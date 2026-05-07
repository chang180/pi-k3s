# Progress: Pi-K3s 專案改進

## Status

- **目前 phase**：Phase 3 待開始
- **已完成 phase**：Phase 1, 2
- **上次 commit**：（將於本 phase 結束建立）

## Completed

- ✅ Laravel 13 升級（前置任務，已 push）
- ✅ Phase 1: 基礎清理
- ✅ Phase 2: UI 中文化

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

## Phase 3: 首頁重設計（待開始）

## Phase 4: /calculate UI 重整（待開始）

## Phase 5: K8s 狀態強化（待開始）

## Phase 6: 部署文件強化（待開始）

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

## Verification

### Phase 1
- `php artisan test --compact`：83 passed (305 assertions)
- `vendor/bin/pint --dirty --format agent`：passed
- `curl -sk https://pi-k3s.test/`：HTTP 200

### Phase 2
- `npm run build`：成功
- `php artisan test --compact`：83 passed (305 assertions)
- `vendor/bin/pint --dirty --format agent`：passed

## Next Steps

Phase 3：首頁重設計。Welcome.vue 換成 Pi-K3s 主題 landing。
