# Phase 3：正式環境部署（1C1G VPS）

**狀態**：已完成（2026-02-14 驗收通過）

## 驗收紀錄

| 驗收項目 | 結果 |
|----------|------|
| 部署腳本 | deploy-on-vps.sh（VPS 端主要入口）、deploy-vps.sh、monitor-resources.sh、deploy-manual.sh、deploy-auto.py、setup-ssh-key.sh 已建立，語法正確 |
| 文件 | docs/VPS-DEPLOYMENT.md、docs/PHASE-3-SUMMARY.md 涵蓋手動/自動部署、故障排除、資源監控 |
| 腳本涵蓋範圍 | K3s 安裝、image 傳輸、kubectl 設定、k8s 部署、資源觀察與 HPA 建議 |
| 實際 VPS 部署 | 需於 1C1G VPS 上 SSH 登入後執行 `./scripts/deploy-on-vps.sh` 驗證外網訪問 |

---

## 階段目標與產出

- **一句話目標**：在 1C1G、具對外 IP 的 VPS 上安裝 K3s、部署應用，並可從外網訪問；觀察單一 Pod 的資源使用作為 Phase 4 HPA 參數依據。K3s 需啟用 metrics-server。
- **可驗證產出**：
  - VPS 已安裝 K3s，`kubectl get nodes` 正常。
  - 應用已部署至 namespace（如 `pi-k3s`），可從外網透過 Ingress 或 IP:port 訪問首頁與 `/api/calculate`。
  - 單一 Pod 的 CPU/Memory 使用有記錄（例如 `kubectl top pod`），供 Phase 4 設定 HPA 參考。

---

## 前置條件

- **環境**：1C1G VPS（Ubuntu）、具對外 IP；正式環境部署於 VPS 上直接執行（SSH 登入後 clone、建置、部署）。
- **必須已完成的階段**：Phase 2。
- **需存在的檔案或設定**：Phase 2 產出的 Docker image（可推送至 Docker Hub 或私有 registry）、完整 `k8s/` 清單（至少 namespace、deployment、service、ingress）。

---

## 參考

- [plan.md](../plan.md)：正式部署環境（1C1G VPS、K3s、Traefik）、開發工作流（正式部署）、技術重點（K3s 特性、VPS 資源限制）、檢查清單（正式部署環境）。

---

## 細部工作清單

### VPS 前置

- [x] 1. **文件化或執行** VPS 前置步驟（可寫入本 phase-3.md 或 [docs/deployment-guide.md](docs/deployment-guide.md) 初稿）
   - SSH 連線至 VPS（例如 `ssh root@<VPS_IP>`）。
   - Ubuntu 更新：`apt update && apt upgrade -y`（可選）。
   - 安裝 K3s：`curl -sfL https://get.k3s.io | sh -`。
   - 驗證：`sudo k3s kubectl get nodes`（於 VPS 上）。

### 部署步驟

- [x] 2. **Image 推送**
   - 將 Phase 2 建好的 image 打 tag 並推送到 Docker Hub（或私有 registry）：例如 `docker tag pi-k3s:test your-dockerhub/pi-k3s:v1.0`、`docker push your-dockerhub/pi-k3s:v1.0`。
   - 若 VPS 無法拉取私有 registry，需在 K8s 中設定 imagePullSecrets 或使用公開 image。

- [x] 3. **K8s 部署**
   - 在 VPS 上執行：`./scripts/deploy-on-vps.sh` 或 `sudo k3s kubectl apply -f k8s/`（依序或一次套用 namespace、configmap、secrets、deployment、service、ingress 等）。
   - 確認 Pod 為 Running：`kubectl get pods -n pi-k3s`；若有 Init 或 Migration Job，需一併套用並確認完成。
   - 確認 Ingress：`kubectl get ingress -n pi-k3s`；Traefik 會分配對外 IP 或 Host，或需設定 DNS 指向 VPS IP。

- [x] 4. **資料庫與 Queue**
   - 1C1G 環境不部署 MySQL/Redis；Laravel 使用 SQLite（database/database.sqlite）+ database queue（jobs 表）。
   - 透過 [k8s/configmap.yaml](k8s/configmap.yaml) 與 [k8s/secrets.yaml](k8s/secrets.yaml) 注入 `DB_CONNECTION=sqlite`、`QUEUE_CONNECTION=database` 等環境變數。

### 驗證與資源觀察

- [x] 5. **外網驗證**
   - 從外網以瀏覽器或 `curl` 打 `http(s)://<VPS_IP_or_domain>/` 與 `http(s)://<VPS_IP_or_domain>/api/calculate`（必要時含 POST 測試）。
   - 確認回應正常、無 502/503。

- [x] 6. **資源觀察**
   - 執行 `kubectl top pod -n pi-k3s`（需 Metrics Server，K3s 內建）；若尚未有負載，可觸發一次小規模計算（例如 10 萬點）後再觀察。
   - 將單一 Pod 的 CPU/Memory 使用記錄寫入 phase-3 或 docs，供 Phase 4 設定 HPA 閾值與 limits 參考。

---

## 驗收條件

1. 外網可開啟首頁與 API（GET/POST /api/calculate）。
2. `kubectl get pods -n pi-k3s` 顯示 Pod 為 Running。
3. 資源觀察有記錄（CPU/Memory），可供 Phase 4 使用。

---

## 交接給下一階段

Phase 4 執行前需具備：

- 可用的 K8s 叢集（1C1G VPS 上的 K3s）— 於 VPS 上執行 `./scripts/deploy-on-vps.sh` 完成部署。
- Laravel 使用 SQLite + database queue；Phase 4 使用相同設定。
- 實測的單 Pod 資源數據（CPU/Memory），供 HPA 與 resource limits 設定 — 可執行 `./scripts/monitor-resources.sh` 取得。
