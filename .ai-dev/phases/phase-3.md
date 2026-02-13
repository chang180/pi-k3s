# Phase 3：正式環境部署（1C1G VPS）

## 階段目標與產出

- **一句話目標**：在 1C1G、具對外 IP 的 VPS 上安裝 K3s、部署應用，並可從外網訪問；觀察單一 Pod 的資源使用作為後續 HPA 參數依據。
- **可驗證產出**：
  - VPS 已安裝 K3s，`kubectl get nodes` 正常。
  - 應用已部署至 namespace（如 `pi-k3s`），可從外網透過 Ingress 或 IP:port 訪問首頁與 `/api/calculate`。
  - 單一 Pod 的 CPU/Memory 使用有記錄（例如 `kubectl top pod`），供 Phase 4 設定 HPA 參考。

---

## 前置條件

- **環境**：1C1G VPS（Ubuntu）、具對外 IP；本機可 SSH 至 VPS 或從本機以 `KUBECONFIG` 遠端操作。
- **必須已完成的階段**：Phase 2。
- **需存在的檔案或設定**：Phase 2 產出的 Docker image（可推送至 Docker Hub 或私有 registry）、完整 `k8s/` 清單（至少 namespace、deployment、service、ingress）。

---

## 參考

- [plan.md](../plan.md)：正式部署環境（1C1G VPS、K3s、Traefik）、開發工作流（正式部署）、技術重點（K3s 特性、VPS 資源限制）、檢查清單（正式部署環境）。

---

## 細部工作清單

### VPS 前置

1. **文件化或執行** VPS 前置步驟（可寫入本 phase-3.md 或 [docs/deployment-guide.md](docs/deployment-guide.md) 初稿）
   - SSH 連線至 VPS（例如 `ssh root@<VPS_IP>`）。
   - Ubuntu 更新：`apt update && apt upgrade -y`（可選）。
   - 安裝 K3s：`curl -sfL https://get.k3s.io | sh -`。
   - 驗證：`kubectl get nodes`（若以 root 執行安裝，kubeconfig 通常在 `/etc/rancher/k3s/k3s.yaml`；本機遠端操作時將此檔複製到本機並設定 `KUBECONFIG`）。

### 部署步驟

2. **Image 推送**
   - 將 Phase 2 建好的 image 打 tag 並推送到 Docker Hub（或私有 registry）：例如 `docker tag pi-k3s:test your-dockerhub/pi-k3s:v1.0`、`docker push your-dockerhub/pi-k3s:v1.0`。
   - 若 VPS 無法拉取私有 registry，需在 K8s 中設定 imagePullSecrets 或使用公開 image。

3. **K8s 部署**
   - 在 VPS 上（或從本機 `KUBECONFIG` 指向 VPS）執行：`kubectl apply -f k8s/`（依序或一次套用 namespace、configmap、secrets、deployment、service、ingress 等）。
   - 確認 Pod 為 Running：`kubectl get pods -n pi-k3s`；若有 Init 或 Migration Job，需一併套用並確認完成。
   - 確認 Ingress：`kubectl get ingress -n pi-k3s`；Traefik 會分配對外 IP 或 Host，或需設定 DNS 指向 VPS IP。

4. **MySQL / Redis（若 Phase 2 未含）**
   - 此階段補上 [k8s/mysql-statefulset.yaml](k8s/mysql-statefulset.yaml)、[k8s/redis-deployment.yaml](k8s/redis-deployment.yaml) 及對應 Service；Laravel 的 `.env` 中 DB_*、REDIS_* 需與 K8s 內 service 名稱一致。
   - 透過 [k8s/configmap.yaml](k8s/configmap.yaml) 與 [k8s/secrets.yaml](k8s/secrets.yaml) 注入環境變數；或文件註明「正式需改為 MySQL+Redis」，先以 SQLite/本地 Redis 讓單 Pod 可跑（僅供驗證，不建議長期）。

### 驗證與資源觀察

5. **外網驗證**
   - 從外網以瀏覽器或 `curl` 打 `http(s)://<VPS_IP_or_domain>/` 與 `http(s)://<VPS_IP_or_domain>/api/calculate`（必要時含 POST 測試）。
   - 確認回應正常、無 502/503。

6. **資源觀察**
   - 執行 `kubectl top pod -n pi-k3s`（需 Metrics Server，K3s 內建）；若尚未有負載，可觸發一次小規模計算（例如 10 萬點）後再觀察。
   - 將單一 Pod 的 CPU/Memory 使用記錄寫入本 phase-3.md 或 [plan.md](../plan.md) 或 [docs/deployment-guide.md](docs/deployment-guide.md)，供 Phase 4 設定 HPA 閾值與 limits 參考。

---

## 驗收條件

1. 外網可開啟首頁與 API（GET/POST /api/calculate）。
2. `kubectl get pods -n pi-k3s` 顯示 Pod 為 Running。
3. 資源觀察有記錄（CPU/Memory），可供 Phase 4 使用。

---

## 交接給下一階段

Phase 4 執行前需具備：

- 可用的 K8s 叢集（1C1G VPS 上的 K3s）。
- Laravel 可連線 MySQL 與 Redis（若已部署）；或文件註明將在 Phase 4 補上。
- 實測的單 Pod 資源數據（CPU/Memory），供 HPA 與 resource limits 設定。
