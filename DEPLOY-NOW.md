# 正式環境部署指南

正式環境部署在 VPS 主機上直接執行，不從本機傳輸。請 SSH 登入主機後依下列步驟操作。

## 前置需求（VPS）

- K3s 已安裝且運行中
- Docker 已安裝（用於建置映像）

## 部署步驟

### Step 1: SSH 登入 VPS

```bash
ssh ubuntu@165.154.227.179
```

### Step 2: 安裝 Docker（若尚未安裝）

```bash
sudo apt update && sudo apt install -y docker.io
sudo usermod -aG docker $USER
```

登出後重新 SSH 登入，使 docker 群組生效。

### Step 3: Clone 專案

```bash
git clone https://github.com/chang180/pi-k3s.git
cd pi-k3s
```

### Step 4: 設定環境檔（首次部署）

```bash
# 從範本複製並填入正式環境設定
cp k8s/secrets.yaml.example k8s/secrets.yaml
cp k8s/configmap.yaml.example k8s/configmap.yaml
cp k8s/deployment.yaml.example k8s/deployment.yaml

# 編輯 secrets.yaml：填入 APP_KEY
# php artisan key:generate --show 取得 key
# echo -n 'base64:YOUR_KEY' | base64 取得 base64 編碼後填入
nano k8s/secrets.yaml

# 視需要編輯 configmap.yaml（APP_URL、域名等）
# 視需要編輯 deployment.yaml（HTTPS、hostPort 等）
nano k8s/configmap.yaml
nano k8s/deployment.yaml
```

### Step 5: 執行部署

```bash
chmod +x scripts/deploy-on-vps.sh
./scripts/deploy-on-vps.sh
```

### Step 6: 驗證

```bash
# 查看 pod 狀態
sudo k3s kubectl get pods -n pi-k3s

# 查看 HPA 狀態（需 metrics-server 啟用）
sudo k3s kubectl get hpa -n pi-k3s

# 查看日誌
sudo k3s kubectl logs -n pi-k3s -l app=laravel -f

# 測試 API
curl http://165.154.227.179
curl -X POST http://165.154.227.179/api/calculate -H 'Content-Type: application/json' -d '{"total_points":100000}'
```

## HPA 與 metrics-server

HPA 需 metrics-server 提供 CPU 指標。若 K3s 以 `--disable=metrics-server` 安裝，HPA 無法運作。

**檢查**：`sudo k3s kubectl get pods -n kube-system | grep metrics`

**若無 metrics-server**：重新安裝 K3s，勿加 `--disable=metrics-server`（deploy-vps.sh 已修正；手動安裝則用預設或 `curl -sfL https://get.k3s.io | sh -s - --tls-san 165.154.227.179`）。

## 使用 Cursor / VS Code Remote SSH

1. 安裝 Remote - SSH 延伸
2. `Cmd/Ctrl + Shift + P` → "Remote-SSH: Connect to Host"
3. 輸入 `ubuntu@165.154.227.179`
4. 連線後開啟專案目錄，可在遠端編輯、建置、部署、除錯

## 更新部署（已有 clone）

```bash
cd ~/pi-k3s  # 或你的專案路徑
git pull origin master
./scripts/deploy-on-vps.sh
```

## TLS 憑證錯誤處理

**錯誤**：`x509: certificate is valid for 10.41.98.152, ..., not 165.154.227.179`

**處理**（在 VPS 上）：

```bash
sudo /usr/local/bin/k3s-uninstall.sh
curl -sfL https://get.k3s.io | sh -s - --tls-san 165.154.227.179
sleep 15
sudo systemctl status k3s
```

完成後重新執行 Step 5 部署。

## 除錯指令

```bash
# Pod 日誌
sudo k3s kubectl logs -n pi-k3s -l app=laravel -f

# Pod 詳情
sudo k3s kubectl describe pod -n pi-k3s -l app=laravel

# 重啟 Deployment
sudo k3s kubectl rollout restart deployment/laravel-app -n pi-k3s
```

## 完整文件

- [docs/VPS-DEPLOYMENT.md](docs/VPS-DEPLOYMENT.md) — 詳細部署說明
- [docs/PHASE-3-SUMMARY.md](docs/PHASE-3-SUMMARY.md) — Phase 3 總結
