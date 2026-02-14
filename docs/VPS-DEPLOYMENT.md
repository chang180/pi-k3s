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
