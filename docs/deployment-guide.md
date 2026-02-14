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
# APP_URL: "http://<YOUR_VPS_IP>"
vi k8s/configmap.yaml
```

### deployment.yaml

```bash
# 若需 HTTPS，取消 SSL 相關註解
vi k8s/deployment.yaml
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

# 4. 應用（Deployment、Service）
sudo k3s kubectl apply -f k8s/deployment.yaml
sudo k3s kubectl apply -f k8s/service.yaml

# 5. Ingress（若使用 Traefik）
sudo k3s kubectl apply -f k8s/ingress.yaml

# 6. HPA（自動擴展）
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
# 預期：laravel-app-xxx   1/1   Running
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
# 預期：laravel-app   Deployment/laravel-app   <cpu>%/60%   1   2
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
# - SQLite 檔案權限問題
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

```bash
# Pod 資源使用
sudo k3s kubectl top pod -n pi-k3s

# Node 資源使用
sudo k3s kubectl top node

# 全部資源概覽
sudo k3s kubectl get all -n pi-k3s
```

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
