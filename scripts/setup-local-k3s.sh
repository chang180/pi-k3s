#!/bin/bash
#
# 本機 K3s 驗證流程（k3d）
# - web: 1 replica
# - worker: 2 replicas
# - mariadb + redis
# - ingress 透過 http://localhost:8081 對外
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
K8S_DIR="$PROJECT_ROOT/k8s"
GENERATED_DIR="$K8S_DIR/.generated-local"
CLUSTER_NAME="pi-k3s-local"
NAMESPACE="pi-k3s-local"
APP_URL="http://localhost:8081"
K3D_BIN="${K3D_BIN:-k3d}"

echo "======================================"
echo "Pi-K3s 本機 K3s 驗證"
echo "======================================"
echo "專案目錄: $PROJECT_ROOT"
echo "Cluster:   $CLUSTER_NAME"
echo "URL:       $APP_URL"
echo ""

cd "$PROJECT_ROOT"

if ! command -v "$K3D_BIN" >/dev/null 2>&1; then
    echo "錯誤: 未找到 k3d。"
    echo "Windows 可安裝: winget install --id k3d.k3d"
    exit 1
fi

if ! command -v kubectl >/dev/null 2>&1; then
    echo "錯誤: 未找到 kubectl。"
    exit 1
fi

if ! docker info >/dev/null 2>&1; then
    echo "錯誤: Docker 未運行。"
    exit 1
fi

mkdir -p "$GENERATED_DIR"

APP_KEY=""
if [ -f .env ]; then
    APP_KEY=$(grep '^APP_KEY=' .env | cut -d= -f2- | tr -d '"' | tr -d "'" || true)
fi

if [ -z "$APP_KEY" ]; then
    APP_KEY="base64:PLEASE_GENERATE_KEY"
fi

LOCAL_DB_PASSWORD="${LOCAL_DB_PASSWORD:-local-db-$(date +%s)-$RANDOM}"
LOCAL_DB_ROOT_PASSWORD="${LOCAL_DB_ROOT_PASSWORD:-local-root-$(date +%s)-$RANDOM}"

cat > "$GENERATED_DIR/00-namespace.yaml" <<YAML
apiVersion: v1
kind: Namespace
metadata:
  name: $NAMESPACE
YAML

cat > "$GENERATED_DIR/10-configmap.yaml" <<YAML
apiVersion: v1
kind: ConfigMap
metadata:
  name: laravel-config
  namespace: $NAMESPACE
data:
  APP_NAME: "Pi Calculator"
  APP_ENV: "local"
  APP_DEBUG: "true"
  APP_URL: "$APP_URL"
  LOG_CHANNEL: "stderr"
  LOG_LEVEL: "debug"
  DB_CONNECTION: "mysql"
  DB_HOST: "mariadb"
  DB_PORT: "3306"
  DB_DATABASE: "pi_k3s"
  DB_USERNAME: "pi_k3s"
  CACHE_STORE: "redis"
  SESSION_DRIVER: "redis"
  QUEUE_CONNECTION: "redis"
  REDIS_CLIENT: "phpredis"
  REDIS_HOST: "redis"
  REDIS_PORT: "6379"
  BROADCAST_DRIVER: "log"
YAML

cat > "$GENERATED_DIR/11-secrets.yaml" <<YAML
apiVersion: v1
kind: Secret
metadata:
  name: laravel-secrets
  namespace: $NAMESPACE
type: Opaque
stringData:
  APP_KEY: "$APP_KEY"
  DB_PASSWORD: "$LOCAL_DB_PASSWORD"
  MARIADB_ROOT_PASSWORD: "$LOCAL_DB_ROOT_PASSWORD"
YAML

cat > "$GENERATED_DIR/20-mariadb.yaml" <<YAML
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mariadb
  namespace: $NAMESPACE
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mariadb
  template:
    metadata:
      labels:
        app: mariadb
    spec:
      containers:
      - name: mariadb
        image: mariadb:11.4
        env:
        - name: MARIADB_ROOT_PASSWORD
          valueFrom:
            secretKeyRef:
              name: laravel-secrets
              key: MARIADB_ROOT_PASSWORD
        - name: MARIADB_DATABASE
          value: pi_k3s
        - name: MARIADB_USER
          value: pi_k3s
        - name: MARIADB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: laravel-secrets
              key: DB_PASSWORD
        ports:
        - containerPort: 3306
        readinessProbe:
          exec:
            command: ["/usr/local/bin/healthcheck.sh", "--connect", "--innodb_initialized"]
          initialDelaySeconds: 10
          periodSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: mariadb
  namespace: $NAMESPACE
