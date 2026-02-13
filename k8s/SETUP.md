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

### Database errors

```bash
# The pod uses SQLite by default
# If you see database errors, exec into the pod:
kubectl exec -it -n pi-k3s deployment/laravel-app -- sh

# Then check:
ls -la /var/www/html/database/
php artisan migrate --force
```
