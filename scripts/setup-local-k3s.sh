#!/bin/bash
#
# 本機 K3s + Ingress 設定，透過 http://pi-k3s.local 存取
#
# 前置需求：
#   - Docker 已安裝且運行中
#   - k3d 已安裝（若無，腳本會提示安裝方式）
#   - kubectl 已安裝（k3d 通常會一併安裝）
#
# 使用方式：
#   ./scripts/setup-local-k3s.sh
#
# 完成後：瀏覽 http://pi-k3s.local（需先設定 /etc/hosts 見下方說明）
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
K8S_DIR="$PROJECT_ROOT/k8s"
CLUSTER_NAME="pi-k3s"
NAMESPACE="pi-k3s"

echo "======================================"
echo "Pi-K3s 本機 K3s + Ingress 設定"
echo "======================================"
echo "專案目錄: $PROJECT_ROOT"
echo ""

cd "$PROJECT_ROOT"

# 檢查 k3d
if ! command -v k3d >/dev/null 2>&1; then
    echo "錯誤: 未找到 k3d。請先安裝："
    echo "  curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash"
    echo "  或參考 https://k3d.io/"
    exit 1
fi

# 檢查 kubectl
if ! command -v kubectl >/dev/null 2>&1; then
    echo "錯誤: 未找到 kubectl。安裝 k3d 後通常會包含，或請手動安裝 kubectl。"
    exit 1
fi

# 檢查 Docker
if ! docker info >/dev/null 2>&1; then
    echo "錯誤: Docker 未運行。請先啟動 Docker。"
    exit 1
fi

# 若 cluster 已存在則刪除（可選：--recreate 時使用）
if k3d cluster list 2>/dev/null | grep -q "^$CLUSTER_NAME "; then
    echo "[1/7] 刪除既有 cluster: $CLUSTER_NAME"
    k3d cluster delete "$CLUSTER_NAME"
fi

# 建立 k3d cluster（port 80 對應 Traefik LoadBalancer）
echo "[1/7] 建立 k3d cluster: $CLUSTER_NAME (port 80 -> Traefik)"
k3d cluster create "$CLUSTER_NAME" \
    -p "80:80@loadbalancer" \
    --agents 1

# 建置 Docker 映像
echo "[2/7] 建置 Docker 映像..."
docker build -t pi-k3s:latest .

# 匯入映像到 k3d
echo "[3/7] 匯入映像到 k3d cluster..."
k3d image import pi-k3s:latest -c "$CLUSTER_NAME"

# 生成 ConfigMap（本機用）
echo "[4/7] 生成 ConfigMap、Secrets、Deployment..."
cat > "$K8S_DIR/configmap.yaml" << 'CONFIGMAP'
apiVersion: v1
kind: ConfigMap
metadata:
  name: laravel-config
  namespace: pi-k3s
data:
  APP_NAME: "Pi Calculator"
  APP_ENV: "local"
  APP_DEBUG: "true"
  APP_URL: "http://pi-k3s.local"
  LOG_CHANNEL: "stderr"
  LOG_LEVEL: "debug"
  DB_CONNECTION: "sqlite"
  DB_DATABASE: "/var/www/html/database/database.sqlite"
  CACHE_DRIVER: "file"
  SESSION_DRIVER: "file"
  QUEUE_CONNECTION: "database"
  BROADCAST_DRIVER: "log"
CONFIGMAP

# 從 .env 讀取 APP_KEY 並 base64 編碼
if [ -f .env ]; then
    APP_KEY=$(grep '^APP_KEY=' .env | cut -d= -f2- | tr -d '"' | tr -d "'")
    if [ -n "$APP_KEY" ]; then
        APP_KEY_B64=$(echo -n "$APP_KEY" | base64 -w 0 2>/dev/null || echo -n "$APP_KEY" | base64)
    else
        echo "警告: .env 中未找到 APP_KEY，將使用預設值"
        APP_KEY_B64=$(echo -n "base64:PLEASE_GENERATE_KEY" | base64 -w 0 2>/dev/null || echo -n "base64:PLEASE_GENERATE_KEY" | base64)
    fi
else
    echo "警告: 未找到 .env，將使用預設 APP_KEY"
    APP_KEY_B64=$(echo -n "base64:PLEASE_GENERATE_KEY" | base64 -w 0 2>/dev/null || echo -n "base64:PLEASE_GENERATE_KEY" | base64)
fi

cat > "$K8S_DIR/secrets.yaml" << SECRETS
apiVersion: v1
kind: Secret
metadata:
  name: laravel-secrets
  namespace: pi-k3s
type: Opaque
data:
  APP_KEY: $APP_KEY_B64
  DB_PASSWORD: ""
SECRETS

# 本機 Deployment（無 hostPort，由 Ingress/Traefik 處理 port 80）
cat > "$K8S_DIR/deployment.yaml" << 'DEPLOYMENT'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: laravel-app
  namespace: pi-k3s
  labels:
    app: laravel
    component: web
