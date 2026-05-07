# Feature: Pi-K3s 專案改進總計畫

## Objective

把 Pi-K3s 專案從「Laravel starter kit + 英文 UI + 預設首頁」狀態，改造成適合作為**展示平台**的中文版專案：

- 首頁應該介紹 Pi-K3s 而不是 Laravel starter
- UI 全面中文化（保留必要英文技術術語：K8s、HPA、Pod、π 等）
- /calculate 頁面 UI 重整，視覺與資訊架構更清楚
- VPS 1C1G 部署的設定流程與「部署狀態展示」提升
- 文件（README）反映最新狀態

## Scope

### In Scope

- [README.md](README.md) 技術棧／開發進度／截圖段落更新
- [.env](.env) 中 `APP_URL` 對齊 Herd（`http://localhost` → `https://pi-k3s.test`）
- 新增 `lang/zh_TW/`（Laravel translations，雖然目前主要在前端但保留結構）
- 全部 Vue 元件中文化：[Welcome.vue](resources/js/pages/Welcome.vue)、[Calculate.vue](resources/js/pages/Calculate.vue)、[Dashboard.vue](resources/js/pages/Dashboard.vue)、`auth/*`、`settings/*`、所有 `components/*.vue` 中含英文字串者
- 首頁 [Welcome.vue](resources/js/pages/Welcome.vue) **重做**：以 Pi-K3s 為主題的 landing page，主 CTA 連到 /calculate（demo 免登入），nav 保留 Login/Register（登入後改顯示 Dashboard）
- /calculate 頁面 [Calculate.vue](resources/js/pages/Calculate.vue) UI 重整：資訊分區清晰、視覺層次、響應式
- K8s 狀態展示強化：[K8sStatus.vue](resources/js/components/K8sStatus.vue) + 新增「部署資訊卡」顯示 namespace、Pod、節點資源、HPA 狀態
- 1C1G 部署設定文件強化：[docs/deployment-guide.md](docs/deployment-guide.md) 補充記憶體/CPU 監控、設定範例、常見問題

### Out of Scope

- Laravel framework 內核改造（剛升完 L13，不再動）
- 重寫 Pi 計算演算法／K8s manifests 結構（保持原本 HPA/RBAC/Service 設計）
- 多語系切換功能（vue-i18n 等）— 直接改字串成中文，不做 i18n 切換
- 認證流程功能變更（保留 Fortify 既有功能、不改 2FA／passkey）
- 新增使用者個人資料／歷史紀錄頁（Dashboard 仍是預設樣板，留待後續）

## Success Criteria

- [ ] README.md「技術棧」段落寫 Laravel 13、其他事實校正
- [ ] `.env` `APP_URL` 改為 `https://pi-k3s.test`
- [ ] 主要 Vue 頁面與元件全部中文化（含英文技術術語的使用是合理的）
- [ ] 首頁 `/` 是 Pi-K3s 主題的 landing，不再是 Laravel starter 模板
- [ ] `/calculate` 頁面排版清晰，資訊分區合理
- [ ] K8s 狀態卡顯示更多有用資訊（Pod 列表、HPA 狀態、節點資源）
- [ ] [docs/deployment-guide.md](docs/deployment-guide.md) 補上 1C1G 監控與常見問題
- [ ] 全程 `php artisan test --compact` 維持 83 passed
- [ ] `npm run build` 全程不破
- [ ] `vendor/bin/pint --dirty --format agent` 全程綠
- [ ] 每個 phase 結束有對應的 commit

## Constraints

- **每個 phase 獨立可 commit**：方便額度中斷後接續，progress.md 追蹤
- **不動業務邏輯**：API、計算、HPA 行為都不能改
- **不改套件依賴**：不再 `composer require` / `npm install`，純改寫程式碼與文件（除非中文化用到的 dayjs locale 等需要）
- **保留英文技術術語**：K8s、HPA、Pod、Kubernetes、Monte Carlo、π、API、UUID、SSE、CPU、Memory、ms 等不翻
- **不亂動 starter 元件結構**：`AppLayout`、`AppSidebar`、`AppHeader` 等若沒英文字串就別動
- **遵守 CLAUDE.md**：Vue 單根節點、Tailwind 慣例、Pint format agent
- **不建立 documentation 檔案**（README 與 deployment-guide 是更新既有，不算新增）

