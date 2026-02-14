# Phase 3 Implementation Summary

## Overview

Phase 3 focuses on deploying the pi-k3s application to a remote VPS (1C1G Ubuntu server) running K3s.

**Status**: Scripts and Documentation Ready
**Target VPS**: ubuntu@165.154.227.179
**Completion Date**: 2026-02-14

## Deliverables

### 1. Deployment Scripts

Created multiple deployment scripts to suit different scenarios:

#### Primary Scripts（正式環境）

- **`scripts/deploy-on-vps.sh`** - VPS 端部署（正式環境主要方式）
  - 登入 VPS 後 clone、建置、部署
  - 不需從本機傳輸映像
  - 可用 Cursor Remote SSH 直接編輯、除錯

- **`scripts/monitor-resources.sh`** - Resource monitoring and analysis
  - Monitors CPU, memory, pod status
  - Provides HPA recommendations
  - Supports watch mode and metric export

#### Alternative Scripts（保留，特殊情境）

- **`scripts/deploy-vps.sh`** - 本機建置後 SSH 傳輸至 VPS（如 CI、自動化）

- **`scripts/deploy-manual.sh`** - Step-by-step manual deployment guide
  - Interactive prompts at each step
  - Useful for troubleshooting
  - Educational for understanding the process

- **`scripts/deploy-auto.py`** - Python-based automated deployment
  - Uses paramiko for SSH
  - Requires password via environment variable
  - Note: May require SSH password authentication enabled on VPS

- **`scripts/deploy-to-vps.sh`** - Alternative bash deployment script
  - Chinese comments for easier understanding
  - SSH key setup included

- **`scripts/setup-ssh-key.sh`** - SSH key configuration helper
  - Generates SSH key if needed
  - Copies public key to VPS
  - Tests connection

### 2. Documentation

- **`docs/VPS-DEPLOYMENT.md`** - Comprehensive deployment guide
  - Step-by-step manual deployment instructions
  - Troubleshooting section
  - Resource monitoring guidelines
  - Security best practices
  - Update procedures

- **`docs/PHASE-3-SUMMARY.md`** - This file
  - Implementation overview
  - Next steps for the user

## Deployment Process（於 VPS 上）

正式環境部署在 VPS 主機上直接執行，不從本機傳輸。

1. **SSH 登入 VPS** - `ssh ubuntu@165.154.227.179`
2. **Clone 專案** - `git clone https://github.com/chang180/pi-k3s.git && cd pi-k3s`
3. **設定環境檔**（首次）- 從 `.example` 複製 secrets、configmap、deployment 並填入實際值
4. **執行部署** - `./scripts/deploy-on-vps.sh`

腳本會：Build Docker Image → Import to K3s → Apply manifests

## Technical Architecture

### Docker Image

- **Base Image**: PHP 8.4 FPM Alpine
- **Size**: ~1.31 GB (uncompressed), ~306 MB (compressed)
- **Multi-stage Build**:
  - Stage 1: Node.js 20 for frontend build
  - Stage 2: PHP 8.4 runtime with Nginx + Supervisor

### Kubernetes Configuration

- **Distribution**: K3s (lightweight Kubernetes)
- **Ingress Controller**: Traefik (K3s default)
- **Namespace**: pi-k3s
- **Resources**:
  - CPU Request: 100m, Limit: 500m
  - Memory Request: 128Mi, Limit: 256Mi
- **Replicas**: 1 (suitable for 1C1G VPS)

### Application Components

- **Deployment**: Laravel application with PHP-FPM + Nginx
- **Service**: ClusterIP on port 80
- **Ingress**: HTTP routing to VPS IP
- **ConfigMap**: Environment variables (APP_URL, DB_CONNECTION, etc.)
- **Secret**: Sensitive data (APP_KEY)
- **Database**: SQLite (file-based)

## 部署建議

正式環境直接登入 VPS 部署，不從本機傳輸。詳見 [DEPLOY-NOW.md](../DEPLOY-NOW.md)。

```bash
# 1. SSH 登入 VPS
ssh ubuntu@165.154.227.179

# 2. Clone、設定、部署
git clone https://github.com/chang180/pi-k3s.git && cd pi-k3s
cp k8s/secrets.yaml.example k8s/secrets.yaml  # 填入 APP_KEY
cp k8s/configmap.yaml.example k8s/configmap.yaml
cp k8s/deployment.yaml.example k8s/deployment.yaml
./scripts/deploy-on-vps.sh
```

## Resource Monitoring

After successful deployment, use the monitoring script:

```bash
# One-time check
./scripts/monitor-resources.sh

# Continuous monitoring (updates every 10 seconds)
./scripts/monitor-resources.sh --watch

# Export metrics to file
./scripts/monitor-resources.sh --export
```

Monitor for 24-48 hours to gather baseline metrics for Phase 4 HPA configuration.

## Testing Checklist

After deployment（於 VPS 上）, verify:

