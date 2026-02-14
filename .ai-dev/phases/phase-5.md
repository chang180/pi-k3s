# Phase 5：前端視覺化與即時通訊（SSE）

**狀態**：已完成（覆核驗收通過）

## 驗收紀錄

| 驗收項目 | 結果 |
|----------|------|
| 儀表板可完整操作（點數、模式、開始/停止/重置） | ✓ ControlPanel + Calculate.vue 整合，顯示結果與耗時 |
| 蒙地卡羅 Canvas 與圓周率收斂圖 | ✓ MonteCarloCanvas.vue（Canvas 投點）、PiChart.vue（Chart.js 收斂曲線） |
| K8s 狀態區（Pod 數、HPA、CPU/Memory） | ✓ K8sStatus.vue 輪詢 /api/k8s/status、/api/k8s/metrics |
| SSE 即時進度 | ✓ GET /api/calculate/{id}/stream、EventSource、useCalculationStream |
| 效能對比區（歷史圖表） | ✓ PerformanceComparison.vue、GET /api/history |
| 後端測試 | ✓ CalculateStreamTest、HistoryTest |

## 階段目標與產出

- **一句話目標**：完成控制面板、蒙地卡羅 Canvas、圓周率收斂圖（Chart.js）、K8s 狀態區、效能對比區，以及 SSE 即時推送計算進度與 Pod/CPU。
- **可驗證產出**：
  - 儀表板可操作：選擇點數、模式、開始/停止/重置；發起計算後可看到即時進度與結果。
  - 蒙地卡羅圓形圖與圓周率收斂曲線有正確資料；K8s 狀態區顯示 Pod 數、CPU/Memory；效能對比區可顯示歷史記錄圖表。
  - SSE 連線後可收到計算進度（progress_percent、current_pi 等）與 K8s 狀態更新。

---

## 前置條件

- **環境**：本機 WSL2（或與 Phase 1 相同）；Phase 4 部署與 API 可用。
- **必須已完成的階段**：Phase 1、2、3、4。
- **需存在的檔案或設定**：`POST/GET /api/calculate`、`GET /api/k8s/status`、`GET /api/k8s/metrics`；計算進度可被輪詢或由 Phase 4 寫入 DB（Calculation 表），供本階段實作 SSE。

---

## 參考

- [plan.md](../plan.md)：核心功能模組（前端視覺化介面、即時通訊 SSE）、API 設計、專案檔案結構（resources/js/components/）、技術重點（效能優化、前端節流）。

---

## 細部工作清單

### API

1. **新增** SSE 端點：`GET /api/calculate/{id}/stream` 或 `GET /api/calculate/{id}/events`
   - 回傳 Content-Type: text/event-stream；以 SSE 格式推送事件（例如 `data: {"progress_percent":50,"current_pi":3.14,"pod_count":2}\n\n`）。
   - 資料來源：Phase 4 若已將進度寫入 DB（Calculation 表或子任務表），此端點輪詢 Calculation 後推送；或由 Job 完成時更新 DB、此端點輪詢後推送。
   - 事件欄位建議：progress_percent、current_pi、pod_count、duration_ms 等，與前端約定一致。

2. **新增或擴充** `GET /api/history`
   - 回傳近期 Calculation 列表（例如最新 20～50 筆），供效能對比圖表使用；欄位可含 id、uuid、total_points、mode、status、result_pi、duration_ms、created_at。
   - 可選：分頁或查詢參數（limit、offset）。

### 前端

3. **新增或重構** [resources/js/pages/Calculate.vue](resources/js/pages/Calculate.vue)
   - 整合以下區塊：控制面板、蒙地卡羅 Canvas、圓周率收斂圖、K8s 狀態、效能對比；或改為單一頁面引入多個子元件。
   - 使用 Wayfinder 或 axios 呼叫 POST/GET /api/calculate、GET /api/k8s/status、GET /api/k8s/metrics、GET /api/history；使用 EventSource 訂閱 `/api/calculate/{id}/stream`。
   - 開始計算後建立 SSE 連線，收到事件即更新進度條、current_pi、Pod 數等；計算結束後關閉 SSE。

4. **新增** 元件（可放在 [resources/js/components/](resources/js/components/)）
   - [resources/js/components/ControlPanel.vue](resources/js/components/ControlPanel.vue)：點數選擇（10 萬 / 100 萬 / 1000 萬）、模式（single / distributed）、開始 / 停止 / 重置按鈕；emit 或 v-model 與父層通訊。
   - [resources/js/components/MonteCarloCanvas.vue](resources/js/components/MonteCarloCanvas.vue)：Canvas 繪製單位圓與投點（inside/total）；可依 result_inside、result_total 或即時進度繪製。
   - [resources/js/components/PiChart.vue](resources/js/components/PiChart.vue)：使用 Chart.js 繪製圓周率收斂曲線（X 為樣本數或時間，Y 為 current_pi）；可隨 SSE 或輪詢更新。
   - [resources/js/components/K8sStatus.vue](resources/js/components/K8sStatus.vue)：顯示 Pod 數、HPA 狀態、CPU/Memory 使用率；資料來自 GET /api/k8s/status、GET /api/k8s/metrics。
   - [resources/js/components/PerformanceComparison.vue](resources/js/components/PerformanceComparison.vue)：以 GET /api/history 資料繪製圖表（例如不同 total_points 或 mode 的 duration_ms 對比、Pod 數與耗時）。

5. **RWD**
   - 使用 Tailwind 響應式斷點（sm、md、lg），使儀表板在手機與桌面皆可讀可操作。

### 測試

6. **後端**：可為 SSE 端點撰寫 Feature Test（例如建立計算後請求 stream URL，讀取 response stream 並檢查至少一筆 event 格式）。
7. **前端**：以手動或 E2E 驗證儀表板操作、Canvas 與圖表有資料、SSE 連線後有即時更新。

---

## 驗收條件

1. 儀表板可完整操作（選擇點數、模式、開始/停止/重置），並顯示結果與耗時。
2. 蒙地卡羅 Canvas 與圓周率收斂圖有正確資料來源並顯示。
3. K8s 狀態區顯示 Pod 數、CPU/Memory（可輪詢或 SSE）。
4. SSE 連線後可看到即時進度與 K8s 狀態更新。
5. 效能對比區可顯示歷史記錄圖表（來自 GET /api/history）。

---

## 交接給下一階段

Phase 6 執行前需具備：

- 完整前端儀表板與 SSE 即時更新。
- GET /api/history 可供文件與截圖使用（Phase 6 README、截圖、效能數據）。