## Edge Cases

- **元件可能在 starter 安裝時就有英文標籤**（如 Dashboard、Settings、Profile 等）— 這些屬於「框架預設」，仍要中文化但不能破壞功能
- **2FA／passkey 流程**：Fortify 內含的訊息可能來自 vendor publish 的 lang 檔，需要 `php artisan vendor:publish --tag=fortify-views/lang` 後才能改
- **錯誤訊息**：Laravel 預設驗證訊息會用 `lang/en/validation.php`，要改中文需要加 `lang/zh_TW/validation.php`
- **中英混排排版**：標點、空格、行高需要調整避免擠在一起
- **/calculate 改版時的 props 相容性**：[ControlPanel.vue](resources/js/components/ControlPanel.vue) 等子元件 props 不能亂改，否則 Calculate.vue 會壞
- **Wayfinder 產生的 TS 檔不要手改**：那是 build 時自動生成
- **K8s 狀態卡在本機沒 K8s 時要 graceful fallback**：本機開發看不到真資料，需要 mock 或 N/A 顯示
- **APP_URL 改了之後 Inertia ziggy / wayfinder 路由絕對 URL 受影響**：改完要重 build 並驗證

## Implementation Plan

整體分為 6 個 phase，依序執行，每完成一個就 commit + 更新 progress.md。

### Phase 1：基礎清理（小工，先把雜項做掉）

1. 修正 [.env](.env) `APP_URL` 為 `https://pi-k3s.test`
2. 更新 [README.md](README.md)：
   - 「技術棧」 Laravel 12 → 13
   - 開發進度表加註 L13 升級已完成
   - 文字調整、修正連結
3. 跑 test + build + pint
4. Commit：`docs: README 同步 L13 升級狀態與環境設定修正`

### Phase 2：UI 中文化

