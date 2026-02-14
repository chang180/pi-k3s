# VPS Deployment Guide

## Overview

This guide provides instructions for deploying the pi-k3s application to a remote VPS running K3s.

**Target VPS**: ubuntu@165.154.227.179
**Namespace**: pi-k3s
**K8s Distribution**: K3s (lightweight Kubernetes)
**Ingress**: Traefik (default K3s ingress controller)

## Prerequisites

- Docker installed locally
- kubectl installed locally
- SSH access to VPS
- VPS running Ubuntu with at least 1GB RAM

## Deployment Methods

We provide several deployment scripts to suit different needs:

### Method 1: Automated Deployment (Recommended)

**Script**: `scripts/deploy-vps.sh`

This script automates the entire deployment process, including:
- Building Docker image locally
- Transferring image to VPS
- Installing K3s (if not present)
- Loading image into K3s
- Deploying to Kubernetes

**Requirements**: SSH key authentication must be configured

```bash
# Run the automated deployment
./scripts/deploy-vps.sh
```

The script will set up SSH keys automatically if they're not already configured.

### Method 2: Manual Deployment

**Script**: `scripts/deploy-manual.sh`

Step-by-step guided deployment with manual intervention at each step.

```bash
./scripts/deploy-manual.sh
```

### Method 3: Python Deployment (Alternative)

**Script**: `scripts/deploy-auto.py`

Python-based deployment using paramiko for SSH.

```bash
VPS_PASSWORD='your_password' python3 scripts/deploy-auto.py
```

### Method 4: Deploy from VPS (Direct - 推薦除錯用)

**適用情境**：登入 VPS，在該主機上 clone repo、建置、部署，可直接除錯。

**優點**：
- 不需傳輸大型 Docker 映像
- 建置與執行都在同一台機器，迭代更快
- 可用 Cursor / VS Code Remote SSH 直接編輯、除錯

**VPS 前置需求**：
- K3s 已安裝且運行中
- Docker 已安裝（用於建置）

```bash
# 1. SSH 登入 VPS
ssh ubuntu@165.154.227.179

# 2. 首次需安裝 Docker（若尚未安裝）
sudo apt update && sudo apt install -y docker.io
sudo usermod -aG docker $USER
# 登出後重新 SSH 登入，使 docker 群組生效

# 3. Clone 專案（或使用 Cursor Remote 連線後在遠端 clone）
git clone https://github.com/YOUR_ORG/pi-k3s.git
cd pi-k3s

# 4. 首次部署需設定 k8s/secrets.yaml（APP_KEY、DB_PASSWORD 等）
#    可從本機 scp：scp k8s/secrets.yaml ubuntu@165.154.227.179:~/pi-k3s/k8s/

# 5. 執行 VPS 端部署腳本
chmod +x scripts/deploy-on-vps.sh
./scripts/deploy-on-vps.sh
```

**使用 Cursor Remote SSH**：
1. 安裝 Cursor（或 VS Code）的 Remote - SSH 延伸
2. `Cmd/Ctrl + Shift + P` → "Remote-SSH: Connect to Host"
3. 輸入 `ubuntu@165.154.227.179`
4. 連線後在終端執行 `git clone ...` 或開啟既有專案目錄
5. 在遠端專案內執行 `./scripts/deploy-on-vps.sh` 部署
6. 除錯時可直接執行 `kubectl logs`、`kubectl exec` 等指令

## Step-by-Step Manual Deployment

If you prefer to deploy manually or troubleshoot issues, follow these steps:

### 1. Build Docker Image

```bash
# Build image with timestamp tag
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
docker build -t pi-k3s:latest -t pi-k3s:$TIMESTAMP .
```

### 2. Save and Transfer Image

```bash
# Save image to tar.gz
docker save pi-k3s:latest | gzip > /tmp/pi-k3s-image.tar.gz

# Transfer to VPS
scp /tmp/pi-k3s-image.tar.gz ubuntu@165.154.227.179:/tmp/

# Clean up local file
rm /tmp/pi-k3s-image.tar.gz
```

### 3. Install K3s on VPS

SSH to VPS and install K3s:

```bash
ssh ubuntu@165.154.227.179

# Install K3s
curl -sfL https://get.k3s.io | sh -

# Wait for K3s to start
sudo systemctl status k3s

# Verify installation
sudo k3s kubectl get nodes
```

### 4. Load Docker Image on VPS

```bash
# Still on VPS
sudo k3s ctr images import /tmp/pi-k3s-image.tar.gz

# Verify image is loaded
sudo k3s ctr images ls | grep pi-k3s

# Clean up
rm /tmp/pi-k3s-image.tar.gz
```

