#!/bin/bash

# Automated VPS Deployment Script
# This script automates deployment to the VPS using SSH (password will be prompted)

set -e

VPS_HOST="165.154.227.179"
VPS_USER="ubuntu"
NAMESPACE="pi-k3s"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
IMAGE_FILE="/tmp/pi-k3s-${TIMESTAMP}.tar.gz"

echo "======================================"
echo "Pi-K3s VPS Deployment"
echo "======================================"
echo "Target: $VPS_USER@$VPS_HOST"
echo "Timestamp: $TIMESTAMP"
echo ""
echo "You will be prompted for the VPS password multiple times."
echo "Press Ctrl+C to cancel at any time."
echo ""

# Check prerequisites
command -v docker >/dev/null 2>&1 || { echo "Error: docker not found"; exit 1; }
command -v kubectl >/dev/null 2>&1 || { echo "Error: kubectl not found"; exit 1; }

# Step 1: Test SSH connection
echo "[Step 1/8] Testing SSH connection..."
if ! ssh -o ConnectTimeout=10 $VPS_USER@$VPS_HOST "echo '✓ SSH connection successful'"; then
    echo "Error: Cannot connect to VPS"
    exit 1
fi
echo ""

# Step 2: Set up SSH key (optional but recommended)
echo "[Step 2/8] Setting up SSH key authentication..."
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

# Step 3: Build Docker image
echo "[Step 3/8] Building Docker image..."
docker build -t pi-k3s:latest -t pi-k3s:${TIMESTAMP} .
echo "✓ Image built"
echo ""

# Step 4: Save and transfer image
echo "[Step 4/8] Saving Docker image..."
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

# Step 5: Check and install K3s
echo "[Step 5/8] Checking K3s installation..."
if ssh $VPS_USER@$VPS_HOST "command -v k3s" >/dev/null 2>&1; then
    echo "✓ K3s already installed"
else
    echo "Installing K3s..."
    ssh $VPS_USER@$VPS_HOST "curl -sfL https://get.k3s.io | sh -"
    echo "Waiting for K3s to start..."
    sleep 15
    echo "✓ K3s installed"
fi
echo ""

# Step 6: Load image on VPS
echo "[Step 6/8] Loading Docker image on VPS..."
ssh $VPS_USER@$VPS_HOST "sudo k3s ctr images import /tmp/pi-k3s-${TIMESTAMP}.tar.gz && rm /tmp/pi-k3s-${TIMESTAMP}.tar.gz"
echo "✓ Image loaded"
echo ""

# Step 7: Setup kubectl access
echo "[Step 7/8] Setting up kubectl..."
mkdir -p ~/.kube
scp $VPS_USER@$VPS_HOST:/etc/rancher/k3s/k3s.yaml ~/.kube/config-pi-k3s
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

# Step 8: Deploy application
echo "[Step 8/8] Deploying application..."
cd "$(dirname "$0")/.."

# Update deployment.yaml
cp k8s/deployment.yaml k8s/deployment.yaml.bak 2>/dev/null || true
sed -i "s|image:.*pi-k3s.*|image: pi-k3s:latest|g" k8s/deployment.yaml

# Ensure imagePullPolicy is set
if ! grep -q "imagePullPolicy: Never" k8s/deployment.yaml; then
    sed -i "/image: pi-k3s:latest/a\\        imagePullPolicy: Never" k8s/deployment.yaml
fi

# Apply all manifests
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/secrets.yaml
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
kubectl apply -f k8s/ingress.yaml

echo ""
echo "Waiting for deployment..."
kubectl wait --for=condition=available --timeout=180s deployment/laravel-app -n $NAMESPACE 2>/dev/null || true
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
kubectl get ingress -n $NAMESPACE
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
echo "  kubectl describe pod -n $NAMESPACE <pod-name>"
echo ""