1. 建立 [lang/zh_TW/](lang/) 目錄與必要翻譯檔（validation.php 等）
2. 在 [config/app.php](config/app.php) 設定 `locale` 為 `zh_TW`（透過 `APP_LOCALE` env）
3. 改 [.env.example](.env.example) 與 [.env](.env)：`APP_LOCALE=zh_TW`、`APP_FALLBACK_LOCALE=en`
4. 逐檔翻譯（依 grep 結果）：
   - [resources/js/pages/Welcome.vue](resources/js/pages/Welcome.vue)（暫時翻譯，下個 phase 整個重做）
   - [resources/js/pages/Calculate.vue](resources/js/pages/Calculate.vue)
   - [resources/js/pages/Dashboard.vue](resources/js/pages/Dashboard.vue)
   - [resources/js/pages/auth/*.vue](resources/js/pages/auth/)
   - [resources/js/pages/settings/*.vue](resources/js/pages/settings/)
   - [resources/js/components/ControlPanel.vue](resources/js/components/ControlPanel.vue)
   - [resources/js/components/K8sStatus.vue](resources/js/components/K8sStatus.vue)
   - [resources/js/components/MonteCarloCanvas.vue](resources/js/components/MonteCarloCanvas.vue)
   - [resources/js/components/PiChart.vue](resources/js/components/PiChart.vue)
   - [resources/js/components/PerformanceComparison.vue](resources/js/components/PerformanceComparison.vue)
   - [resources/js/components/AiChat.vue](resources/js/components/AiChat.vue)
   - [resources/js/components/AppSidebar.vue](resources/js/components/AppSidebar.vue)、`AppHeader`、`UserMenuContent`、`DeleteUser`、`AppLogo` 等
5. `Head title` 屬性也要中文化
6. 跑 test + build + pint，啟 dev server 在瀏覽器抽查
7. Commit：`feat(i18n): UI 全面中文化`

### Phase 3：首頁重設計

1. 重寫 [resources/js/pages/Welcome.vue](resources/js/pages/Welcome.vue)：
   - Hero 區：「在樹莓派 K3s 上看見 π 的誕生」+ 一句副標
   - 三段特色卡：蒙地卡羅可視化／K8s HPA 自動擴展／1C1G 友善部署
   - 主 CTA：「立即體驗計算 →」連到 `/calculate`（不需登入）
   - 次 CTA：登入／註冊（給有意願追蹤歷史的使用者）
   - 簡單的「執行原理」段（蒙地卡羅 + HPA 圖示）
   - footer：GitHub 連結、技術棧
2. 簡單的 hero 動畫（CSS keyframes 投點動畫，輕量）
3. 響應式：手機（單欄）／平板（雙欄）／桌機（多欄）
4. Dark mode 支援（沿用 starter 的設定）
5. 跑 build + 瀏覽器測試
6. Commit：`feat(home): Pi-K3s 主題 landing 取代 Laravel starter`

### Phase 4：/calculate 頁面 UI 重整

1. 重新設計 [Calculate.vue](resources/js/pages/Calculate.vue) layout：
   - **頂部**：標題列（含計算 ID/UUID 即時顯示）
   - **左側欄**：ControlPanel（垂直排列，更多空間）
   - **主區**：上半 — Monte Carlo Canvas（更大）+ 即時結果；下半 — π 收斂圖
   - **右下**：K8s 狀態 + 部署資訊
   - **下方**：效能對比（多歷史比較）
   - 移除「Query Existing Calculation」區塊或合併到下方歷史紀錄
2. 子元件視覺優化（卡片陰影、間距、字級）
3. Loading 狀態的 skeleton（Inertia v3 deferred props 友善）
4. 響應式：手機改為垂直堆疊
5. AI Chat 移到固定的浮動按鈕（FAB）
6. 跑 build + 瀏覽器跑完整流程：100K single → 1M distributed → 看歷史
7. Commit：`refactor(calculate): UI 重整與資訊架構優化`

### Phase 5：K8s 狀態展示強化

1. 強化 [K8sStatus.vue](resources/js/components/K8sStatus.vue)：
   - Pod 列表（名稱、狀態、CPU/記憶體用量）
   - HPA 狀態（min/max/current replicas、目標 CPU%、實際 CPU%）
   - 節點資源（總記憶體/CPU、剩餘）
   - 本機沒 K8s 時 graceful fallback：顯示「目前不在 K8s 環境，以下為展示樣式」
2. 新增「部署資訊卡」元件：namespace、image、deploy 時間、git commit
3. 後端 API 新增需要的端點（如果原 `/api/k8s/status` 不夠）
4. 跑 test + build
5. Commit：`feat(k8s-status): 強化 Pod/HPA/節點資源展示與本機 fallback`

### Phase 6：1C1G 部署文件強化

1. 更新 [docs/deployment-guide.md](docs/deployment-guide.md)：
   - 1C1G 監控腳本說明（指向 [scripts/monitor-resources.sh](scripts/monitor-resources.sh)）
   - 記憶體不足時的應對（HPA max 調 1、停 queue worker 等）
   - 常見問題：metrics-server 沒裝、SSE 連線斷、SQLite locked
   - 部署檢核清單
2. 補充 [README.md](README.md) 連結
3. Commit：`docs: 強化 1C1G VPS 部署指南與故障排除`

## Verification Plan

每個 phase 結束都要做：

- **自動**：
  - `php artisan test --compact` — 維持 83 passed
  - `npm run build` — 無錯誤
  - `vendor/bin/pint --dirty --format agent` — passed
- **手動**（依 phase 重點）：
  - Phase 1：訪問 `https://pi-k3s.test` 確認轉址正常、README 在 GitHub 上格式 OK
  - Phase 2：每個改過的頁面開瀏覽器，文字顯示正確、不破版
  - Phase 3：手機／桌機尺寸都看一次首頁，CTA 點擊測試
  - Phase 4：跑一次完整計算流程（single + distributed），AI chat 仍能用
  - Phase 5：本機 fallback 顯示正確、與 [K8sController](app/Http/Controllers/Api/K8sController.php) 對齊
  - Phase 6：用 markdown preview 看文件排版

每個 phase 結束 → 更新 [progress.md](progress.md) → commit。

## Pause/Resume Protocol

如果額度耗盡：
- progress.md 紀錄當前完成到哪個 phase
- 下次接續時讀 plan.md + progress.md 即可知道上次做到哪
- 用 `git log --oneline` 也能看到 commit 對應的 phase
