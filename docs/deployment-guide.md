# 部署指南

本文件說明如何將 Pi-K3s 部署到 1C1G VPS（Ubuntu + K3s）。

## 前置條件

### VPS 需求

- Ubuntu 22.04+ (或相容 Debian 系統)
- 至少 1 vCPU、1GB RAM
- 對外 IP（可從外網存取）
- SSH 存取權限

### 軟體需求（VPS 上）

- **Docker**：用於建置映像
- **K3s**：輕量級 Kubernetes
- **Git**：用於 clone 專案

## 步驟 1：VPS 初始設定

```bash
# SSH 登入 VPS
ssh ubuntu@<YOUR_VPS_IP>

# 更新系統
sudo apt update && sudo apt upgrade -y

# 安裝 Docker
sudo apt install -y docker.io
sudo usermod -aG docker $USER
# 登出後重新 SSH 登入，使 docker group 生效
```

## 步驟 2：安裝 K3s

```bash
# 安裝 K3s（停用 Traefik 以節省記憶體，保留 metrics-server 供 HPA）
curl -sfL https://get.k3s.io | sh -s - \
  --disable traefik \
  --disable servicelb \
  --tls-san <YOUR_VPS_IP>

# 等待 K3s 就緒
sleep 15
sudo systemctl status k3s

# 驗證
sudo k3s kubectl get nodes
```

> **重要**：`--tls-san` 需加入 VPS 的對外 IP，否則遠端 kubectl 會出現 TLS 憑證錯誤。

## 步驟 3：Clone 專案

```bash
git clone https://github.com/chang180/pi-k3s.git
cd pi-k3s
```

## 步驟 4：設定環境變數

從範本複製並填入實際值：

```bash
cp k8s/secrets.yaml.example k8s/secrets.yaml
cp k8s/configmap.yaml.example k8s/configmap.yaml
cp k8s/deployment.yaml.example k8s/deployment.yaml
cp k8s/worker-deployment.yaml.example k8s/worker-deployment.yaml
cp k8s/mariadb-deployment.yaml.example k8s/mariadb-deployment.yaml
cp k8s/mariadb-pvc.yaml.example k8s/mariadb-pvc.yaml
```

### secrets.yaml

```bash
# 產生 APP_KEY（需在有 PHP 環境的機器上，或直接用 base64 編碼填入）
# 格式：base64 編碼的 "base64:xxxxxxx"
vi k8s/secrets.yaml
```

### configmap.yaml

```bash
# 修改 APP_URL 為你的域名或 IP
# DB_* 設定為 MariaDB
# REDIS_HOST 預設為同 namespace 的 redis Service
vi k8s/configmap.yaml
```

### deployment.yaml / worker-deployment.yaml

```bash
# deployment.yaml 是 web pod
# worker-deployment.yaml 是 queue worker
vi k8s/deployment.yaml
vi k8s/worker-deployment.yaml
vi k8s/mariadb-deployment.yaml
```

## 步驟 5：建置 Docker 映像

```bash
docker build -t pi-k3s:latest .

# 匯入映像到 K3s
docker save pi-k3s:latest | sudo k3s ctr images import -
```

## 步驟 6：部署到 K3s

按順序 apply K8s manifests：

```bash
# 1. Namespace
sudo k3s kubectl apply -f k8s/namespace.yaml

# 2. RBAC（ServiceAccount、Role、RoleBinding）
sudo k3s kubectl apply -f k8s/serviceaccount.yaml
sudo k3s kubectl apply -f k8s/role.yaml
sudo k3s kubectl apply -f k8s/rolebinding.yaml

# 3. 設定（ConfigMap、Secrets）
sudo k3s kubectl apply -f k8s/configmap.yaml
sudo k3s kubectl apply -f k8s/secrets.yaml

# 4. 資料層（MariaDB + Redis）
sudo k3s kubectl apply -f k8s/mariadb-pvc.yaml
sudo k3s kubectl apply -f k8s/mariadb-service.yaml
sudo k3s kubectl apply -f k8s/mariadb-deployment.yaml
sudo k3s kubectl apply -f k8s/redis-service.yaml
sudo k3s kubectl apply -f k8s/redis-deployment.yaml

# 5. 應用（Web、Worker、Service）
sudo k3s kubectl apply -f k8s/deployment.yaml
sudo k3s kubectl apply -f k8s/worker-deployment.yaml
sudo k3s kubectl apply -f k8s/service.yaml

# 6. Ingress（若使用 Traefik）
sudo k3s kubectl apply -f k8s/ingress.yaml

# 7. HPA（worker 自動擴展）
sudo k3s kubectl apply -f k8s/hpa.yaml

# 等待 Deployment 就緒
sudo k3s kubectl wait --for=condition=available \
  --timeout=180s deployment/laravel-app -n pi-k3s
```

