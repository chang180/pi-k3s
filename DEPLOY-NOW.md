# 立即部署指南

## 部署方式選擇

| 方式 | 適用情境 |
|------|----------|
| **本機部署** (Step 1–4) | 從本機建置、傳送到 VPS |
| **VPS 直接部署** | 登入 VPS，clone 後在該機建置與除錯（推薦除錯用） |

---

## 方式 A：VPS 直接部署（推薦除錯）

1. SSH 登入 VPS：`ssh ubuntu@165.154.227.179`
2. 安裝 Docker（若尚未安裝）：`sudo apt install -y docker.io && sudo usermod -aG docker $USER`，重新登入
3. Clone 專案：`git clone <你的 repo> && cd pi-k3s`
4. 從本機複製 secrets（首次）：`scp k8s/secrets.yaml ubuntu@165.154.227.179:~/pi-k3s/k8s/`
5. 執行：`chmod +x scripts/deploy-on-vps.sh && ./scripts/deploy-on-vps.sh`

使用 Cursor Remote SSH 時，可在遠端開啟專案並直接執行上述步驟，方便即時除錯。

---

## 方式 B：本機快速部署

請在您的終端依序執行以下命令：

### Step 1: 設置 SSH 密鑰（一次性設置）

```bash
# 複製 SSH 公鑰到 VPS（會提示輸入密碼：Satan630519!@）
ssh-copy-id ubuntu@165.154.227.179
```

如果上述命令不可用，使用以下命令：

```bash
cat ~/.ssh/id_rsa.pub | ssh ubuntu@165.154.227.179 "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys"
```

測試 SSH 連接（應該不需要密碼）：

```bash
ssh ubuntu@165.154.227.179 "echo 'SSH 連接成功'"
```

### Step 2: 執行自動化部署

```bash
cd /home/chang180/projects/pi-k3s
./scripts/deploy-vps.sh
```

**預計時間**：5-10 分鐘（取決於網路速度）

### Step 3: 驗證部署

部署完成後，執行以下命令驗證：

```bash
# 設置 kubeconfig
export KUBECONFIG=~/.kube/config-pi-k3s

# 查看 pod 狀態
kubectl get pods -n pi-k3s

# 查看服務
kubectl get svc -n pi-k3s

# 查看 ingress
kubectl get ingress -n pi-k3s
```

### Step 4: 測試應用程式

```bash
# 測試首頁
curl http://165.154.227.179

# 測試 API
curl -X POST http://165.154.227.179/api/calculate \
  -H 'Content-Type: application/json' \
  -d '{"total_points":100000}'
```

## 若在 Step 7 出現 TLS 憑證錯誤

**錯誤訊息**：`x509: certificate is valid for 10.41.98.152, ..., not 165.154.227.179`

**原因**：K3s 憑證未包含對外 IP，需以 `--tls-san` 重新安裝。

**處理步驟**：

```bash
# 1. SSH 到 VPS
ssh ubuntu@165.154.227.179

# 2. 卸載 K3s（會清除叢集，需重新部署）
sudo /usr/local/bin/k3s-uninstall.sh

# 3. 以 --tls-san 重新安裝（加入對外 IP 到憑證）
curl -sfL https://get.k3s.io | sh -s - --tls-san 165.154.227.179

# 4. 等待約 15 秒
sleep 15

# 5. 確認 K3s 啟動
sudo systemctl status k3s

# 6. 離開 VPS
exit
```

接著在本機執行「從 Step 7 繼續」：

```bash
cd /home/chang180/projects/pi-k3s
export KUBECONFIG=~/.kube/config-pi-k3s

# 重新取得 kubeconfig（公網 IP 已寫入憑證）
ssh ubuntu@165.154.227.179 "sudo cat /etc/rancher/k3s/k3s.yaml" | sed "s/127.0.0.1/165.154.227.179/g" > ~/.kube/config-pi-k3s

# 測試連線
kubectl get nodes

# 若成功，繼續 Step 8 部署
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/secrets.yaml
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
kubectl apply -f k8s/ingress.yaml
```

**注意**：重新安裝 K3s 會清空叢集與已載入的 image。建議完成上述 1～6 後，**直接重跑完整部署腳本**：

```bash
cd /home/chang180/projects/pi-k3s
./scripts/deploy-vps.sh
```

腳本會從頭執行（建置、傳輸、載入 image、設定 kubectl、部署），且 K3s 已帶正確憑證，Step 7、8 會正常完成。

---

## 如果遇到問題

### 問題 1: SSH 密鑰複製失敗

**原因**：SSH 密鑰可能不存在

**解決**：
```bash
# 生成 SSH 密鑰（如果還沒有）
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ""

# 然後重試 Step 1
```

### 問題 2: 部署腳本執行失敗

**解決**：
```bash
# 使用手動部署指南
cat docs/VPS-DEPLOYMENT.md

# 或查看詳細錯誤日誌
./scripts/deploy-vps.sh 2>&1 | tee deploy.log
```

### 問題 3: Pod 無法啟動

**檢查**：
```bash
# 查看 pod 詳細資訊
kubectl describe pod -n pi-k3s <pod-name>

# 查看 pod 日誌
kubectl logs -n pi-k3s <pod-name>
```

**常見原因**：
- 鏡像載入失敗：確認 `imagePullPolicy: Never` 已設置
- 資源不足：檢查 VPS 記憶體使用狀況
- 配置錯誤：檢查 ConfigMap 和 Secret

## 監控資源使用

```bash
# 執行監控腳本
./scripts/monitor-resources.sh

# 持續監控（每 10 秒更新）
./scripts/monitor-resources.sh --watch

# 導出監控報告
./scripts/monitor-resources.sh --export
```

## 下一步

部署成功後：

1. ✅ 監控資源使用 24-48 小時
2. ✅ 記錄基準性能指標
3. ✅ 準備開始 Phase 4 開發

## 需要幫助？

查看完整文檔：
- 部署指南：`docs/VPS-DEPLOYMENT.md`
- Phase 3 總結：`docs/PHASE-3-SUMMARY.md`
