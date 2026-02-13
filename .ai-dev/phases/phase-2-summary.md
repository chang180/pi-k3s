# Phase 2 實作總結

## ✅ 已完成的工作

### Docker 容器化

1. **Dockerfile** - 多階段建置
   - Stage 1: Node.js 前端建置（包含 PHP 8.4 支援 Wayfinder）
   - Stage 2: PHP 8.4 FPM + Nginx 運行環境
   - 優化：使用 Alpine Linux、OpCache、分層快取

2. **.dockerignore** - 排除不必要檔案
   - 減少映像大小
   - 保護敏感資訊

3. **docker/** 配置檔案
   - `nginx.conf` - Nginx 主配置
   - `default.conf` - Laravel 虛擬主機
   - `supervisord.conf` - 進程管理
   - `entrypoint.sh` - 啟動腳本（支援自動遷移）
   - `test.sh` - 自動化測試腳本

4. **docker-compose.yml** - 本機測試用（可選）

### Kubernetes 部署

5. **k8s/namespace.yaml** - pi-k3s namespace

6. **k8s/configmap.yaml** - 環境變數配置
   - APP_URL: `http://pi-k3s.local`
   - Database: SQLite (本階段)
   - Cache/Session: file driver

7. **k8s/secrets.yaml** - 敏感資訊
   - APP_KEY (需更新為實際金鑰)
   - DB_PASSWORD (佔位)

8. **k8s/deployment.yaml** - Laravel 應用部署
   - Replicas: 1 (Phase 3 之前)
   - Resources:
     - Requests: 128Mi memory, 100m CPU
     - Limits: 256Mi memory, 500m CPU
   - Health checks: liveness + readiness probes
   - 環境變數: 從 ConfigMap/Secret 注入

9. **k8s/service.yaml** - ClusterIP 服務
   - Port 80 內部訪問

10. **k8s/ingress.yaml** - Traefik Ingress
    - Host: `pi-k3s.local`
    - 支援 IP 直接訪問（fallback）

11. **k8s/README.md** - 部署指南

12. **k8s/SETUP.md** - 快速設定指南

## 🔧 技術要點

### Dockerfile 特色

- **多階段建置**：分離前端建置和運行環境
- **PHP 8.4**：滿足 Laravel 12 需求
- **Wayfinder 支援**：前端建置階段包含 PHP 用於生成 TypeScript 類型
- **SQLite 預設**：簡化部署，無需外部數據庫
- **自動遷移**：透過環境變數 `AUTO_MIGRATE=true` 控制

### Kubernetes 配置

- **資源限制**：符合 VPS 優化方案
- **健康檢查**：確保 Pod 穩定運行
- **環境分離**：ConfigMap (非敏感) + Secrets (敏感)
- **彈性擴展**：為 Phase 3 HPA 準備架構

### 本機域名

- **使用 `pi-k3s.local`**：與 .env 保持一致
- **Hosts 配置**：需更新 `/etc/hosts` 或 Windows hosts 文件
- **WSL2 注意**：可能需要更新 Windows 和 WSL2 兩個 hosts 文件

## 🚀 驗收方式

### Docker 測試

```bash
# 1. 建置映像
docker build -t pi-k3s:test .

# 2. 執行自動化測試
bash docker/test.sh

# 3. 手動測試
docker run -p 8080:80 pi-k3s:test
curl http://localhost:8080/api/calculate \
  -X POST \
  -H "Content-Type: application/json" \
  -d '{"total_points":100000}'
```

### Kubernetes 測試

```bash
# 1. 配置 hosts
echo "127.0.0.1 pi-k3s.local" | sudo tee -a /etc/hosts

# 2. 更新 Secret 的 APP_KEY
# (見 k8s/SETUP.md)

# 3. 部署
kubectl apply -f k8s/

# 4. 檢查狀態
kubectl get pods -n pi-k3s
kubectl logs -n pi-k3s -l app=laravel -f

# 5. 訪問應用
# 透過 Ingress: http://pi-k3s.local
# 或 Port-forward: kubectl port-forward -n pi-k3s svc/laravel-service 8080:80
```

## 📝 已解決的建置問題

以下問題已於 Dockerfile 中實作對應解決方案：

### 1. Wayfinder 建置問題（已解決）

**問題**：Wayfinder Vite 插件需要 PHP 執行 artisan 命令  
**解決**：Stage 1 前端建置階段已安裝 PHP 8.4 + Composer + 必要擴展，`npm run build` 時 Wayfinder 可正常執行

### 2. PHP 版本需求（已解決）

**問題**：Laravel 12 需要 PHP 8.4  
**解決**：Stage 1 使用 Alpine `php84` 套件；Stage 2 使用 `php:8.4-fpm-alpine` 官方映像；已添加 bcmath、curl、ctype 等擴展

### 3. Platform Requirements（已解決）

**問題**：建置環境與運行環境的 PHP 版本可能不同（如 CI 主機、跨平台 build）  
**解決**：Stage 1 與 Stage 2 的 `composer install` 皆已加入 `--ignore-platform-reqs`

## 🔄 下一階段準備

Phase 3 需要的基礎已完成：

- ✅ 容器化應用可運行
- ✅ Kubernetes 基本部署架構
- ✅ 環境變數分離 (ConfigMap/Secrets)
- ✅ 資源限制配置
- ✅ Health checks

Phase 3 將添加：

- Queue 系統（分散式計算）
- HPA 自動擴展
- Redis (可選，用於 cache/queue)
- MySQL/PostgreSQL (可選，替代 SQLite)

## 📚 參考文件

- **部署指南**: `k8s/README.md`
- **快速設定**: `k8s/SETUP.md`
- **測試腳本**: `docker/test.sh`
- **Docker Compose**: `docker-compose.yml`