spec:
  selector:
    app: mariadb
  ports:
  - port: 3306
    targetPort: 3306
YAML

cat > "$GENERATED_DIR/21-redis.yaml" <<YAML
apiVersion: apps/v1
kind: Deployment
metadata:
  name: redis
  namespace: $NAMESPACE
spec:
  replicas: 1
  selector:
    matchLabels:
      app: redis
  template:
    metadata:
      labels:
        app: redis
    spec:
      containers:
      - name: redis
        image: redis:7-alpine
        args: ["redis-server", "--appendonly", "no", "--maxmemory", "64mb", "--maxmemory-policy", "allkeys-lru"]
        ports:
        - containerPort: 6379
---
apiVersion: v1
kind: Service
metadata:
  name: redis
  namespace: $NAMESPACE
spec:
  selector:
    app: redis
  ports:
  - port: 6379
    targetPort: 6379
YAML

cat > "$GENERATED_DIR/30-web.yaml" <<YAML
apiVersion: apps/v1
kind: Deployment
metadata:
  name: laravel-app
  namespace: $NAMESPACE
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
      - name: app
        image: pi-k3s:latest
        imagePullPolicy: Never
        ports:
        - containerPort: 80
        envFrom:
        - configMapRef:
            name: laravel-config
        env:
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
        readinessProbe:
          httpGet:
            path: /up
            port: 80
          initialDelaySeconds: 20
          periodSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: laravel-service
  namespace: $NAMESPACE
spec:
  selector:
    app: laravel
    component: web
  ports:
  - port: 80
    targetPort: 80
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: laravel-ingress
  namespace: $NAMESPACE
  annotations:
    traefik.ingress.kubernetes.io/router.entrypoints: web
spec:
  ingressClassName: traefik
  rules:
  - http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: laravel-service
            port:
              number: 80
YAML

cat > "$GENERATED_DIR/31-worker.yaml" <<YAML
apiVersion: apps/v1
kind: Deployment
metadata:
  name: laravel-worker
  namespace: $NAMESPACE
  labels:
    app: laravel
    component: worker
spec:
  replicas: 2
  selector:
    matchLabels:
      app: laravel
      component: worker
  template:
    metadata:
      labels:
        app: laravel
        component: worker
    spec:
      containers:
      - name: worker
        image: pi-k3s:latest
        imagePullPolicy: Never
        envFrom:
        - configMapRef:
            name: laravel-config
        env:
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
          value: "false"
        - name: CONTAINER_ROLE
          value: "worker"
        resources:
          requests:
            cpu: "100m"
            memory: "96Mi"
          limits:
            cpu: "700m"
            memory: "256Mi"
YAML

cat > "$GENERATED_DIR/32-hpa.yaml" <<YAML
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: laravel-worker
  namespace: $NAMESPACE
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: laravel-worker
  minReplicas: 1
  maxReplicas: 2
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 50
YAML

if "$K3D_BIN" cluster list 2>/dev/null | grep -q "^$CLUSTER_NAME "; then
    echo "[1/6] 刪除既有 cluster: $CLUSTER_NAME"
    "$K3D_BIN" cluster delete "$CLUSTER_NAME"
fi

echo "[1/6] 建立 k3d cluster"
"$K3D_BIN" cluster create "$CLUSTER_NAME" -p "8081:80@loadbalancer" --agents 1

echo "[2/6] 建置 Docker image"
docker build -t pi-k3s:latest .

echo "[3/6] 匯入 image 到 k3d"
"$K3D_BIN" image import pi-k3s:latest -c "$CLUSTER_NAME"

echo "[4/6] 套用 local manifests"
kubectl apply -f "$GENERATED_DIR"

echo "[5/6] 等待部署就緒"
kubectl wait --for=condition=available --timeout=240s deployment/mariadb -n "$NAMESPACE"
kubectl wait --for=condition=available --timeout=240s deployment/redis -n "$NAMESPACE"
kubectl wait --for=condition=available --timeout=240s deployment/laravel-app -n "$NAMESPACE"
kubectl wait --for=condition=available --timeout=240s deployment/laravel-worker -n "$NAMESPACE"

echo "[6/6] 狀態摘要"
kubectl get deployment,hpa -n "$NAMESPACE"
kubectl get pods -n "$NAMESPACE" -o wide

echo ""
echo "======================================"
echo "✓ 本機 K3s 驗證環境完成"
echo "======================================"
echo "URL: $APP_URL"
echo ""
echo "HPA 壓力測試（Windows PowerShell）:"
echo "  ./scripts/test-local-k3s-hpa.ps1"
echo ""
