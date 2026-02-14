#!/bin/bash
#
# 在 VPS 上直接部署 - 於 clone 後在專案目錄內執行
# 適用：登入 VPS → Cursor / VS Code Remote → git clone → 本腳本
#
# 前置需求（VPS 上）：
#   - K3s 已安裝且運行中
#   - Docker 已安裝（用於建置映像）
#   - kubectl 或 sudo k3s kubectl 可用
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
NAMESPACE="pi-k3s"

echo "======================================"
echo "Pi-K3s 在 VPS 上直接部署"
echo "======================================"
echo "專案目錄: $PROJECT_ROOT"
echo ""

cd "$PROJECT_ROOT"

# 檢查 Docker
if ! command -v docker >/dev/null 2>&1; then
    echo "錯誤: 未找到 Docker。請先安裝："
    echo "  sudo apt update && sudo apt install -y docker.io"
    echo "  sudo usermod -aG docker \$USER"
    echo "  然後重新登入 SSH"
    exit 1
fi

# 檢查 K3s
if ! command -v k3s >/dev/null 2>&1 && ! sudo k3s kubectl get nodes >/dev/null 2>&1; then
    echo "錯誤: K3s 未安裝或未運行。請先安裝 K3s。"
    exit 1
fi

# 使用 k3s kubectl（VPS 上通常如此）
KUBECTL="sudo k3s kubectl"
if command -v kubectl >/dev/null 2>&1 && kubectl get nodes >/dev/null 2>&1; then
    KUBECTL="kubectl"
fi

# Step 1: 建置映像
echo "[1/4] 建置 Docker 映像..."
docker build -t pi-k3s:latest .

# Step 2: 匯入到 K3s
echo "[2/4] 匯入映像到 K3s..."
docker save pi-k3s:latest | sudo k3s ctr images import -

# Step 3: 套用 manifests
echo "[3/4] 套用 Kubernetes  manifests..."
$KUBECTL apply -f k8s/namespace.yaml
$KUBECTL apply -f k8s/configmap.yaml
$KUBECTL apply -f k8s/secrets.yaml
$KUBECTL apply -f k8s/deployment.yaml
$KUBECTL apply -f k8s/service.yaml
$KUBECTL apply -f k8s/ingress.yaml

# Step 4: 等待並驗證
echo "[4/4] 等待 Deployment 就緒..."
$KUBECTL wait --for=condition=available --timeout=180s deployment/laravel-app -n $NAMESPACE 2>/dev/null || true

echo ""
echo "======================================"
echo "✓ 部署完成"
echo "======================================"
$KUBECTL get pods -n $NAMESPACE
echo ""
echo "除錯指令："
echo "  日誌: $KUBECTL logs -n $NAMESPACE -l app=laravel -f"
echo "  詳情: $KUBECTL describe pod -n $NAMESPACE -l app=laravel"
echo "  重啟: $KUBECTL rollout restart deployment/laravel-app -n $NAMESPACE"
