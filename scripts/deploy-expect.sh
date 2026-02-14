#!/bin/bash

# Automated VPS Deployment Script using expect for password handling
# This script automates the entire deployment process to the VPS

set -e

VPS_HOST="165.154.227.179"
VPS_USER="ubuntu"
VPS_PASSWORD="$1"
NAMESPACE="pi-k3s"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
IMAGE_FILE="/tmp/pi-k3s-${TIMESTAMP}.tar.gz"

if [ -z "$VPS_PASSWORD" ]; then
    echo "Error: Password required"
    echo "Usage: $0 <vps_password>"
    exit 1
fi

echo "======================================"
echo "Pi-K3s VPS Automated Deployment"
echo "======================================"
echo "Target: $VPS_USER@$VPS_HOST"
echo "Timestamp: $TIMESTAMP"
echo ""

# Check prerequisites
command -v expect >/dev/null 2>&1 || { echo "Error: expect not found. Install with: sudo apt-get install expect"; exit 1; }
command -v docker >/dev/null 2>&1 || { echo "Error: docker not found"; exit 1; }
command -v kubectl >/dev/null 2>&1 || { echo "Error: kubectl not found"; exit 1; }

# Step 1: Build Docker image
echo "[1/7] Building Docker image..."
docker build -t pi-k3s:latest -t pi-k3s:${TIMESTAMP} .
echo "✓ Image built successfully"
echo ""

# Step 2: Save image to tar.gz
echo "[2/7] Saving Docker image..."
docker save pi-k3s:latest | gzip > "$IMAGE_FILE"
IMAGE_SIZE=$(du -h "$IMAGE_FILE" | cut -f1)
echo "✓ Image saved: $IMAGE_FILE ($IMAGE_SIZE)"
echo ""

# Step 3: Transfer image to VPS
echo "[3/7] Transferring image to VPS (this may take a while)..."
expect <<EOF
set timeout 600
spawn scp -o StrictHostKeyChecking=no $IMAGE_FILE $VPS_USER@$VPS_HOST:/tmp/
expect {
    "password:" {
        send "$VPS_PASSWORD\r"
        exp_continue
    }
    eof
}
EOF
echo "✓ Image transferred"
echo ""

# Step 4: Check and install K3s
echo "[4/7] Checking K3s installation..."
K3S_CHECK=$(expect <<EOF
set timeout 30
spawn ssh -o StrictHostKeyChecking=no $VPS_USER@$VPS_HOST "command -v k3s"
expect {
    "password:" {
        send "$VPS_PASSWORD\r"
        exp_continue
    }
    eof
}
EOF
)

if echo "$K3S_CHECK" | grep -q "/k3s"; then
    echo "✓ K3s already installed"
else
    echo "Installing K3s..."
    expect <<EOF
set timeout 300
spawn ssh -o StrictHostKeyChecking=no $VPS_USER@$VPS_HOST "curl -sfL https://get.k3s.io | sh -"
expect {
    "password:" {
        send "$VPS_PASSWORD\r"
        exp_continue
    }
    eof
}
EOF
    echo "Waiting for K3s to start..."
    sleep 15
    echo "✓ K3s installed"
fi
echo ""

# Step 5: Load Docker image on VPS
echo "[5/7] Loading Docker image on VPS..."
expect <<EOF
set timeout 300
spawn ssh -o StrictHostKeyChecking=no $VPS_USER@$VPS_HOST "sudo k3s ctr images import /tmp/pi-k3s-${TIMESTAMP}.tar.gz && rm /tmp/pi-k3s-${TIMESTAMP}.tar.gz"
expect {
    "password:" {
        send "$VPS_PASSWORD\r"
        exp_continue
    }
    eof
}
EOF
echo "✓ Image loaded on VPS"
echo ""

# Clean up local tar file
rm "$IMAGE_FILE"

# Step 6: Setup kubectl access
echo "[6/7] Setting up kubectl access..."
mkdir -p ~/.kube
expect <<EOF
set timeout 30
spawn scp -o StrictHostKeyChecking=no $VPS_USER@$VPS_HOST:/etc/rancher/k3s/k3s.yaml ~/.kube/config-pi-k3s
expect {
    "password:" {
        send "$VPS_PASSWORD\r"
        exp_continue
    }
    eof
}
EOF

# Update server address in kubeconfig
sed -i.bak "s/127.0.0.1/$VPS_HOST/g" ~/.kube/config-pi-k3s
export KUBECONFIG=~/.kube/config-pi-k3s
echo "✓ kubectl configured"
echo ""

# Test kubectl connection
echo "Testing kubectl connection..."
kubectl get nodes || {
    echo "Error: Cannot connect to K3s cluster"
    exit 1
}
echo ""

# Step 7: Deploy to K3s
echo "[7/7] Deploying application..."

# Update deployment.yaml
cd "$(dirname "$0")/.."
cp k8s/deployment.yaml k8s/deployment.yaml.bak
sed -i "s|image:.*pi-k3s.*|image: pi-k3s:latest|g" k8s/deployment.yaml

# Ensure imagePullPolicy is set to Never
if ! grep -q "imagePullPolicy: Never" k8s/deployment.yaml; then
    sed -i "/image: pi-k3s:latest/a\\        imagePullPolicy: Never" k8s/deployment.yaml
fi

# Apply manifests
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/secrets.yaml
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
kubectl apply -f k8s/ingress.yaml

echo ""
echo "Waiting for deployment to be ready..."
kubectl wait --for=condition=available --timeout=180s deployment/laravel-app -n $NAMESPACE || true
echo ""

# Display deployment status
echo "======================================"
echo "Deployment Complete!"
echo "======================================"
echo ""
kubectl get pods -n $NAMESPACE
echo ""
kubectl get svc -n $NAMESPACE
echo ""
kubectl get ingress -n $NAMESPACE
echo ""

echo "Application URL: http://$VPS_HOST"
echo ""
echo "Test API:"
echo "  curl -X POST http://$VPS_HOST/api/calculate -H 'Content-Type: application/json' -d '{\"total_points\":100000}'"
echo ""
echo "Useful commands:"
echo "  kubectl --kubeconfig=~/.kube/config-pi-k3s logs -n $NAMESPACE -l app=laravel -f"
echo "  kubectl --kubeconfig=~/.kube/config-pi-k3s get pods -n $NAMESPACE"
echo ""
