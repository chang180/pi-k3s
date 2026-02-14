#!/bin/bash

# Automated VPS Deployment Script (K3s - optimized for 1C1G)
# Deploys Laravel app on K3s with minimal resource usage

set -e

VPS_HOST="165.154.227.179"
VPS_USER="ubuntu"
NAMESPACE="pi-k3s"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
IMAGE_FILE="/tmp/pi-k3s-${TIMESTAMP}.tar.gz"

echo "======================================"
echo "Pi-K3s VPS Deployment (Lightweight K3s)"
echo "======================================"
echo "Target: $VPS_USER@$VPS_HOST"
echo "Timestamp: $TIMESTAMP"
echo ""
echo "You will be prompted for the VPS password multiple times."
echo "Press Ctrl+C to cancel at any time."
echo ""

# Check prerequisites
command -v docker >/dev/null 2>&1 || { echo "Error: docker not found"; exit 1; }

# Step 1: Test SSH connection
echo "[Step 1/9] Testing SSH connection..."
if ! ssh -o ConnectTimeout=10 $VPS_USER@$VPS_HOST "echo '✓ SSH connection successful'"; then
    echo "Error: Cannot connect to VPS"
    exit 1
fi
echo ""

# Step 2: Set up SSH key (optional but recommended)
echo "[Step 2/9] Setting up SSH key authentication..."
if ! ssh -o BatchMode=yes -o ConnectTimeout=5 $VPS_USER@$VPS_HOST "echo 'test'" 2>/dev/null; then
    echo "SSH key not configured. Setting up now..."
    if [ -f ~/.ssh/id_rsa.pub ]; then
        echo "Copying SSH public key to VPS..."
        cat ~/.ssh/id_rsa.pub | ssh $VPS_USER@$VPS_HOST "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys"
        echo "✓ SSH key configured - subsequent steps won't require password"
    else
        echo "⚠ No SSH key found. You will need to enter password for each step."
        echo "  To generate SSH key: ssh-keygen -t rsa -b 4096"
    fi
else
    echo "✓ SSH key already configured"
fi
echo ""

# Step 3: Set up swap + disable unnecessary services (safety net for 1G RAM)
echo "[Step 3/9] Optimizing VPS for low memory..."
ssh $VPS_USER@$VPS_HOST 'bash -s' <<'OPTIMIZE_EOF'
# --- Swap ---
if [ ! -f /swapfile ]; then
    echo "Creating 1GB swap file..."
    sudo fallocate -l 1G /swapfile
    sudo chmod 600 /swapfile
    sudo mkswap /swapfile
    sudo swapon /swapfile
    echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
    echo "✓ Swap created and enabled"
else
    if ! swapon --show | grep -q /swapfile; then
        sudo swapon /swapfile
    fi
    echo "✓ Swap already exists"
fi
sudo sysctl -w vm.swappiness=10 > /dev/null
echo 'vm.swappiness=10' | sudo tee /etc/sysctl.d/99-swappiness.conf > /dev/null

# --- Disable unnecessary services to free memory ---
SERVICES_TO_DISABLE="multipathd multipathd.socket ModemManager udisks2 nginx"
for svc in $SERVICES_TO_DISABLE; do
    if systemctl is-active --quiet "$svc" 2>/dev/null; then
        sudo systemctl stop "$svc" 2>/dev/null
        sudo systemctl disable "$svc" 2>/dev/null
        echo "  ✓ Stopped $svc"
    fi
done

# Stop Docker if running (K3s uses its own containerd)
if systemctl is-active --quiet docker 2>/dev/null; then
    sudo systemctl stop docker docker.socket containerd 2>/dev/null
    sudo systemctl disable docker docker.socket containerd 2>/dev/null
    echo "  ✓ Stopped Docker (K3s uses its own containerd)"
fi

echo "✓ VPS optimized"
OPTIMIZE_EOF
echo ""

# Step 4: Build Docker image
echo "[Step 4/9] Building Docker image..."
cd "$(dirname "$0")/.."
docker build -t pi-k3s:latest -t pi-k3s:${TIMESTAMP} .
echo "✓ Image built"
echo ""

