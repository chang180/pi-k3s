# VPS Deployment Guide

## Overview

正式環境部署在 VPS 主機上直接執行（登入 SSH 後 clone、建置、部署），不從本機傳輸。

**Target VPS**: ubuntu@165.154.227.179
**Namespace**: pi-k3s
**K8s Distribution**: K3s (lightweight Kubernetes)

## Prerequisites（VPS 上）

- K3s 已安裝且運行中
- Docker 已安裝（用於建置映像）
- VPS 為 Ubuntu，至少 1GB RAM

## 部署方式（推薦）

### Method 1: VPS 端一鍵部署（正式環境主要方式）

**Script**: `scripts/deploy-on-vps.sh`

登入 VPS 後，clone 專案並執行部署腳本。

```bash
# 1. SSH 登入 VPS
ssh ubuntu@165.154.227.179

# 2. 首次需安裝 Docker（若尚未安裝）
sudo apt update && sudo apt install -y docker.io
sudo usermod -aG docker $USER
# 登出後重新 SSH 登入

# 3. Clone 專案
git clone https://github.com/chang180/pi-k3s.git
cd pi-k3s

# 4. 首次部署：從範本複製並填入 secrets、configmap、deployment
cp k8s/secrets.yaml.example k8s/secrets.yaml
cp k8s/configmap.yaml.example k8s/configmap.yaml
cp k8s/deployment.yaml.example k8s/deployment.yaml
# 編輯 secrets.yaml 填入 APP_KEY 等

# 5. 執行部署
chmod +x scripts/deploy-on-vps.sh
./scripts/deploy-on-vps.sh
```

**使用 Cursor / VS Code Remote SSH**：
1. 安裝 Remote - SSH 延伸
2. `Cmd/Ctrl + Shift + P` → "Remote-SSH: Connect to Host" → `ubuntu@165.154.227.179`
3. 連線後開啟專案目錄，可直接編輯、建置、部署、除錯

## 其他部署方式（保留，特殊情境用）

以下腳本從本機建置並傳輸至 VPS，保留供特殊情境（如 CI、自動化）使用。

### Method 2: 本機→VPS 傳輸部署

**Script**: `scripts/deploy-vps.sh`

需在本機安裝 Docker、kubectl，並設定 SSH 至 VPS。

```bash
# 從本機執行（需 SSH key 已設定）
./scripts/deploy-vps.sh
```

### Method 3: 手動引導

**Script**: `scripts/deploy-manual.sh`

### Method 4: Python 自動化

**Script**: `scripts/deploy-auto.py`

```bash
VPS_PASSWORD='your_password' python3 scripts/deploy-auto.py
```

## Step-by-Step Manual Deployment（於 VPS 上）

若需手動逐步操作，於 VPS 上執行：

### 1. Build Docker Image（於 VPS 上）

```bash
cd ~/pi-k3s  # 或你的專案路徑
docker build -t pi-k3s:latest .
```

### 2. Import Image to K3s

```bash
docker save pi-k3s:latest | sudo k3s ctr images import -
```

### 3. Apply Manifests

```bash
# 確保 secrets、configmap、deployment 已從 .example 複製並填入
sudo k3s kubectl apply -f k8s/namespace.yaml
sudo k3s kubectl apply -f k8s/configmap.yaml
sudo k3s kubectl apply -f k8s/secrets.yaml
sudo k3s kubectl apply -f k8s/deployment.yaml
sudo k3s kubectl apply -f k8s/service.yaml
sudo k3s kubectl apply -f k8s/ingress.yaml

# Wait for deployment
sudo k3s kubectl wait --for=condition=available --timeout=180s deployment/laravel-app -n pi-k3s
```

### 4. Verify

```bash
sudo k3s kubectl get pods -n pi-k3s
sudo k3s kubectl get svc -n pi-k3s
sudo k3s kubectl logs -n pi-k3s -l app=laravel -f
```

## Testing the Deployment

### Access the Application

```bash
# Application should be accessible at:
curl http://165.154.227.179
```

### Test the API

```bash
# Test calculation endpoint
curl -X POST http://165.154.227.179/api/calculate \
  -H 'Content-Type: application/json' \
  -d '{"total_points":100000}'

# Expected response: JSON with calculation results
```

### Query Calculation by UUID

```bash
# Use the UUID from the calculation response
curl http://165.154.227.179/api/calculate/{uuid}
```

## Troubleshooting

### Pods Not Starting

