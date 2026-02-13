# Pi-K3s 分階段開發文件

本目錄包含六個階段的獨立開發文件，供不同 AI 依序執行。每階段一份 Markdown，執行時請只讀取被指派的 `phase-N.md` 與專案根目錄的 [plan.md](../plan.md)。

---

## 專案與主計畫

- **專案名稱**：Pi-K3s - 分散式圓周率計算展示平台
- **主計畫**：[.ai-dev/plan.md](../plan.md) — 技術棧、API 設計、K8s 架構、檔案結構、技術重點與注意事項

---

## 階段一覽

| 階段 | 檔案 | 一句話目標 | 依賴 |
|------|------|------------|------|
| Phase 1 | [phase-1.md](phase-1.md) | 蒙地卡羅單機 + POST/GET /api/calculate + 簡單前端可選點數並顯示 π | 無（專案已為 Laravel 12 + Inertia/Vue） |
| Phase 2 | [phase-2.md](phase-2.md) | Dockerfile + 最小 K8s（namespace、deployment、service、ingress），本機可 build/run 或 K8s 部署訪問 | Phase 1 |
| Phase 3 | [phase-3.md](phase-3.md) | 1C1G VPS 安裝 K3s、部署應用、外網可訪問；觀察單 Pod 資源供 HPA 參考 | Phase 2 |
| Phase 4 | [phase-4.md](phase-4.md) | HPA、分散式計算協調器、K8s API（Pod/HPA）、Laravel Queue（Redis）與 Worker | Phase 3 |
| Phase 5 | [phase-5.md](phase-5.md) | 前端視覺化（控制面板、Canvas、Chart、K8s 狀態、效能對比）+ SSE 即時推送 | Phase 4 |
| Phase 6 | [phase-6.md](phase-6.md) | 測試、README、架構圖、截圖/GIF、Git 整理；可選 Laravel AI SDK | Phase 5 |

---

## 給執行 AI 的指引

1. **執行前必讀**
   - [.ai-dev/plan.md](../plan.md) — 技術棧、API 設計、專案檔案結構、技術重點與注意事項
   - 專案 [CLAUDE.md](../../CLAUDE.md) / [AGENTS.md](../../AGENTS.md) — Laravel/Pest/Pint/Inertia/Wayfinder 慣例

2. **執行範圍**
   - 僅執行被指派的 **單一** `phase-N.md`；完成該檔內所有「細部工作清單」與「驗收條件」後再進行下一階段。
   - 不得改動其他階段約定的介面（如 API 路徑、Response 欄位、類別名稱），除非在該 phase 文件中明確允許。

3. **每階段結束時**
   - 執行 `php artisan test`（可用 `--filter=...` 限定相關測試）
   - 執行 `vendor/bin/pint --dirty --format agent`
   - 若有前端改動：`npm run build` 或提醒使用者執行 `npm run dev`

4. **交接**
   - 每份 phase-N.md 末尾有「交接給下一階段」；下一階段執行前請確認所列檔案、路由、環境變數已就緒。

---

## 主要產出與檔案清單（摘要）

| 階段 | 主要產出 | 關鍵檔案（新增/修改） |
|------|----------|------------------------|
| Phase 1 | 單機計算、API、簡單前端 | MonteCarloService.php, Calculation model + migration, CalculateController.php, StoreCalculationRequest, api routes, Calculate.vue |
| Phase 2 | 容器化與最小 K8s | Dockerfile, .dockerignore, k8s/namespace.yaml, deployment.yaml, service.yaml, ingress.yaml, 可選 docker/nginx.conf |
| Phase 3 | VPS 部署與資源觀察 | 部署步驟、可選 mysql/redis K8s、資源記錄 |
| Phase 4 | HPA、分散式、K8s API | hpa.yaml, RBAC, CalculatePiJob, DistributedCalculator, K8sClientService, /api/k8s/status, /api/k8s/metrics |
| Phase 5 | 視覺化與 SSE | /api/calculate/{id}/stream, /api/history, ControlPanel, MonteCarloCanvas, PiChart, K8sStatus, PerformanceComparison, EventSource |
| Phase 6 | 測試、文件、可選 AI | README.md, docs/architecture.md, docs/deployment-guide.md, 可選 PiK3sExplainer, /api/ai/ask |
