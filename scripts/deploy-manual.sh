#!/bin/bash

# Manual Deployment Script for Pi-K3s
# This script guides you through manual deployment steps

set -e

VPS_HOST="165.154.227.179"
VPS_USER="ubuntu"
NAMESPACE="pi-k3s"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
IMAGE_TAG="pi-k3s:$TIMESTAMP"

echo "======================================"
echo "Pi-K3s VPS Manual Deployment Guide"
echo "======================================"
echo "Target: $VPS_USER@$VPS_HOST"
echo ""

# Check prerequisites
echo "Checking prerequisites..."
command -v docker >/dev/null 2>&1 || { echo "Error: docker not found"; exit 1; }
command -v kubectl >/dev/null 2>&1 || { echo "Error: kubectl not found"; exit 1; }
echo "✓ Prerequisites OK"
echo ""

# Step 1: Build image
echo "[Step 1/6] Building Docker image..."
echo "Press Enter to continue..."
read
docker build -t pi-k3s:latest -t $IMAGE_TAG .
echo "✓ Image built successfully"
echo ""

# Step 2: Save image
echo "[Step 2/6] Saving image to file..."
echo "This will create /tmp/pi-k3s-image.tar.gz"
echo "Press Enter to continue..."
read
docker save pi-k3s:latest | gzip > /tmp/pi-k3s-image.tar.gz
echo "✓ Image saved to /tmp/pi-k3s-image.tar.gz"
echo ""

# Step 3: Transfer image
echo "[Step 3/6] Transfer image to VPS"
echo "Please run the following command in another terminal:"
echo ""
echo "  scp /tmp/pi-k3s-image.tar.gz $VPS_USER@$VPS_HOST:/tmp/"
echo ""
echo "You will be prompted for the VPS password."
echo "After transfer is complete, press Enter to continue..."
read

# Step 4: Install K3s and load image
echo "[Step 4/6] Install K3s and load image on VPS"
echo "Please SSH to VPS and run these commands:"
echo ""
echo "  ssh $VPS_USER@$VPS_HOST"
echo ""
echo "Then on the VPS, run:"
echo ""
echo "  # Install K3s if not already installed"
echo "  curl -sfL https://get.k3s.io | sh -"
echo ""
echo "  # Load the Docker image"
echo "  sudo k3s ctr images import /tmp/pi-k3s-image.tar.gz"
echo ""
echo "  # Clean up"
echo "  rm /tmp/pi-k3s-image.tar.gz"
echo ""
echo "  # Exit SSH"
echo "  exit"
echo ""
echo "After completing these steps, press Enter to continue..."
read

# Step 5: Setup kubectl
echo "[Step 5/6] Setting up kubectl access"
echo "Please run this command to copy kubeconfig:"
echo ""
echo "  scp $VPS_USER@$VPS_HOST:/etc/rancher/k3s/k3s.yaml ~/.kube/config-pi-k3s"
echo ""
echo "After copying, press Enter to continue..."
read

# Update kubeconfig
sed -i.bak "s/127.0.0.1/$VPS_HOST/g" ~/.kube/config-pi-k3s
export KUBECONFIG=~/.kube/config-pi-k3s
echo "✓ kubectl configured"
echo ""

# Test kubectl connection
echo "Testing kubectl connection..."
kubectl get nodes || {
    echo "Error: Cannot connect to K3s cluster"
    echo "Please check:"
    echo "  1. K3s is running on VPS: ssh $VPS_USER@$VPS_HOST 'sudo systemctl status k3s'"
    echo "  2. kubeconfig is correct: cat ~/.kube/config-pi-k3s"
    exit 1
}
echo ""

# Step 6: Deploy application
echo "[Step 6/6] Deploying application to K3s..."
echo "Press Enter to continue..."
read

# Update deployment.yaml
cd "$(dirname "$0")/.."
cp k8s/deployment.yaml k8s/deployment.yaml.bak
sed -i "s|image:.*pi-k3s.*|image: pi-k3s:latest|g" k8s/deployment.yaml
sed -i "/image: pi-k3s:latest/a\\        imagePullPolicy: Never" k8s/deployment.yaml

# Apply manifests
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/secrets.yaml
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
kubectl apply -f k8s/ingress.yaml

echo ""
echo "Waiting for deployment..."
kubectl wait --for=condition=available --timeout=180s deployment/laravel-app -n $NAMESPACE || true

echo ""
echo "======================================"
echo "Deployment Complete!"
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
echo "Useful commands:"
echo "  kubectl logs -n $NAMESPACE -l app=laravel -f"
echo "  kubectl get pods -n $NAMESPACE"
echo "  kubectl describe pod -n $NAMESPACE <pod-name>"
echo ""
echo "Test API:"
echo "  curl -X POST http://$VPS_HOST/api/calculate -H 'Content-Type: application/json' -d '{\"total_points\":100000}'"
echo ""

# Cleanup
rm /tmp/pi-k3s-image.tar.gz
