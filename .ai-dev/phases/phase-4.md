# Phase 4：HPA 與分散式計算

## 階段目標與產出

- **一句話目標**：啟用 Metrics Server、HPA（min=1、max=2，1C1G 可調 3）、分散式計算協調器、K8s API 整合（Pod 狀態、HPA）、Laravel Queue（database driver）與 Worker。1C1G 環境無 MySQL/Redis，使用 SQLite + database queue。
- **可驗證產出**：
  - HPA 會隨 CPU 負載擴縮（1 → 2 replicas）。
  - `mode=distributed` 時，計算由 Worker 執行並正確彙總結果（π 與單機一致）。
  - `GET /api/k8s/status`、`GET /api/k8s/metrics` 回傳 Pod 數、HPA 狀態、CPU/Memory 等。

---

## 前置條件

- **環境**：Phase 3 已完成，K8s 叢集（1C1G VPS）可用；K3s 需啟用 metrics-server（勿以 --disable=metrics-server 安裝）。
- **必須已完成的階段**：Phase 1、2、3。
- **需存在的檔案或設定**：`QUEUE_CONNECTION=database` 與 jobs 表已遷移；k8s/hpa.yaml 已套用；K8s 內可執行 kubectl 或 PHP Kubernetes Client。

---

## 參考

- [plan.md](../plan.md)：核心功能模組、API 設計、Kubernetes 架構設計、技術重點。

---

## 細部工作清單

### Kubernetes

1. **確認** [k8s/hpa.yaml](k8s/hpa.yaml) 已套用
   - targetRef 指向 Laravel deployment、minReplicas=1、maxReplicas=2、metrics 類型為 resource（CPU 目標 60%）。
   - 註：K3s 預設內建 metrics-server；若以 deploy-vps.sh 安裝，已移除 --disable=metrics-server。
   - 1C1G 可依實測將 maxReplicas 調為 3。

2. **新增** RBAC（ServiceAccount、Role、RoleBinding）
   - 新增 [k8s/serviceaccount.yaml](k8s/serviceaccount.yaml)：建立專用 ServiceAccount。
   - 新增 [k8s/role.yaml](k8s/role.yaml)：Rule 允許 get、list pods、horizontalpodautoscalers、可選 metrics。
   - 新增 [k8s/rolebinding.yaml](k8s/rolebinding.yaml)：將 Role 綁定至 ServiceAccount。
   - 修改 [k8s/deployment.yaml](k8s/deployment.yaml)：指定 `serviceAccountName`。

### 後端：分散式計算

3. **新增** [app/Jobs/CalculatePiJob.php](app/Jobs/CalculatePiJob.php)
   - 實作 `ShouldQueue`（使用 database queue connection）。
   - 建構參數：calculation_id、子任務參數。
   - 在 handle 中執行該 chunk 的蒙地卡羅計算，將結果寫入 DB；完成時更新彙總進度，若為最後一個 chunk 則彙總到 `Calculation`。

4. **新增或擴充** [app/Services/DistributedCalculator.php](app/Services/DistributedCalculator.php)
   - 將總點數切為 N 份，每份 dispatch 一個 `CalculatePiJob` 到 database queue。
   - 輪詢 DB 中各 chunk 完成狀態；全部完成後彙總 π 並更新 `Calculation`。

5. **修改** [app/Http/Controllers/Api/CalculateController.php](app/Http/Controllers/Api/CalculateController.php)
   - `store`：當 `mode=distributed` 時改呼叫 `DistributedCalculator`，立即回傳 202 或 200 與 calculation id；當 `mode=single` 時維持 Phase 1 行為。

### 後端：K8s API

6. **新增** [app/Services/K8sClientService.php](app/Services/K8sClientService.php)
   - 取得 Pod 列表、HPA 狀態；可選取得 CPU/Memory 使用（Metrics Server API）。
   - 方法建議：`getPods(): array`、`getHpaStatus(): array`；可選 `getMetrics(): array`。

7. **新增** API 與 Controller
   - 新增 [app/Http/Controllers/Api/K8sStatusController.php](app/Http/Controllers/Api/K8sStatusController.php)：`status()` 回傳 Pod 數、HPA 當前/目標 replica；`metrics()` 回傳 CPU、Memory 使用。
   - 註冊路由：`GET /api/k8s/status`、`GET /api/k8s/metrics`。

### Queue 與 Worker

8. **設定** Queue
   - 確保 `QUEUE_CONNECTION=database`；已執行 `php artisan queue:table` 與 migrate。
   - Worker 運行方式：以 `php artisan queue:work` 為 entrypoint 的 sidecar 或同一 deployment 多 replica 同時跑 web + queue worker。

### 測試與驗證

9. **新增** Feature Test
   - 分散式任務：POST /api/calculate 傳 `mode=distributed`，回傳 200/202 且含 id；輪詢 GET /api/calculate/{id} 直至 status=completed，驗證 result_pi 合理。
   - 可選：mock K8sClientService，測試 K8sStatusController 回傳結構。

10. **壓力測試與擴展驗證**
    - 觸發高負載計算（例如 1000 萬點）；觀察 `kubectl get hpa -n pi-k3s`、`kubectl get pods -n pi-k3s` 是否擴展至 2 replicas。

---

## 驗收條件

1. HPA 會隨 CPU 負載擴縮（min 1、max 2，可調 3）。
2. 分散式計算（mode=distributed）結果正確，與單機結果一致。
3. `GET /api/k8s/status`、`GET /api/k8s/metrics` 回傳正確（Pod 數、HPA、可選 CPU/Memory）。

---

## 交接給下一階段

Phase 5 執行前需具備：

- `GET /api/k8s/status`、`GET /api/k8s/metrics` 可用。
- 計算進度可被輪詢（GET /api/calculate/{id}）；Phase 5 可依此實作 SSE。
