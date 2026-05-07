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

REQUIRED_MANIFESTS=(
    "k8s/configmap.yaml"
    "k8s/secrets.yaml"
    "k8s/deployment.yaml"
    "k8s/worker-deployment.yaml"
    "k8s/mariadb-pvc.yaml"
    "k8s/mariadb-deployment.yaml"
)

missing_manifests=()
for manifest in "${REQUIRED_MANIFESTS[@]}"; do
    if [ ! -f "$manifest" ]; then
        missing_manifests+=("$manifest")
    fi
done

if [ "${#missing_manifests[@]}" -gt 0 ]; then
    echo "錯誤: 缺少環境特定 Kubernetes manifest："
    for manifest in "${missing_manifests[@]}"; do
        echo "  - $manifest"
    done
    echo ""
    echo "首次部署請先複製範本並填入正式環境設定："
    echo "  cp k8s/configmap.yaml.example k8s/configmap.yaml"
    echo "  cp k8s/secrets.yaml.example k8s/secrets.yaml"
    echo "  cp k8s/deployment.yaml.example k8s/deployment.yaml"
    echo "  cp k8s/worker-deployment.yaml.example k8s/worker-deployment.yaml"
    echo "  cp k8s/mariadb-pvc.yaml.example k8s/mariadb-pvc.yaml"
    echo "  cp k8s/mariadb-deployment.yaml.example k8s/mariadb-deployment.yaml"
    exit 1
fi

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
echo "[3/4] 套用 Kubernetes manifests..."
$KUBECTL apply -f k8s/namespace.yaml
$KUBECTL apply -f k8s/configmap.yaml
$KUBECTL apply -f k8s/secrets.yaml
$KUBECTL apply -f k8s/serviceaccount.yaml
$KUBECTL apply -f k8s/role.yaml
$KUBECTL apply -f k8s/rolebinding.yaml
$KUBECTL apply -f k8s/mariadb-pvc.yaml
$KUBECTL apply -f k8s/mariadb-service.yaml
$KUBECTL apply -f k8s/mariadb-deployment.yaml
$KUBECTL apply -f k8s/redis-service.yaml
$KUBECTL apply -f k8s/redis-deployment.yaml
$KUBECTL apply -f k8s/deployment.yaml
$KUBECTL apply -f k8s/worker-deployment.yaml
$KUBECTL apply -f k8s/service.yaml
$KUBECTL apply -f k8s/ingress.yaml
$KUBECTL delete hpa laravel-app -n $NAMESPACE --ignore-not-found >/dev/null 2>&1 || true
$KUBECTL apply -f k8s/hpa.yaml 2>/dev/null || true

# Step 4: 觸發 rollout 並等待就緒
# 注意：web deployment 使用 hostPort，策略已設為 maxSurge=0（先終止舊 Pod 再啟動新 Pod）
# worker deployment 不對外，作為 K3s 單節點上的可擴展計算層
echo "[4/4] 觸發 rollout restart 並等待就緒..."
# 先等基礎設施就緒，再啟動 Laravel（避免 migration 因 MariaDB 未就緒而失敗）
$KUBECTL rollout restart deployment/mariadb -n $NAMESPACE
$KUBECTL rollout restart deployment/redis -n $NAMESPACE
$KUBECTL rollout status deployment/mariadb -n $NAMESPACE --timeout=180s
$KUBECTL rollout status deployment/redis -n $NAMESPACE --timeout=120s
$KUBECTL rollout restart deployment/laravel-app -n $NAMESPACE
$KUBECTL rollout restart deployment/laravel-worker -n $NAMESPACE
$KUBECTL rollout status deployment/laravel-app -n $NAMESPACE --timeout=180s
$KUBECTL rollout status deployment/laravel-worker -n $NAMESPACE --timeout=180s

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