```bash
# Check pod status and events
kubectl describe pod -n pi-k3s <pod-name>

# Check logs
kubectl logs -n pi-k3s <pod-name>

# Common issues:
# - Image pull errors: Ensure imagePullPolicy: Never is set
# - Permission errors: Check secrets and configmap
# - Database errors: SQLite database needs write permissions
```

### Cannot Access Application

```bash
# Check if pods are running（於 VPS 上）
sudo k3s kubectl get pods -n pi-k3s

# Check service endpoints
sudo k3s kubectl get endpoints -n pi-k3s

# Check ingress rules
sudo k3s kubectl describe ingress -n pi-k3s

# View pod logs
sudo k3s kubectl logs -n pi-k3s -l app=laravel -f
```

### kubectl TLS Certificate Error (Step 7)

**Error**: `x509: certificate is valid for 10.41.98.152, ..., not 165.154.227.179`

**Cause**: K3s API server certificate does not include the public IP.

**Fix**: 在 VPS 上重新安裝 K3s（加入 `--tls-san`）：

```bash
# 於 VPS 上執行
sudo /usr/local/bin/k3s-uninstall.sh
curl -sfL https://get.k3s.io | sh -s - --tls-san 165.154.227.179
sleep 15
sudo systemctl status k3s
```

完成後重新執行 `./scripts/deploy-on-vps.sh` 部署。

### SSH Connection Issues

```bash
# Test SSH connection
ssh -v ubuntu@165.154.227.179

# Set up SSH key if not configured
ssh-copy-id ubuntu@165.154.227.179

# Or manually copy key
cat ~/.ssh/id_rsa.pub | ssh ubuntu@165.154.227.179 \
  "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys"
```

## Resource Monitoring

Monitor resource usage on VPS:

```bash
# Pod resource usage
sudo k3s kubectl top pod -n pi-k3s

# Node resource usage
sudo k3s kubectl top node

# Detailed pod description
sudo k3s kubectl describe pod -n pi-k3s <pod-name>
```

See `scripts/monitor-resources.sh` for automated monitoring.

## Updating the Application（於 VPS 上）

### Deploy New Version

```bash
cd ~/pi-k3s
git pull origin master
./scripts/deploy-on-vps.sh
```

## Cleanup

### Remove Deployment（於 VPS 上）

```bash
cd ~/pi-k3s
sudo k3s kubectl delete -f k8s/ingress.yaml
sudo k3s kubectl delete -f k8s/service.yaml
sudo k3s kubectl delete -f k8s/deployment.yaml
sudo k3s kubectl delete -f k8s/secrets.yaml
sudo k3s kubectl delete -f k8s/configmap.yaml
sudo k3s kubectl delete -f k8s/namespace.yaml
```

### Uninstall K3s

On the VPS:

```bash
/usr/local/bin/k3s-uninstall.sh
```

## Environment Variables

Key environment variables (configured in k8s/configmap.yaml and k8s/secrets.yaml):

- `APP_URL`: Application base URL (http://165.154.227.179)
- `DB_CONNECTION`: Database type (sqlite)
- `APP_KEY`: Laravel application key
- `APP_DEBUG`: Debug mode (false in production)

## Useful Commands（於 VPS 上）

```bash
# Get all resources in namespace
sudo k3s kubectl get all -n pi-k3s

# View pod logs
sudo k3s kubectl logs -n pi-k3s -l app=laravel -f

# Execute command in pod
sudo k3s kubectl exec -it -n pi-k3s <pod-name> -- /bin/sh

# Describe pod / deployment
sudo k3s kubectl describe pod -n pi-k3s -l app=laravel
sudo k3s kubectl describe deployment -n pi-k3s laravel-app

# Restart deployment
sudo k3s kubectl rollout restart deployment/laravel-app -n pi-k3s
```

## Security Considerations

- **SSH**: Use key-based authentication, disable password auth
- **Secrets**: Never commit secrets to version control
- **APP_KEY**: Generate unique key with `php artisan key:generate`
- **Firewall**: Configure UFW to allow only necessary ports (22, 80, 443)
- **Updates**: Keep K3s and system packages updated

## Performance Optimization

For 1C1G VPS:

- **Resource Limits**: Set appropriate CPU/memory limits (currently 500m/256Mi)
- **Replicas**: Start with 1 replica, scale based on monitoring
- **Database**: SQLite 適合 1C1G 低流量；無 MySQL/Redis 以節省資源

## Next Steps

After successful Phase 3 deployment:

- Monitor resource usage for 24-48 hours
- Document single-pod baseline metrics
- Plan Phase 4 HPA configuration based on actual resource consumption
- 1C1G 環境維持 SQLite + database queue，不增加 MySQL/Redis
