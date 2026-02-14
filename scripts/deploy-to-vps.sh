#!/bin/bash

set -e

# VPS 配置
VPS_HOST="165.154.227.179"
VPS_USER="ubuntu"
NAMESPACE="pi-k3s"

echo "======================================"
echo "Pi-K3s VPS Deployment Script"
echo "======================================"
echo ""

# 檢查必要工具
command -v ssh >/dev/null 2>&1 || { echo "Error: ssh is required but not installed."; exit 1; }
command -v docker >/dev/null 2>&1 || { echo "Error: docker is required but not installed."; exit 1; }

# 顯示 VPS 資訊
echo "Target VPS: $VPS_USER@$VPS_HOST"
echo "Namespace: $NAMESPACE"
echo ""

# 步驟 1: 測試 SSH 連線
echo "[1/7] Testing SSH connection..."
ssh -o ConnectTimeout=10 -o BatchMode=yes $VPS_USER@$VPS_HOST "echo 'SSH connection successful'" 2>/dev/null || {
    echo "Error: Cannot connect to VPS via SSH."
    echo "Please ensure:"
    echo "  1. SSH key is configured: ssh-copy-id $VPS_USER@$VPS_HOST"
    echo "  2. Or use: ssh $VPS_USER@$VPS_HOST (enter password when prompted)"
    exit 1
}
echo "✓ SSH connection verified"
echo ""

# 步驟 2: 建置並標記 Docker image
echo "[2/7] Building and tagging Docker image..."
IMAGE_TAG="${VPS_USER}/pi-k3s:$(date +%Y%m%d-%H%M%S)"
docker build -t pi-k3s:latest -t $IMAGE_TAG .
echo "✓ Image built: $IMAGE_TAG"
echo ""

# 步驟 3: 推送 image 到 Docker Hub（需要先登入）
echo "[3/7] Pushing image to registry..."
echo "Note: This requires Docker Hub login. Run 'docker login' if needed."
read -p "Push to Docker Hub? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    docker push $IMAGE_TAG
    echo "✓ Image pushed to Docker Hub"
else
    echo "Skipping Docker Hub push. Will save and transfer image instead..."

    # 保存 image 到 tar 文件
    echo "Saving image to tar file..."
    docker save pi-k3s:latest | gzip > /tmp/pi-k3s-image.tar.gz

    # 傳送到 VPS
    echo "Transferring image to VPS..."
    scp /tmp/pi-k3s-image.tar.gz $VPS_USER@$VPS_HOST:/tmp/

    # 在 VPS 上載入 image
    echo "Loading image on VPS..."
    ssh $VPS_USER@$VPS_HOST "sudo k3s ctr images import /tmp/pi-k3s-image.tar.gz && rm /tmp/pi-k3s-image.tar.gz"

    rm /tmp/pi-k3s-image.tar.gz
    echo "✓ Image transferred and loaded on VPS"

    IMAGE_TAG="pi-k3s:latest"
fi
echo ""

# 步驟 4: 在 VPS 上安裝 K3s（如果尚未安裝）
echo "[4/7] Checking K3s installation..."
ssh $VPS_USER@$VPS_HOST "command -v k3s" >/dev/null 2>&1 && {
    echo "✓ K3s already installed"
} || {
    echo "Installing K3s..."
    ssh $VPS_USER@$VPS_HOST "curl -sfL https://get.k3s.io | sh -"
    echo "Waiting for K3s to start..."
    sleep 10
    echo "✓ K3s installed"
}
echo ""

# 步驟 5: 複製 kubeconfig 到本機
echo "[5/7] Configuring kubectl access..."
mkdir -p ~/.kube
scp $VPS_USER@$VPS_HOST:/etc/rancher/k3s/k3s.yaml ~/.kube/config-pi-k3s
sed -i "s/127.0.0.1/$VPS_HOST/g" ~/.kube/config-pi-k3s
export KUBECONFIG=~/.kube/config-pi-k3s
echo "✓ kubectl configured (KUBECONFIG=~/.kube/config-pi-k3s)"
echo ""

# 步驟 6: 更新 deployment.yaml 中的 image
echo "[6/7] Updating Kubernetes manifests..."
sed -i.bak "s|image:.*|image: $IMAGE_TAG|g" k8s/deployment.yaml
echo "✓ Updated image tag in deployment.yaml"
echo ""

# 步驟 7: 部署到 K3s
echo "[7/7] Deploying to K3s..."
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/secrets.yaml
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
kubectl apply -f k8s/ingress.yaml

echo ""
echo "Waiting for deployment to be ready..."
kubectl wait --for=condition=available --timeout=120s deployment/laravel-app -n $NAMESPACE || {
    echo "Warning: Deployment did not become ready within 120s"
    echo "Check status with: kubectl get pods -n $NAMESPACE"
}

echo ""
echo "======================================"
echo "Deployment Complete!"
echo "======================================"
echo ""
echo "Next steps:"
echo "  1. Check deployment status:"
echo "     kubectl get pods -n $NAMESPACE"
echo "     kubectl get svc -n $NAMESPACE"
echo "     kubectl get ingress -n $NAMESPACE"
echo ""
echo "  2. View logs:"
echo "     kubectl logs -n $NAMESPACE -l app=laravel -f"
echo ""
echo "  3. Access application:"
echo "     http://$VPS_HOST"
echo ""
echo "  4. Test API:"
echo "     curl -X POST http://$VPS_HOST/api/calculate \\"
echo "       -H 'Content-Type: application/json' \\"
echo "       -d '{\"total_points\":100000}'"
echo ""
