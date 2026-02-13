# Phase 2：容器化與最小 K8s 部署

**狀態**：已完成（2026-02-14 驗收通過）

## 驗收紀錄

| 驗收項目 | 結果 |
|----------|------|
| `docker build -t pi-k3s:test .` | 成功 |
| `docker run -p 8080:80 pi-k3s:test` | 容器可啟動，health /up 通過 |
| POST /api/calculate | 回傳 201，含 result_pi、uuid、status |
| k8s 清單 | namespace、deployment、service、ingress、configmap、secrets |
| 本機域名 | pi-k3s.local（Ingress Host） |
| 測試腳本 | docker/test.sh 全數通過 |

---

## 階段目標與產出

- **一句話目標**：產出 Dockerfile、.dockerignore，以及最小 K8s 清單（namespace、deployment、service、ingress），使本機可 build/run 或於 Docker Desktop K8s 部署並從外網或 port-forward 訪問。
- **可驗證產出**：
  - `docker build -t pi-k3s:test .` 成功，`docker run -p 8080:80 pi-k3s:test` 後可訪問首頁或 `/api/calculate`。
  - 或於本機 K8s（Docker Desktop / minikube / k3d）執行 `kubectl apply -f k8s/` 後，可透過 Ingress 或 `kubectl port-forward` 打 API。
  - 可選：補齊 MySQL、Redis 的 K8s 資源（Phase 2 可只做佔位，讓 Phase 3 能先跑單一 Laravel Pod）。

---

## 前置條件

- **環境**：WSL2、Docker Desktop（含可選的 K8s 或 minikube/k3d）。
- **必須已完成的階段**：Phase 1。
- **需存在的檔案或設定**：Phase 1 產出的 `MonteCarloService`、`Calculation` model、`POST/GET /api/calculate`、可運行的前端；專案可正常 `php artisan serve` 與 `npm run dev`。

---

## 參考

- [plan.md](../plan.md)：技術棧（Docker、K3s）、Kubernetes 架構設計（部署元件、HPA 配置重點）、專案檔案結構（docker/、k8s/）、技術重點與注意事項（K3s 特性、VPS 資源限制）、開發工作流（本機容器化測試）。

---

## 細部工作清單

### Docker

- [x] 1. **新增** [Dockerfile](Dockerfile)
   - 多階段建置：第一階段 Node 建置前端（`npm ci`、`npm run build`），第二階段 PHP 運行環境（Laravel 12、php-fpm 或單一 Apache/Nginx+PHP 映像）。
   - 複製 `composer.json` / `composer.lock`、安裝依賴（`--no-dev`）、複製應用程式碼、複製第一階段產出的 `public/build`。
   - 設定 entrypoint：可選 `php artisan migrate --force`（或於 K8s job 執行）、啟動 php-fpm 或 Nginx+php-fpm。
   - 以現有 [public/](public/) 與 [vendor/](vendor/) 結構為準；若使用 Nginx，需設定 document root 為 Laravel `public`。

- [x] 2. **新增** [.dockerignore](.dockerignore)
   - 排除：`node_modules`、`.git`、`.env`、`tests`、`storage/logs`、`storage/framework/cache`、`.phpunit.result.cache`、`vendor`（將在映像內重新安裝）等，避免肥大與敏感檔進映像。

- [x] 3. **可選** [docker/nginx.conf](docker/nginx.conf)
   - 若使用 Nginx：root 指向 Laravel `public`、php-fpm upstream、`index index.php`、`try_files $uri $uri/ /index.php?$query_string`；必要時設定 `client_max_body_size` 等。

### Kubernetes

- [x] 4. **新增** [k8s/namespace.yaml](k8s/namespace.yaml)
   - 建立 namespace，例如 `pi-k3s`。

- [x] 5. **新增** [k8s/deployment.yaml](k8s/deployment.yaml)
   - 部署 Laravel 應用：單一 replica（本階段不啟用 HPA）、image 可參數化（如 `your-dockerhub/pi-k3s:latest` 或佔位）。
   - 資源：`requests` memory 128Mi、cpu 100m；`limits` memory 256Mi、cpu 500m（與 plan 中 VPS 優化一致）。
   - 環境變數：可來自 ConfigMap/Secret（此階段可先寫死或佔位，例如 `APP_KEY`、`APP_ENV`、`DB_*`、`REDIS_*` 等，Phase 3 再改為 ConfigMap/Secret）。

- [x] 6. **新增** [k8s/service.yaml](k8s/service.yaml)
   - ClusterIP、port 80、selector 對應 deployment 的 label。

- [x] 7. **新增** [k8s/ingress.yaml](k8s/ingress.yaml)
   - Traefik（K3s 內建）：Host 或 Path 規則指向上述 service；若本機無域名可先用 Path 或預設規則，VPS 上再改為 Host。

- [x] 8. **可選（Phase 2 可只做佔位或簡化）**
   - [k8s/configmap.yaml](k8s/configmap.yaml)：非敏感環境變數。
   - [k8s/secrets.yaml](k8s/secrets.yaml)：敏感資訊（注意勿提交真實密碼；可用 placeholder 或 sealed secrets）。
   - [k8s/mysql-statefulset.yaml](k8s/mysql-statefulset.yaml)、[k8s/redis-deployment.yaml](k8s/redis-deployment.yaml)：若希望 Phase 3 直接使用 DB/Redis，可在此階段加入；否則可於 Phase 3 補上，讓 Phase 2 僅驗證「單一 Laravel Pod 可跑」。

### 文件（寫入本 phase-2.md 或註解）

- [x] 9. **本機驗證指令**
   - `docker build -t pi-k3s:test .`
   - `docker run -p 8080:80 pi-k3s:test`，訪問 `http://localhost:8080`、`http://localhost:8080/api/calculate`。
   - 或：`kubectl apply -f k8s/` 後，`kubectl port-forward -n pi-k3s svc/laravel-service 8080:80` 或透過 Ingress 訪問。

---

## 驗收條件

1. **Docker**：`docker run -p 8080:80 pi-k3s:test` 後，瀏覽器或 `curl` 可打開首頁或 `GET /api/calculate`（若需 id 可先 `POST /api/calculate` 取得）。
2. **K8s（可選）**：在本機 K8s 部署後，可透過 Ingress 或 port-forward 打 API，Pod 狀態為 Running。

---

## 交接給下一階段

Phase 3 執行前需具備：

- 可成功 build 且可運行的 Docker image（可推送至 Docker Hub 或私有 registry）。
- 完整 `k8s/` 清單：至少 `namespace.yaml`、`deployment.yaml`、`service.yaml`、`ingress.yaml`。
- 若 Phase 2 未含 MySQL/Redis，Phase 3 或 Phase 4 需補上對應 StatefulSet/Deployment 與 Laravel 連線設定。