### 5. Setup kubectl Access

Back on your local machine:

```bash
# Copy kubeconfig from VPS
mkdir -p ~/.kube
scp ubuntu@165.154.227.179:/etc/rancher/k3s/k3s.yaml ~/.kube/config-pi-k3s

# Update server address
sed -i.bak "s/127.0.0.1/165.154.227.179/g" ~/.kube/config-pi-k3s

# Set as current kubeconfig
export KUBECONFIG=~/.kube/config-pi-k3s

# Test connection
kubectl get nodes
```

### 6. Update Deployment Manifest

Ensure the deployment uses the local image:

```bash
# Update image reference
sed -i "s|image:.*pi-k3s.*|image: pi-k3s:latest|g" k8s/deployment.yaml

# Ensure imagePullPolicy is set to Never
# Add this line after the image line if not present:
#   imagePullPolicy: Never
```

### 7. Deploy to K3s

```bash
# Apply all manifests in order
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/secrets.yaml
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
kubectl apply -f k8s/ingress.yaml

# Wait for deployment to be ready
kubectl wait --for=condition=available --timeout=180s deployment/laravel-app -n pi-k3s
```

### 8. Verify Deployment

```bash
# Check pod status
kubectl get pods -n pi-k3s

# Check service
kubectl get svc -n pi-k3s

# Check ingress
kubectl get ingress -n pi-k3s

# View logs
kubectl logs -n pi-k3s -l app=laravel -f
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
# Check if pods are running
kubectl get pods -n pi-k3s

# Check service endpoints
kubectl get endpoints -n pi-k3s

# Check Traefik ingress controller
kubectl get pods -n kube-system | grep traefik

# Check ingress rules
kubectl describe ingress -n pi-k3s
```

### kubectl TLS Certificate Error (Step 7)

**Error**: `x509: certificate is valid for 10.41.98.152, ..., not 165.154.227.179`

**Cause**: K3s API server certificate does not include the public IP.

**Fix**: Reinstall K3s with `--tls-san` on the VPS:

```bash
ssh ubuntu@165.154.227.179
sudo /usr/local/bin/k3s-uninstall.sh
curl -sfL https://get.k3s.io | sh -s - --tls-san 165.154.227.179
sleep 15
exit
```

Then re-run `./scripts/deploy-vps.sh` from the start (image will be re-transferred and loaded).

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

Monitor resource usage to optimize for 1C1G VPS:

```bash
# Pod resource usage
kubectl top pod -n pi-k3s

# Node resource usage
kubectl top node

# Detailed pod description
kubectl describe pod -n pi-k3s <pod-name>
```

See `scripts/monitor-resources.sh` for automated monitoring.

## Updating the Application

### Deploy New Version

```bash
# Build new image
docker build -t pi-k3s:latest .

# Save and transfer
docker save pi-k3s:latest | gzip > /tmp/pi-k3s-image.tar.gz
scp /tmp/pi-k3s-image.tar.gz ubuntu@165.154.227.179:/tmp/

# Load on VPS
ssh ubuntu@165.154.227.179 "sudo k3s ctr images import /tmp/pi-k3s-image.tar.gz && rm /tmp/pi-k3s-image.tar.gz"

# Restart deployment
kubectl rollout restart deployment/laravel-app -n pi-k3s

# Monitor rollout
kubectl rollout status deployment/laravel-app -n pi-k3s
```

## Cleanup

### Remove Deployment

```bash
# Delete all resources
kubectl delete -f k8s/ingress.yaml
kubectl delete -f k8s/service.yaml
kubectl delete -f k8s/deployment.yaml
kubectl delete -f k8s/secrets.yaml
kubectl delete -f k8s/configmap.yaml
kubectl delete -f k8s/namespace.yaml
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

## Useful Commands

```bash
# Set kubeconfig for all terminal sessions
export KUBECONFIG=~/.kube/config-pi-k3s

# Get all resources in namespace
kubectl get all -n pi-k3s

# Execute command in pod
kubectl exec -it -n pi-k3s <pod-name> -- /bin/sh

# Port forward for local testing
kubectl port-forward -n pi-k3s svc/laravel-service 8080:80

# View resource limits
kubectl describe deployment -n pi-k3s laravel-app
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
- **Database**: SQLite is suitable for low traffic; upgrade to MySQL for higher load
- **Caching**: Consider Redis for session/cache in Phase 4

## Next Steps

After successful Phase 3 deployment:

- Monitor resource usage for 24-48 hours
- Document single-pod baseline metrics
- Plan Phase 4 HPA configuration based on actual resource consumption
- Consider adding MySQL and Redis for production workloads
