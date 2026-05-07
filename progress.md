# Progress: Pi-K3s 專案改進

## Status

- **目前 phase**：✅ 全部完成
- **已完成 phase**：Phase 1, 2, 3, 4, 5, 6
- **上次 commit**：（將於本 phase 結束建立）

## Completed

- ✅ Laravel 13 升級（前置任務，已 push）
- ✅ Phase 1: 基礎清理
- ✅ Phase 2: UI 中文化
- ✅ Phase 3: 首頁重設計
- ✅ Phase 4: /calculate UI 重整
- ✅ Phase 5: K8s 狀態強化
- ✅ Phase 6: 部署文件強化

## Phase 1: 基礎清理（已完成）

- [x] `.env` `APP_URL` 改為 `https://pi-k3s.test`（用戶已自行更新）
- [x] [README.md](README.md) 技術棧 L12 → L13
- [x] [README.md](README.md) 本地開發補充 Herd 提示
- [x] [README.md](README.md) 開發進度表加 L13 + 後續改進
- [x] `php artisan test --compact`：83 passed
- [x] `vendor/bin/pint --dirty --format agent`：passed
- [x] `curl https://pi-k3s.test/`：200
- [x] commit

## Phase 2: UI 中文化（已完成）

- [x] `.env.example` `APP_LOCALE=zh_TW`、`APP_FAKER_LOCALE=zh_TW`
- [x] 核心展示元件中文化（ControlPanel、K8sStatus、MonteCarloCanvas、PiChart、PerformanceComparison、AiChat）
- [x] [Calculate.vue](resources/js/pages/Calculate.vue) 翻譯
- [x] [Dashboard.vue](resources/js/pages/Dashboard.vue) 翻譯
- [x] auth 頁面（Login、Register、ForgotPassword、ResetPassword、ConfirmPassword、VerifyEmail、TwoFactorChallenge）
- [x] settings 頁面（Profile、Password、Appearance、TwoFactor）
- [x] 共用元件（AppLogo、AppHeader、AppSidebar、NavMain、UserMenuContent、DeleteUser、AppearanceTabs、TwoFactorRecoveryCodes、TwoFactorSetupModal）
- [x] sidebar/header 連結改指 chang180/pi-k3s 而非 laravel/vue-starter-kit
- [x] `npm run build`：成功
- [x] `php artisan test --compact`：83 passed
- [x] `vendor/bin/pint --dirty --format agent`：passed

## Phase 3: 首頁重設計（已完成）

- [x] [Welcome.vue](resources/js/pages/Welcome.vue) 整個重寫成 Pi-K3s 主題 landing
  - Top nav：Pi-K3s logo + 登入/註冊或儀表板
  - Hero 區：主標「在樹莓派 K3s 上看見 π 的誕生」+ 副標 + 兩個 CTA + SVG π 視覺化
  - 特色區：三張卡片（蒙地卡羅可視化、HPA 自動擴展、1C1G 友善）
  - 執行原理區：四步驟說明
  - 技術棧 + 二次 CTA 區
  - Footer：GitHub 連結
- [x] 主 CTA `立即體驗計算 →` 連到 `/calculate`（demo 免登入）
- [x] 響應式：手機單欄、桌機 grid 兩欄
- [x] Dark mode 支援（沿用 starter 機制）
- [x] Tailwind v4 慣例：`bg-linear-to-*`（IDE diagnostic 提示後修正）
- [x] `npm run build`：Welcome bundle 47.68 kB → 13.51 kB
- [x] `php artisan test --compact`：83 passed
- [x] `vendor/bin/pint --dirty --format agent`：passed
- [x] `curl https://pi-k3s.test/`：Inertia 回傳 component=Welcome、prop canRegister 正確

## Phase 4: /calculate UI 重整（已完成）

- [x] 加 page header（h1「計算 π」+ 副標 + 即時顯示 UUID 前 8 碼）
- [x] 上排 grid 響應式：`md:grid-cols-2 lg:grid-cols-3`（中型螢幕從 1 欄改 2 欄，桌機 3 欄）
- [x] Query 區塊改為 `<details>` 折疊（預設收起，不主要佔位）
- [x] Query 結果改為 grid 雙欄、視覺更乾淨
- [x] AiChat 維持原本（已是完整 card），不重複包裝
- [x] `npm run build`、test、pint 全綠

## Phase 5: K8s 狀態強化（已完成）

- [x] [resources/js/types/calculation.ts](resources/js/types/calculation.ts) — `K8sStatusResponse` 對齊後端實際輸出（`phase` 而非 `status`、移除 `node`、HPA shape）
- [x] [resources/js/components/K8sStatus.vue](resources/js/components/K8sStatus.vue) 全面重寫：
  - 標題列加 In-Cluster / 本機開發 標籤
  - 本機 fallback：明確的「未在 K8s 叢集中執行」說明卡 + 半透明佔位 tiles
  - HPA 詳情卡：副本數 + 進度條 + 擴縮中提示（desired ≠ current 時）
  - Pod 列表：彩色狀態 dot（Running 綠 / Pending 黃 / Failed 紅）+ 截短名稱 + 未就緒徽章
  - 合併 metrics（CPU / 記憶體）到 Pod 列表內