或使用一鍵部署腳本：

```bash
chmod +x scripts/deploy-on-vps.sh
./scripts/deploy-on-vps.sh
```

## 步驟 7：驗證部署

### 確認 Pod 運行

```bash
sudo k3s kubectl get pods -n pi-k3s
# 預期至少包含：
# laravel-app-xxx      1/1   Running
# laravel-worker-xxx   1/1   Running
# mariadb-xxx          1/1   Running
# redis-xxx            1/1   Running
```

### 確認 Service

```bash
sudo k3s kubectl get svc -n pi-k3s
```

### 測試 API

```bash
# 健康檢查
curl http://<YOUR_VPS_IP>

# 計算 API
curl -X POST http://<YOUR_VPS_IP>/api/calculate \
  -H 'Content-Type: application/json' \
  -d '{"total_points":100000}'

# K8s 狀態
curl http://<YOUR_VPS_IP>/api/k8s/status

# 歷史記錄
curl http://<YOUR_VPS_IP>/api/history
```

### 確認 HPA

```bash
sudo k3s kubectl get hpa -n pi-k3s
# 預期：laravel-worker   Deployment/laravel-worker   <cpu>%/60%   1   2
```

## 步驟 8：HTTPS 設定（可選）

```bash
# 安裝 certbot
sudo apt install -y certbot

# 取得憑證（先暫停 K3s 佔用的 80 port，或使用 DNS 驗證）
sudo certbot certonly --standalone -d your-domain.example.com

# 在 k8s/deployment.yaml 中啟用 SSL 相關設定
# 重新 apply deployment
sudo k3s kubectl apply -f k8s/deployment.yaml
```

## 更新部署

```bash
cd ~/pi-k3s
git pull origin master

# 重建映像並部署
docker build -t pi-k3s:latest .
docker save pi-k3s:latest | sudo k3s ctr images import -
sudo k3s kubectl rollout restart deployment/laravel-app -n pi-k3s
```

## 常見問題

### Pod 無法啟動

```bash
# 檢查 Pod 事件
sudo k3s kubectl describe pod -n pi-k3s -l app=laravel

# 檢查日誌
sudo k3s kubectl logs -n pi-k3s -l app=laravel

# 常見原因：
# - imagePullPolicy 未設為 Never（本地映像）
# - secrets.yaml 中 APP_KEY 格式錯誤
# - Secret / ConfigMap 缺少資料庫或 Redis 設定
# - MariaDB / Redis 尚未就緒
```

### HPA 不觸發擴展

```bash
# 確認 metrics-server 運行
sudo k3s kubectl get pods -n kube-system | grep metrics

# 確認 HPA 有取得 CPU 指標
sudo k3s kubectl get hpa -n pi-k3s
# 若 TARGETS 顯示 <unknown>，表示 metrics-server 未正常運行

# 重新安裝 K3s 時確保未停用 metrics-server
# 不要加 --disable=metrics-server
```

### 記憶體不足 (OOMKilled)

```bash
# 檢查 Pod 記憶體使用
sudo k3s kubectl top pod -n pi-k3s

# 調整 deployment.yaml 中的 resources.limits.memory
# 建議 1C1G 環境：256Mi-384Mi per pod

# 建立 swap 以緩衝記憶體壓力
sudo fallocate -l 1G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
sudo sysctl vm.swappiness=10
```

### x509 TLS 憑證錯誤

K3s API server 憑證未包含 VPS 公網 IP：

```bash
# 重新安裝 K3s，加入 --tls-san
sudo /usr/local/bin/k3s-uninstall.sh
curl -sfL https://get.k3s.io | sh -s - \
  --disable traefik \
  --disable servicelb \
  --tls-san <YOUR_VPS_IP>
```

## 資源監控

### 即席指令

```bash
# Pod 資源使用
sudo k3s kubectl top pod -n pi-k3s

# Node 資源使用
sudo k3s kubectl top node

# 全部資源概覽
sudo k3s kubectl get all -n pi-k3s
```

### 監控腳本

[scripts/monitor-resources.sh](../scripts/monitor-resources.sh) 提供整合式檢查（節點、Pod、HPA、metrics-server 狀態）：

```bash
# 在本機執行（需先設好 ~/.kube/config-pi-k3s）
./scripts/monitor-resources.sh
```

