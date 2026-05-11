# Kubernetes Deployment Guide

## Prerequisites

- Docker installed
- Kubernetes cluster (K3s, Docker Desktop, minikube, or k3d)
- kubectl configured to access your cluster

## Docker Build and Test

### Build Docker Image

```bash
docker build -t pi-k3s:test .
```

### Test Docker Image Locally

```bash
# Run the container
docker run -p 8080:80 --name pi-k3s-test pi-k3s:test

# Test the application
curl http://localhost:8080
curl -X POST http://localhost:8080/api/calculate \
  -H "Content-Type: application/json" \
  -d '{"total_points":100000,"mode":"single"}'

# Clean up
docker stop pi-k3s-test
docker rm pi-k3s-test
```

## Kubernetes Deployment

### Setup Local DNS (Required)

Add the following entry to your `/etc/hosts` (Linux/Mac) or `C:\Windows\System32\drivers\etc\hosts` (Windows):

```bash
# For Docker Desktop Kubernetes or local K3s
127.0.0.1 pi-k3s.local

# For remote K3s cluster
<YOUR_K3S_IP> pi-k3s.local
```

On WSL2, you may need to update both Windows and WSL2 hosts files.

### Deploy to Kubernetes

Apply manifests in order (RBAC before deployment that uses the ServiceAccount):

```bash
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/secrets.yaml
kubectl apply -f k8s/serviceaccount.yaml
kubectl apply -f k8s/role.yaml
kubectl apply -f k8s/rolebinding.yaml
kubectl apply -f k8s/mariadb-pvc.yaml
kubectl apply -f k8s/mariadb-service.yaml
kubectl apply -f k8s/mariadb-deployment.yaml
kubectl apply -f k8s/redis-service.yaml
kubectl apply -f k8s/redis-deployment.yaml
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/worker-deployment.yaml
kubectl apply -f k8s/service.yaml
kubectl apply -f k8s/hpa.yaml
# Or apply all: kubectl apply -f k8s/
```

**RBAC**：`serviceaccount.yaml`、`role.yaml`、`rolebinding.yaml` 讓 Laravel Pod 可讀取 Pod 與 HPA 狀態（`GET /api/k8s/status`、`GET /api/k8s/metrics`）。Deployment 使用 `serviceAccountName: laravel-app`。

**HPA**：此專案在 K3s 單節點下維持 `web` 單副本，HPA 針對 `laravel-worker` 擴縮（min=1、max=2）。觸發門檻為 CPU 70%（以 worker CPU request 150m 計算，絕對值約 105m）。需啟用 metrics-server（K3s 預設啟用；勿以 `--disable=metrics-server` 安裝）。

**1G/1C 資源預算**：各元件 memory limits 合計 768Mi（調整前為 1130Mi），避免 1G 主機 OOM。MariaDB 以啟動參數限制 `innodb_buffer_pool_size=64M`，實際記憶體用量遠低於 limit 上限。如升級至更高規格，可調高 `hpa.yaml` 的 `maxReplicas` 與各 deployment 的 `limits`。

```bash
# Check deployment status
kubectl get all -n pi-k3s

# Check pods are running
kubectl get pods -n pi-k3s

# View logs
kubectl logs -n pi-k3s -l app=laravel --tail=100 -f
```

### Access the Application

#### Option 1: Through Ingress (Recommended)

If using K3s or Docker Desktop Kubernetes with Traefik:

1. Ensure `/etc/hosts` is configured (see above)
2. Access the application at: `http://pi-k3s.local`

#### Option 2: Port Forward (Alternative)

```bash
kubectl port-forward -n pi-k3s svc/laravel-service 8080:80
```

Then access: `http://localhost:8080` or `http://pi-k3s.local:8080` (if hosts file is configured)

### Test the API

```bash
# POST: Create calculation
curl -X POST http://localhost:8080/api/calculate \
  -H "Content-Type: application/json" \
  -d '{"total_points":1000000,"mode":"single"}'

# GET: Query calculation (replace {id} with actual ID from POST response)
curl http://localhost:8080/api/calculate/{id}
```

## Configuration

### Update Secrets

Before deploying to production, update the secrets:

```bash
# Generate a new Laravel APP_KEY
php artisan key:generate --show

# Encode it for Kubernetes Secret
echo -n 'base64:YOUR_GENERATED_KEY_HERE' | base64

# Update k8s/secrets.yaml with the encoded value
```

### Update ConfigMap

Edit `k8s/configmap.yaml` to update:
- `APP_URL`
- MariaDB connection settings
- Redis connection settings
- Other environment variables

### Update Ingress

For production deployment with a domain:

1. Edit `k8s/ingress.yaml`
2. Uncomment and update the host-based rule
3. Update the hostname to your actual domain

## Troubleshooting

### Check Pod Status

```bash
kubectl get pods -n pi-k3s
kubectl describe pod -n pi-k3s <pod-name>
```

### View Logs

```bash
# Application logs
kubectl logs -n pi-k3s -l app=laravel -f

# Nginx logs
kubectl exec -n pi-k3s <pod-name> -- tail -f /var/log/nginx/error.log
```

### Shell into Pod

```bash
kubectl exec -it -n pi-k3s <pod-name> -- sh
```

### Restart Deployment

```bash
kubectl rollout restart deployment/laravel-app -n pi-k3s
```

## Clean Up

```bash
# Delete all resources
kubectl delete -f k8s/

# Or delete namespace (will delete everything in it)
kubectl delete namespace pi-k3s
```

## Rebuild Image and Redeploy

```bash
# 1. Rebuild image
docker build -t pi-k3s:latest .

# 2. (Optional) Tag and push to registry, or on VPS load from tar
# docker save pi-k3s:latest | gzip > pi-k3s.tar.gz
# scp pi-k3s.tar.gz user@vps:/tmp/ && ssh user@vps 'sudo k3s ctr images import /tmp/pi-k3s.tar.gz'

# 3. Restart deployment to pick up new image
kubectl rollout restart deployment/laravel-app -n pi-k3s
kubectl rollout status deployment/laravel-app -n pi-k3s
```

## Runtime Layout

| 元件 | 副本 | Memory Request / Limit | CPU Request / Limit | 說明 |
|---|---|---|---|---|
| `laravel-app` | 1（固定） | 64Mi / 192Mi | 50m / 500m | web pod，hostPort 80/443 對外 |
| `laravel-worker` | 1–2（HPA） | 96Mi / 192Mi | 150m / 600m | queue worker，負責分散式計算 |
| `mariadb` | 1 | 128Mi / 256Mi | 100m / 500m | 正式環境資料庫，innodb_buffer_pool=64M |
| `redis` | 1 | 32Mi / 128Mi | 25m / 100m | queue / cache / session / lock，maxmemory 64mb |

本地開發可繼續使用 SQLite；正式環境請參考 [docs/PRODUCTION-ENV.md](../docs/PRODUCTION-ENV.md)。
