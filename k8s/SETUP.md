# Quick Setup Guide

## 1. Configure Local DNS

### On Linux / Mac / WSL2

Add to `/etc/hosts`:

```bash
sudo nano /etc/hosts
```

Add this line:
```
127.0.0.1 pi-k3s.local
```

### On Windows

Add to `C:\Windows\System32\drivers\etc\hosts` (run as Administrator):

```
127.0.0.1 pi-k3s.local
```

### On WSL2 (Important!)

You may need to update BOTH Windows and WSL2 hosts files:

1. **Windows hosts**: `C:\Windows\System32\drivers\etc\hosts`
2. **WSL2 hosts**: `/etc/hosts`

## 2. Generate APP_KEY for Kubernetes

```bash
# Generate a new key
php artisan key:generate --show

# The output will be something like:
# base64:XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX

# Encode it for Kubernetes secret
echo -n 'base64:XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX' | base64

# Update k8s/secrets.yaml with the encoded value
```

## 3. Deploy to Kubernetes

```bash
# Apply all manifests
kubectl apply -f k8s/

# Wait for deployment
kubectl wait --for=condition=available --timeout=60s deployment/laravel-app -n pi-k3s

# Check status
kubectl get pods -n pi-k3s
```

## 4. Access the Application

Open browser and go to: **http://pi-k3s.local**

## Troubleshooting

### Can't access pi-k3s.local

1. Check hosts file is configured correctly
2. Flush DNS cache:
   - Linux/Mac: `sudo dscacheutil -flushcache` or `sudo systemd-resolve --flush-caches`
   - Windows: `ipconfig /flushdns`
3. Try accessing via port-forward:
   ```bash
   kubectl port-forward -n pi-k3s svc/laravel-service 8080:80
   # Then visit http://localhost:8080
   ```

### Pod not starting

```bash
# Check logs
kubectl logs -n pi-k3s -l app=laravel

# Describe pod for events
kubectl describe pod -n pi-k3s -l app=laravel

# Common issues:
# - APP_KEY not set correctly
# - Image pull failed (check image name in deployment.yaml)
# - Resource constraints (check limits/requests)
```

### 主機 OOM / 記憶體不足（1G/1C 主機）

各元件 memory limits 合計約 768Mi，加上 k3s 本身約 170Mi，**接近 1G 主機上限**。
若系統 OOM 重開機，請確認以下設定是否正確（各檔案對應的關鍵值）：

| 檔案 | 關鍵設定 |
|---|---|
| `mariadb-deployment.yaml` | `--innodb-buffer-pool-size=64M`、limits memory `256Mi` |
| `worker-deployment.yaml` | limits memory `192Mi` |
| `hpa.yaml` | `maxReplicas: 2`、`averageUtilization: 70` |

```bash
# 查看目前資源分配
kubectl describe nodes | grep -A8 "Allocated resources"

# 查看各 pod 實際用量
kubectl top pods -n pi-k3s
```

### Database errors

```bash
# Production K3s uses MariaDB. Check the mariadb pod and DB secrets first.
# If you see database errors, exec into the pod:
kubectl exec -it -n pi-k3s deployment/laravel-app -- sh

# Then check:
php artisan migrate --force
```
