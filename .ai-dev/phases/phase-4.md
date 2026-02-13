# Phase 4：HPA 與分散式計算

## 階段目標與產出

- **一句話目標**：啟用 Metrics Server、HPA（min=1、max=3）、分散式計算協調器、K8s API 整合（Pod 狀態、HPA）、Laravel Queue（Redis）與 Worker，並以壓力測試驗證自動擴展。
- **可驗證產出**：
  - HPA 會隨 CPU 負載擴縮（1 → 2 → 3 replicas）。
  - `mode=distributed` 時，計算由多 Worker 執行並正確彙總結果（π 與單機一致）。
  - `GET /api/k8s/status`、`GET /api/k8s/metrics` 回傳 Pod 數、HPA 狀態、CPU/Memory 等。

---

## 前置條件

- **環境**：Phase 3 已完成，K8s 叢集（1C1G VPS）可用；Laravel 可連 MySQL 與 Redis。
- **必須已完成的階段**：Phase 1、2、3。
- **需存在的檔案或設定**：Phase 3 的資源觀察數據；`QUEUE_CONNECTION=redis` 與 Redis 可連；K8s 內可執行 kubectl 或 PHP Kubernetes Client（in-cluster 或 kubeconfig）。

---

## 參考

- [plan.md](../plan.md)：核心功能模組（蒙地卡羅計算引擎、Kubernetes 整合）、API 設計（GET /api/k8s/status、GET /api/k8s/metrics）、Kubernetes 架構設計（HPA、ConfigMap、Secrets）、技術重點（可行性要點、K8s 整合關鍵、VPS 資源限制、效能優化）。

---

## 細部工作清單

### Kubernetes

1. **新增** [k8s/hpa.yaml](k8s/hpa.yaml)
   - 參考 HorizontalPodAutoscaler：targetRef 指向 Laravel deployment、minReplicas=1、maxReplicas=3、metrics 類型為 resource（CPU 目標利用率，例如 60%）。
   - 註明：K3s 內建 Metrics Server，無需額外安裝。

2. **新增** RBAC（ServiceAccount、Role、RoleBinding）
   - 新增 [k8s/serviceaccount.yaml](k8s/serviceaccount.yaml)（或合併於 deployment 內）：建立專用 ServiceAccount。
   - 新增 [k8s/role.yaml](k8s/role.yaml)：Rule 允許 get、list pods、horizontalpodautoscalers、可選 metrics（依叢集 API 而定）。
   - 新增 [k8s/rolebinding.yaml](k8s/rolebinding.yaml)：將 Role 綁定至 ServiceAccount。
   - 修改 [k8s/deployment.yaml](k8s/deployment.yaml)：指定 `serviceAccountName` 為上述 ServiceAccount。

### 後端：分散式計算

3. **新增** [app/Jobs/CalculatePiJob.php](app/Jobs/CalculatePiJob.php)
   - 實作 `ShouldQueue`（使用 Redis connection）。
   - 建構參數：calculation_id、子任務參數（例如 chunk 的 start_index、end_index 或 points 數）。
   - 在 handle 中執行該 chunk 的蒙地卡羅計算（可呼叫 `MonteCarloService` 或內聯邏輯），將結果寫入 Redis（例如 key 含 calculation_id）或 DB（子任務結果表）；完成時更新彙總進度，若為最後一個 chunk 則彙總到 `Calculation`（result_pi = 4 * sum(inside)/sum(total)，status=completed）。

4. **新增或擴充** [app/Services/DistributedCalculator.php](app/Services/DistributedCalculator.php)
   - 輸入：Calculation 或 total_points、calculation_id。
   - 將總點數切為 N 份（N 可依當前 Pod 數或固定值，例如 3～10），每份 dispatch 一個 `CalculatePiJob` 到 queue。
   - 輪詢或監聽 Redis/DB 中各 chunk 完成狀態；全部完成後彙總 π = 4 * sum(inside)/sum(total)，更新 `Calculation`（result_pi、result_inside、result_total、duration_ms、status=completed）。

5. **修改** [app/Http/Controllers/Api/CalculateController.php](app/Http/Controllers/Api/CalculateController.php)
   - `store`：當 `mode=distributed` 時改呼叫 `DistributedCalculator`（非同步觸發），立即回傳 202 或 200 與 calculation id；當 `mode=single` 時維持 Phase 1 行為（同步 `MonteCarloService`）。

### 後端：K8s API

6. **新增** [app/Services/K8sClientService.php](app/Services/K8sClientService.php)
   - 透過 Kubernetes PHP Client（例如 `renoki-co/php-k8s` 或官方 client）或 `exec('kubectl get pods ...')` 取得當前 namespace 的 Pod 列表、HPA 狀態。
   - 需在 K8s 內可用的 kubeconfig（in-cluster 使用 serviceAccount token）或環境變數指定 kubeconfig 路徑；若以 exec kubectl，需確保 Pod 內有 kubectl 且具權限。
   - 方法建議：`getPods(): array`、`getHpaStatus(): array`；可選 `getMetrics(): array`（若叢集有 metrics.k8s.io）。

7. **新增** API 與 Controller
   - 新增 [app/Http/Controllers/Api/K8sStatusController.php](app/Http/Controllers/Api/K8sStatusController.php)（或合併於既有 Controller）：`status()` 回傳 Pod 數、HPA 當前/目標 replica、可選 Pod 名稱列表；`metrics()` 回傳 CPU、Memory 使用（若 K8sClientService 或 Metrics Server API 可取得）。
   - 註冊路由：`GET /api/k8s/status`、`GET /api/k8s/metrics`。

### Queue 與 Worker

8. **設定** Queue
   - 確保 `.env` 與 K8s ConfigMap/Secret 中 `QUEUE_CONNECTION=redis`；Redis 連線正常。
   - Worker 運行方式：與 Laravel deployment 同 image，以 `php artisan queue:work` 為 entrypoint 的 sidecar 或獨立 deployment；或同一 deployment 多 replica 同時跑 web + queue worker（依專案取捨）。需確保多個 Worker 可消費同一 queue。

### 測試

9. **新增** Feature Test
   - 分散式任務：POST /api/calculate 傳 `mode=distributed`、合法 total_points，回傳 200/202 且含 id；輪詢 GET /api/calculate/{id} 直至 status=completed，驗證 result_pi 合理。
   - 可選：mock K8sClientService 或 exec，測試 K8sStatusController 回傳結構。

### 驗證

10. **壓力測試與擴展驗證**
    - 觸發高負載計算（例如 1000 萬點、distributed）；觀察 `kubectl get hpa -n pi-k3s`、`kubectl get pods -n pi-k3s` 是否擴展至 2～3 replicas。
    - 確認分散式計算結果與單機結果在誤差範圍內一致。

---

## 驗收條件

1. HPA 會隨 CPU 負載擴縮（min 1、max 3）。
2. 分散式計算（mode=distributed）結果正確，與單機結果一致。
3. `GET /api/k8s/status`、`GET /api/k8s/metrics` 回傳正確（Pod 數、HPA、可選 CPU/Memory）。

---

## 交接給下一階段

Phase 5 執行前需具備：

- `GET /api/k8s/status`、`GET /api/k8s/metrics` 可用。
- 計算進度可被輪詢（GET /api/calculate/{id}）或後續以 SSE 推送；若 Phase 4 已實作進度寫入 Redis/DB，Phase 5 可依此實作 SSE。