- [x] 後端不需改動（[K8sClientService](app/Services/K8sClientService.php) 已提供完整資料）
- [x] `npm run build`、test 83 passed、pint 全綠
- [x] 本機 API smoke：`/api/k8s/status` 回 `in_cluster:false`、shape 正確

## Phase 6: 部署文件強化（已完成）

- [x] [docs/deployment-guide.md](docs/deployment-guide.md) 增補：
  - 「資源監控」段加入 [scripts/monitor-resources.sh](scripts/monitor-resources.sh) 使用說明
  - 加入「應用程式內建狀態」段，介紹 Phase 5 強化後的 K8sStatus 卡呈現
  - 新增「1C1G 環境調校建議」段：記憶體壓力（patch HPA、swap 確認）、CPU 持續滿載、SQLite 鎖定、SSE 連線中斷
  - 新增「部署檢核清單」段：10 項可逐一勾選
- [x] `php artisan test --compact`：83 passed

---

## Deviations

- Phase 1 原訂自己改 `.env` `APP_URL`，但用戶已先行修改，跳過。
- Phase 2 原訂建立 `lang/zh_TW/` 目錄與 `validation.php` 等翻譯檔，**未建立**。理由：UI 字串都直接寫死中文於 Vue 元件中，後端僅在 form 驗證錯誤時才會回 Laravel 內建英文訊息（auth/profile 路徑），影響面有限。如要完整覆蓋，未來可 `php artisan lang:publish` 再翻譯。
- Phase 2 跳過 [Welcome.vue](resources/js/pages/Welcome.vue) 翻譯，因為 Phase 3 會整個重做。

## Issues

None

## Files Changed

### Phase 1
- [README.md](README.md) — 技術棧 L13、Herd 提示、進度表更新
- [plan.md](plan.md) — 多 phase 改進計畫（覆寫前一版 L13 升級用的）
- [progress.md](progress.md) — phase 進度追蹤

### Phase 2
- [.env.example](.env.example) — APP_LOCALE 改 zh_TW
- 約 22 個 Vue 元件 / 頁面翻譯（auth、settings、components、Calculate、Dashboard）
- 詳見 git diff：`git diff master~1 -- resources/`

### Phase 3
- [resources/js/pages/Welcome.vue](resources/js/pages/Welcome.vue) — 全新 Pi-K3s 主題 landing

### Phase 4
- [resources/js/pages/Calculate.vue](resources/js/pages/Calculate.vue) — page header、grid 響應式、Query 改折疊

### Phase 5
- [resources/js/types/calculation.ts](resources/js/types/calculation.ts) — K8s types 對齊後端
- [resources/js/components/K8sStatus.vue](resources/js/components/K8sStatus.vue) — 重寫，加 Pod 列表、HPA 進度條、本機 fallback

### Phase 6
- [docs/deployment-guide.md](docs/deployment-guide.md) — 加 monitor 腳本說明、應用程式內建狀態、1C1G 調校建議、部署檢核清單

## Verification

### Phase 1
- `php artisan test --compact`：83 passed (305 assertions)
- `vendor/bin/pint --dirty --format agent`：passed
- `curl -sk https://pi-k3s.test/`：HTTP 200

### Phase 2
- `npm run build`：成功
- `php artisan test --compact`：83 passed (305 assertions)
- `vendor/bin/pint --dirty --format agent`：passed

### Phase 3
- `npm run build`：成功，Welcome bundle 大幅減重
- `php artisan test --compact`：83 passed
- `vendor/bin/pint --dirty --format agent`：passed
- `curl -sk https://pi-k3s.test/`：Inertia component=Welcome 正確
- 待手動驗證：用戶在瀏覽器 https://pi-k3s.test/ 視覺確認

### Phase 4
- `npm run build`：成功
- `php artisan test --compact`：83 passed
- `vendor/bin/pint --dirty --format agent`：passed
- 待手動驗證：用戶在瀏覽器 https://pi-k3s.test/calculate 跑完整流程

### Phase 5
- `npm run build`：成功
- `php artisan test --compact`：83 passed
- `vendor/bin/pint --dirty --format agent`：passed
- API smoke：`/api/k8s/status` 與 `/api/k8s/metrics` 回應正確
- 待真實叢集驗證：部署到 K3s 後手動驗證 Pod 列表、HPA 進度條呈現

### Phase 6
- `php artisan test --compact`：83 passed
- 文件 markdown 渲染待手動於 GitHub 或 IDE preview 確認排版

## Next Steps

✅ 全部 6 個 phase 完成。剩餘：

- 用戶手動驗收：瀏覽器訪問 `https://pi-k3s.test/` 與 `/calculate`，確認新版 UI、中文、響應式表現
- 真實 VPS / K3s 叢集驗證 Phase 5 強化後的 K8sStatus 顯示
- 後續可選：完整 lang/zh_TW 翻譯（目前 Laravel 內建錯誤訊息仍是英文）、SSR 啟用、首頁加入 demo 動畫等