腳本會輸出：節點 CPU/記憶體用量、Pod 列表與資源、HPA 當前狀態、metrics-server 健康度。

### 應用程式內建狀態

部署後訪問 `https://<your-domain>/calculate`，頁面右下角的 **Kubernetes 狀態** 卡片會即時顯示：

- Pod 數量與每個 Pod 的 phase（Running / Pending / Failed）
- HPA current/min/max 副本數，以進度條呈現
- 每個 Pod 的 CPU / 記憶體 metrics（需 metrics-server）

頁面每 5 秒自動 polling，無需手動刷新。

## 1C1G 環境調校建議

> 此區塊整理 1 vCPU / 1 GB RAM 環境下的常見壓力點與建議。

### 記憶體壓力

當 `kubectl top node` 顯示 **記憶體 > 80%** 持續一段時間：

```bash
# 1. 把 HPA max 暫時調為 1（停止擴展）
sudo k3s kubectl patch hpa laravel-worker -n pi-k3s \
  --type='json' -p='[{"op":"replace","path":"/spec/maxReplicas","value":1}]'

# 2. 確認 PHP-FPM workers（預設已是 2，不建議再降；降到 1 會卡 SSE）
# 編輯 docker/php-fpm-pool.conf 重 build

# 3. 確認 swap 已建立（部署腳本會自動建 1G swap）
swapon --show
```

### CPU 持續滿載

K3s 的 metrics-server 本身會吃 50-80m CPU。1 vCPU 環境下：

- 建議 HPA `targetCPUUtilizationPercentage` 設 60%（已預設）— 太高會反應太慢
- 若連 metrics-server 都拖累，可考慮關閉 HPA 改為固定 1 副本：
  ```bash
  sudo k3s kubectl delete hpa laravel-worker -n pi-k3s
  sudo k3s kubectl scale deployment/laravel-app --replicas=1 -n pi-k3s
  ```

### 多 Pod 分散式計算

正式環境請使用：

- `laravel-app`：固定 1 replica，保留 hostPort 對外
- `laravel-worker`：可擴縮
- MariaDB：共享 `calculations`、`calculation_chunks`、`jobs` 等資料
- Redis：共享 queue / cache / session / lock

不要在正式環境用 SQLite 來承接多個 worker pod。

### SSE 連線中斷

`/api/calculate/{id}/stream` 是長連線：

- nginx `proxy_buffering off` 已預設關閉 SSE 緩衝
- 若 1C1G 在重負載下逾時，可在 [docker/default.conf](../docker/default.conf) 將 `proxy_read_timeout` 調至 300s 以上
- 前端會自動重連，但同一計算的進度會從頭重播

## 部署檢核清單

部署完成後，逐項確認：

- [ ] `kubectl get pods -n pi-k3s` — web / worker / mariadb 都是 `Running`
- [ ] `kubectl get hpa -n pi-k3s` — `TARGETS` 顯示具體 CPU%（不是 `<unknown>`）
- [ ] `kubectl get svc -n pi-k3s` — Service 端點正確
- [ ] `curl -k https://<host>/up` — 回 `200`
- [ ] `curl -k -X POST https://<host>/api/calculate -d '{"total_points":100000,"mode":"single"}' -H 'Content-Type: application/json'` — 回 `201` 並含 `result_pi`
- [ ] 瀏覽器訪問 `https://<host>/calculate`，跑一次完整計算（single + distributed），AI Chat（如果 OPENAI_API_KEY 已設）能正常對話
- [ ] `kubectl top pod -n pi-k3s` — web / worker / mariadb 資源都在預期內
- [ ] `swapon --show` — Swap 1GB 已啟用
- [ ] HTTPS 憑證（如有）：`curl -I https://<host>/` 顯示有效憑證
- [ ] HPA 壓力測試：連續發 distributed 計算，確認 worker 副本數能從 1 擴到 2

## 清除部署

```bash
# 刪除所有 K8s 資源
sudo k3s kubectl delete namespace pi-k3s

# 或逐一刪除
sudo k3s kubectl delete -f k8s/hpa.yaml
sudo k3s kubectl delete -f k8s/ingress.yaml
sudo k3s kubectl delete -f k8s/service.yaml
sudo k3s kubectl delete -f k8s/deployment.yaml
sudo k3s kubectl delete -f k8s/secrets.yaml
sudo k3s kubectl delete -f k8s/configmap.yaml
sudo k3s kubectl delete -f k8s/namespace.yaml
```