- [ ] Pods are running: `sudo k3s kubectl get pods -n pi-k3s`
- [ ] Service is accessible: `sudo k3s kubectl get svc -n pi-k3s`
- [ ] Ingress is configured: `sudo k3s kubectl get ingress -n pi-k3s`
- [ ] Application responds: `curl http://165.154.227.179`
- [ ] API works: Test POST to `/api/calculate`
- [ ] Logs are clean: `sudo k3s kubectl logs -n pi-k3s -l app=laravel`
- [ ] No restarts: Check pod restart count
- [ ] Resource usage is normal: `sudo k3s kubectl top pod -n pi-k3s`

## Known Limitations

1. **Single Replica**: Only 1 pod due to 1C1G VPS constraints
2. **No HA**: No high availability configuration
3. **SQLite**: Single-file database (not suitable for multiple replicas)
4. **No TLS**: HTTP only (HTTPS can be added in Phase 4)
5. **No Persistent Storage**: Data stored in pod (use PVC in Phase 4 if needed)

## Security Considerations

Current security measures:

- SSH key-based authentication (recommended)
- Application secrets stored in K8s Secret
- APP_DEBUG set to false
- No sensitive data in ConfigMap

Additional security measures to consider:

- Configure UFW firewall on VPS
- Set up fail2ban for SSH protection
- Add TLS/HTTPS (cert-manager + Let's Encrypt)
- Implement network policies
- Regular security updates

## Cost and Performance

**VPS Specifications**:
- 1 vCPU
- 1 GB RAM
- Ubuntu OS
- IP: 165.154.227.179

**Expected Performance**:
- Handles ~10-50 concurrent requests
- Suitable for development/testing
- Calculation API may take 2-10 seconds for large point counts
- Response times under 200ms for small requests

## Troubleshooting Guide

### Common Issues

**Issue**: Pods stuck in ImagePullBackOff
**Solution**: Ensure `imagePullPolicy: Never` is set in deployment.yaml

**Issue**: Pods stuck in CrashLoopBackOff
**Solution**: Check logs with `sudo k3s kubectl logs -n pi-k3s <pod-name>`

**Issue**: Cannot access application externally
**Solution**:
- Check ingress: `sudo k3s kubectl get ingress -n pi-k3s`
- Verify Traefik: `sudo k3s kubectl get pods -n kube-system | grep traefik`
- Check VPS firewall: `sudo ufw status`

**Issue**: Out of memory errors
**Solution**: Increase memory limits or upgrade VPS

**Issue**: Database permission errors
**Solution**: Check volume mounts and file permissions

## Next Steps (Phase 4 Preview)

Phase 4 will implement:

1. **Horizontal Pod Autoscaler (HPA)**
   - Based on CPU/memory metrics
   - Auto-scale from 1-3 replicas

2. **MySQL Database**
   - Replace SQLite with MySQL StatefulSet
   - Persistent storage with PVC

3. **Redis Cache**
   - Session and cache storage
   - Improve performance

4. **Advanced Monitoring**
   - Prometheus metrics
   - Grafana dashboards

5. **Additional Optimizations**
   - TLS/HTTPS support
   - CDN integration
   - Performance tuning

## Files Created in Phase 3

```
scripts/
├── deploy-on-vps.sh        # VPS 端部署（正式環境主要入口）
├── deploy-vps.sh           # 本機→VPS 傳輸部署（保留，特殊情境用）
├── deploy-manual.sh        # Manual step-by-step deployment
├── deploy-auto.py          # Python automated deployment
├── deploy-to-vps.sh        # Alternative bash deployment
├── setup-ssh-key.sh        # SSH key configuration
└── monitor-resources.sh    # Resource monitoring

docs/
├── VPS-DEPLOYMENT.md       # Comprehensive deployment guide
└── PHASE-3-SUMMARY.md      # This file
```

## Conclusion

Phase 3 provides comprehensive deployment infrastructure for VPS deployment:

✅ VPS 端直接部署（deploy-on-vps.sh）為正式環境主要方式
✅ Detailed documentation with troubleshooting
✅ Resource monitoring and analysis tools
✅ Security best practices
✅ Clear path to Phase 4 scaling

**Action Required**: 登入 VPS 後 clone 專案並執行 `./scripts/deploy-on-vps.sh` 完成部署。

## Quick Start for User

```bash
# 1. SSH 登入 VPS
ssh ubuntu@165.154.227.179

# 2. Clone、設定、部署
git clone https://github.com/chang180/pi-k3s.git && cd pi-k3s
cp k8s/secrets.yaml.example k8s/secrets.yaml  # 填入 APP_KEY
cp k8s/configmap.yaml.example k8s/configmap.yaml
cp k8s/deployment.yaml.example k8s/deployment.yaml
./scripts/deploy-on-vps.sh

# 3. Test the application
curl -X POST http://165.154.227.179/api/calculate \
  -H 'Content-Type: application/json' \
  -d '{"total_points":100000}'
```

For detailed instructions, see: [DEPLOY-NOW.md](../DEPLOY-NOW.md) 或 `docs/VPS-DEPLOYMENT.md`
