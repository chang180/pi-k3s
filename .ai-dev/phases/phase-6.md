# Phase 6：測試、文件與可選 AI

## 階段目標與產出

- **一句話目標**：補齊端到端與效能測試、撰寫 README 與架構圖與部署指南、截圖或 GIF、Git 整理；可選整合 Laravel AI SDK 說明型 Agent 與 `/api/ai/ask` 串流。
- **可驗證產出**：
  - `php artisan test` 通過、`vendor/bin/pint --dirty --format agent` 通過。
  - README 可依步驟完成本地與 K8s 部署；架構圖與截圖齊全。
  - 可選：`/api/ai/ask` 可串流回覆（需 OPENAI_API_KEY 或其它 provider）。

---

## 前置條件

- **環境**：與 Phase 5 相同；專案已具備完整功能（計算、K8s、前端、SSE）。
- **必須已完成的階段**：Phase 1～5。
- **需存在的檔案或設定**：完整前端與 GET /api/history；若實作可選 AI，需可設定 API key 的環境。

---

## 參考

- [plan.md](../plan.md)：展示與作品集呈現（README、截圖與 GIF、面試準備）、成功指標、Laravel AI SDK 整合方案（可選）、參考資源。

---

## 細部工作清單

### 測試

1. **補齊** 端到端或關鍵路徑 Feature Test
   - 涵蓋：POST/GET /api/calculate（single 與 distributed）、GET /api/k8s/status、GET /api/history、可選 SSE 或 stream 端點。
   - 確保 `php artisan test` 全套通過。

2. **可選** 效能測試
   - 記錄 10 萬 / 100 萬 / 1000 萬點與 1 / 2 / 3 Pod 的耗時，寫入 README 或 [docs/](docs/) 供展示使用。

### 文件

3. **撰寫** [README.md](README.md)
   - 專案簡介（一句話說明 Pi-K3s 目的）。
   - 本地開發：PHP、Composer、Node、Redis 需求；`composer install`、`npm install`、`.env`、`php artisan migrate`、`php artisan serve`、`npm run dev`。
   - K8s 部署：Docker build/push、VPS 上 K3s 安裝、`kubectl apply -f k8s/`、Ingress 或 port-forward 訪問方式。
   - 環境需求：1C1G VPS、對外 IP、可選 Docker Hub 帳號。
   - 效能數據：實際測試結果對比（可從效能測試或手動記錄取得）。
   - 技術細節：HPA 配置、分散式計算邏輯簡述；連結至 docs/。

4. **撰寫** [docs/architecture.md](docs/architecture.md)
   - 以 Mermaid 繪製系統架構圖（使用者 → Ingress → Laravel Pod(s) → MySQL/Redis；Queue Worker；K8s HPA/Metrics）。
   - 簡述蒙地卡羅流程、分散式協調、K8s 整合要點。

5. **撰寫** [docs/deployment-guide.md](docs/deployment-guide.md)
   - VPS 前置（SSH、Ubuntu、K3s 安裝）、Image 推送、kubectl apply 順序、ConfigMap/Secrets 設定、驗證步驟、常見問題。

### 展示

6. **截圖與 GIF**（依 plan 展示與作品集呈現）
   - 截圖 1：三合一儀表板（計算 + K8s + 效能）。
   - 截圖 2：kubectl 顯示 HPA 擴展狀態。
   - 可選 GIF 1：完整自動擴展過程（1 pod → 3 pods → 1 pod）。
   - 可選 GIF 2：蒙地卡羅投點動畫。
   - 將檔案放在 `docs/screenshots/` 或 README 內嵌連結，並在 README 中列出。

### 可選：Laravel AI SDK

7. **安裝與設定**
   - `composer require laravel/ai`
   - `php artisan vendor:publish --provider="Laravel\Ai\AiServiceProvider"`
   - `php artisan migrate`
   - 在 `config/ai.php` 或 `.env` 設定 `OPENAI_API_KEY`（或其它 provider）；部署時以 K8s ConfigMap/Secret 注入。

8. **新增** Agent：[app/Ai/Agents/PiK3sExplainer.php](app/Ai/Agents/PiK3sExplainer.php)
   - `instructions()` 回傳字串：簡介蒙地卡羅法、HPA、本專案 Pi-K3s 用途（可參考 plan 內容）。
   - 可選實作 `Conversational` 與 `RemembersConversations` 做多輪問答。

9. **新增** 路由與 Controller
   - `POST /api/ai/ask` 或 `POST /api/ai/chat`：接收使用者訊息，呼叫 PiK3sExplainer 的 `stream()`，回傳 SSE。
   - 前端可選「問 Pi-K3s」輸入框與 EventSource/ fetch stream 顯示回覆。

10. **文件**：在 README 或 docs 註明「可選 AI 功能需設定 OPENAI_API_KEY」。

### Git

11. **建議** commit 訊息、可選 tag（如 v1.0）、GitHub 發布步驟
    - 可寫入本 phase-6.md 或 README：例如「完成 Phase 6 後可 git add、commit、push；可打 tag v1.0 並在 GitHub 建立 release」。

---

## 驗收條件

1. `php artisan test` 通過；`vendor/bin/pint --dirty --format agent` 通過。
2. README 可依步驟完成本地與 K8s 部署；架構圖（Mermaid）與部署指南齊全。
3. 截圖（與可選 GIF）已備齊並在 README 或 docs 中引用。
4. 若實作可選 AI：`/api/ai/ask` 可串流回覆，且文件註明 API key 需求。

---

## 交接給下一階段

無下一階段；專案可交付與展示。後續若有維護或新功能，可再新增 phase 或直接於主計畫與程式碼中迭代。
