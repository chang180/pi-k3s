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
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
kubectl apply -f k8s/hpa.yaml
# Or apply all: kubectl apply -f k8s/
```

**RBAC**：`serviceaccount.yaml`、`role.yaml`、`rolebinding.yaml` 讓 Laravel Pod 可讀取 Pod 與 HPA 狀態（`GET /api/k8s/status`、`GET /api/k8s/metrics`）。Deployment 使用 `serviceAccountName: laravel-app`。

**HPA**：需啟用 metrics-server（K3s 預設啟用；勿以 `--disable=metrics-server` 安裝）。

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
- Database connection settings（1C1G 使用 SQLite）
- QUEUE_CONNECTION=database（1C1G 無 Redis）
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

## Next Steps

- Phase 4: HPA、分散式計算、K8s API、Laravel database queue 與 Worker
- HPA (min=1, max=2) 已配置；需啟用 metrics-server
- QUEUE_CONNECTION=database；Supervisor 內含 queue worker