spec:
  replicas: 1
  selector:
    matchLabels:
      app: laravel
      component: web
  template:
    metadata:
      labels:
        app: laravel
        component: web
    spec:
      serviceAccountName: laravel-app
      containers:
      - name: laravel
        image: pi-k3s:latest
        imagePullPolicy: Never
        ports:
        - containerPort: 80
          name: http
          protocol: TCP
        env:
        - name: APP_NAME
          valueFrom:
            configMapKeyRef:
              name: laravel-config
              key: APP_NAME
        - name: APP_ENV
          valueFrom:
            configMapKeyRef:
              name: laravel-config
              key: APP_ENV
        - name: APP_DEBUG
          valueFrom:
            configMapKeyRef:
              name: laravel-config
              key: APP_DEBUG
        - name: APP_URL
          valueFrom:
            configMapKeyRef:
              name: laravel-config
              key: APP_URL
        - name: LOG_CHANNEL
          valueFrom:
            configMapKeyRef:
              name: laravel-config
              key: LOG_CHANNEL
        - name: LOG_LEVEL
          valueFrom:
            configMapKeyRef:
              name: laravel-config
              key: LOG_LEVEL
        - name: DB_CONNECTION
          valueFrom:
            configMapKeyRef:
              name: laravel-config
              key: DB_CONNECTION
        - name: DB_DATABASE
          valueFrom:
            configMapKeyRef:
              name: laravel-config
              key: DB_DATABASE
        - name: CACHE_DRIVER
          valueFrom:
            configMapKeyRef:
              name: laravel-config
              key: CACHE_DRIVER
        - name: SESSION_DRIVER
          valueFrom:
            configMapKeyRef:
              name: laravel-config
              key: SESSION_DRIVER
        - name: QUEUE_CONNECTION
          valueFrom:
            configMapKeyRef:
              name: laravel-config
              key: QUEUE_CONNECTION
        - name: BROADCAST_DRIVER
          valueFrom:
            configMapKeyRef:
              name: laravel-config
              key: BROADCAST_DRIVER
        - name: APP_KEY
          valueFrom:
            secretKeyRef:
              name: laravel-secrets
              key: APP_KEY
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: laravel-secrets
              key: DB_PASSWORD
        - name: AUTO_MIGRATE
          value: "true"
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "192Mi"
            cpu: "500m"
        livenessProbe:
          httpGet:
            path: /up
            port: 80
          initialDelaySeconds: 60
          periodSeconds: 30
          timeoutSeconds: 5
          failureThreshold: 5
        readinessProbe:
          httpGet:
            path: /up
            port: 80
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 5
        volumeMounts:
        - name: storage
          mountPath: /var/www/html/storage
      volumes:
      - name: storage
        emptyDir: {}
DEPLOYMENT

# 套用 manifests
echo "[5/7] 套用 Kubernetes manifests..."
kubectl apply -f "$K8S_DIR/namespace.yaml"
kubectl apply -f "$K8S_DIR/ingressclass.yaml" 2>/dev/null || true
kubectl apply -f "$K8S_DIR/configmap.yaml"
kubectl apply -f "$K8S_DIR/secrets.yaml"
kubectl apply -f "$K8S_DIR/serviceaccount.yaml"
kubectl apply -f "$K8S_DIR/role.yaml"
kubectl apply -f "$K8S_DIR/rolebinding.yaml"
kubectl apply -f "$K8S_DIR/deployment.yaml"
kubectl apply -f "$K8S_DIR/service.yaml"
kubectl apply -f "$K8S_DIR/ingress.yaml"
kubectl apply -f "$K8S_DIR/hpa.yaml" 2>/dev/null || true

# 等待 Deployment 就緒
echo "[6/7] 等待 Deployment 就緒..."
kubectl wait --for=condition=available --timeout=180s deployment/laravel-app -n "$NAMESPACE" 2>/dev/null || true

echo "[7/7] 驗證..."
kubectl get pods -n "$NAMESPACE"
kubectl get ingress -n "$NAMESPACE"

echo ""
echo "======================================"
echo "✓ 本機 K3s 設定完成"
echo "======================================"
echo ""
echo "請確認 /etc/hosts 已加入："
echo "  127.0.0.1 pi-k3s.local"
echo ""
echo "然後瀏覽： http://pi-k3s.local"
echo ""
echo "除錯指令："
echo "  kubectl logs -n $NAMESPACE -l app=laravel -f"
echo "  kubectl describe pod -n $NAMESPACE -l app=laravel"
echo ""
echo "若無法存取，可先用 port-forward 測試："
echo "  kubectl port-forward -n $NAMESPACE svc/laravel-service 8080:80"
echo "  然後訪問 http://localhost:8080"
echo ""