# Step 5: Save and transfer image
echo "[Step 5/9] Saving Docker image..."
docker save pi-k3s:latest | gzip > "$IMAGE_FILE"
IMAGE_SIZE=$(du -h "$IMAGE_FILE" | cut -f1)
echo "✓ Image saved: $IMAGE_SIZE"
echo ""

echo "Transferring image to VPS (this may take a few minutes)..."
scp "$IMAGE_FILE" $VPS_USER@$VPS_HOST:/tmp/
echo "✓ Image transferred"
echo ""

# Clean up local file
rm "$IMAGE_FILE"

# Step 6: Install K3s (lightweight mode - no traefik, no servicelb; metrics-server 保留供 HPA)
echo "[Step 6/9] Checking K3s installation..."
ssh $VPS_USER@$VPS_HOST 'bash -s' <<'K3S_EOF'
if command -v k3s >/dev/null 2>&1 && systemctl is-active --quiet k3s; then
    echo "✓ K3s already installed and running"
else
    echo "Installing K3s (lightweight mode)..."
    curl -sfL https://get.k3s.io | sh -

    # Patch K3s service with lightweight flags
    sudo sed -i '/^ExecStart=/,/^$/c\ExecStart=/usr/local/bin/k3s \\\n    server \\\n    --tls-san 165.154.227.179 \\\n    --disable=traefik \\\n    --disable=servicelb \\\n    --kubelet-arg=max-pods=30 \\\n    --kubelet-arg=eviction-hard=memory.available<100Mi \\\n    --kube-apiserver-arg=max-requests-inflight=10 \\\n    --kube-apiserver-arg=max-mutating-requests-inflight=5\n' /etc/systemd/system/k3s.service

    sudo systemctl daemon-reload
    sudo systemctl restart k3s
    echo "Waiting for K3s to be ready..."
    sleep 20
    echo "✓ K3s installed (lightweight mode)"
fi
K3S_EOF
echo ""

# Step 7: Load image on VPS
echo "[Step 7/9] Loading Docker image on VPS..."
ssh $VPS_USER@$VPS_HOST "sudo k3s ctr images import /tmp/pi-k3s-${TIMESTAMP}.tar.gz && rm /tmp/pi-k3s-${TIMESTAMP}.tar.gz"
echo "✓ Image loaded"
echo ""

# Step 8: Setup kubectl access
echo "[Step 8/9] Setting up kubectl..."
mkdir -p ~/.kube
# Copy kubeconfig using sudo cat to avoid permission issues
ssh $VPS_USER@$VPS_HOST "sudo cat /etc/rancher/k3s/k3s.yaml" > ~/.kube/config-pi-k3s
sed -i.bak "s/127.0.0.1/$VPS_HOST/g" ~/.kube/config-pi-k3s
export KUBECONFIG=~/.kube/config-pi-k3s
echo "✓ kubectl configured"
echo ""

# Verify connection
echo "Testing kubectl connection..."
if ! kubectl get nodes; then
    echo "Error: Cannot connect to K3s cluster"
    exit 1
fi
echo ""

# Step 9: Deploy application
echo "[Step 9/9] Deploying application..."

# Apply K8s manifests (no ingress — using hostPort instead)
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/secrets.yaml
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
kubectl apply -f k8s/hpa.yaml 2>/dev/null || true

echo ""
echo "Waiting for deployment..."
kubectl wait --for=condition=available --timeout=300s deployment/laravel-app -n $NAMESPACE 2>/dev/null || true
echo ""

# Show status
echo "======================================"
echo "✓ Deployment Complete!"
echo "======================================"
echo ""
echo "Deployment Status:"
kubectl get pods -n $NAMESPACE
echo ""
kubectl get svc -n $NAMESPACE
echo ""

echo "Application URL: http://$VPS_HOST"
echo ""
echo "Test API:"
echo "  curl -X POST http://$VPS_HOST/api/calculate \\"
echo "    -H 'Content-Type: application/json' \\"
echo "    -d '{\"total_points\":100000}'"
echo ""
echo "View logs:"
echo "  kubectl --kubeconfig=~/.kube/config-pi-k3s logs -n $NAMESPACE -l app=laravel -f"
echo ""
echo "Useful commands:"
echo "  export KUBECONFIG=~/.kube/config-pi-k3s"
echo "  kubectl get pods -n $NAMESPACE"
echo ""
