# Feature: Laravel 12 → 13 升級

## Objective

把專案核心 framework 從 Laravel 12 升到 13.x（最新 13.8），同步升級所有相關官方/社群套件至支援 L13 的版本。

升級後維持現有功能完整可用：Pi 計算 API、SSE stream、AI chat、Wayfinder route 產生、k8s 部署 manifests。

## Scope

### In Scope

- `composer.json` require / require-dev 的 framework 與直接相關套件版本約束
- 連動升級：
  - `laravel/framework` `^12.0` → `^13.0`
  - `laravel/fortify` `^1.30` → `^1.37`
  - `laravel/tinker` `^2.10.1` → `^3.0`（major bump）
  - `laravel/wayfinder` `^0.1.9` → `^0.1.17`
  - `laravel/ai` `^0.1.5` → `^0.6.6`（major bump，0.1 → 0.6）
  - `laravel/boost` `^2.0` → `^2.4`
  - `laravel/pail` `^1.2.2` → `^1.2.6`
  - `laravel/sail` `^1.41` → `^1.58`
  - `nunomaduro/collision` `^8.6` → `^8.9`
  - `pestphp/pest-plugin-laravel` `^4.0` → `^4.1`
  - `inertiajs/inertia-laravel` `^2.0` → `^3.1`（major bump）
- 因升級造成的程式碼相容性修改（特別是 `laravel/ai` 與 `inertia-laravel`）
- 跑 `php artisan test`、`npm run build` 全部綠

### Out of Scope

- 三項改進主題（首頁重設計、中文化、VPS 狀態頁）— 留待 L13 升級完成後另行 plan
- 業務邏輯變動（蒙地卡羅演算法、HPA、SSE 行為）
- .env 內容變動
- k8s manifests 重寫（除非 L13 升級必要）
- 前端 npm 套件版本升級（除非有 peer dep 需求）

## Success Criteria

- [ ] `composer install` 完成且無 conflict
- [ ] `composer show laravel/framework` 顯示 `v13.x`
- [ ] `php artisan migrate:fresh` 成功
- [ ] `php artisan test --compact` 全部通過（基準：升級前先跑一次拿到目前 baseline）
- [ ] `npm run build` 成功
- [ ] 啟動 `php artisan serve`，瀏覽 `/calculate` 頁面可正常顯示
- [ ] `POST /api/calculate` 回傳 200 + 計算結果
- [ ] AI chat 端點 `POST /api/ai/ask`：API 行為一致或已調整呼叫端
- [ ] `vendor/bin/pint --dirty --format agent` 無錯
- [ ] git status：除 composer.json/composer.lock + 必要程式碼修改外，不含意外變動

## Constraints

- **不動使用者已設定的 `.env`**（除非 L13 強制要求新 key）
- **不改業務邏輯**：只改因升級需要的相容性修正
- **不擅自改前端 API 呼叫格式**：若 `laravel/ai` 後端改變，調整後端 controller 對映即可
- **如果 AI chat 確認壞了且修不快**，先標 TODO 不擋住其他驗證（用戶說過 AI 是可選功能）
- 遵守 CLAUDE.md：使用 `vendor/bin/pint --dirty --format agent` 而非 `--test`
- 全程使用 `--no-interaction`

## Edge Cases

- **laravel/ai 0.1 → 0.6 跨版**：API/設定 key 名稱可能變動，[app/Ai/Agents/PiK3sExplainer.php](app/Ai/Agents/PiK3sExplainer.php) 與 controller 需檢查
- **inertia-laravel 2 → 3 跨版**：Inertia::render、shared props、middleware 可能有變
- **laravel/tinker 2 → 3**：dev-only，理論上不影響 runtime；若有 breaking 影響的是 `php artisan tinker` 互動
- **Laravel 12 → 13 framework 自身 breaking**：middleware 註冊、scheduler API、container 等須對照 upgrade guide
- **PHP 版本**：`laravel/ai 0.6` 要求 `php ^8.3`、`pest-plugin-laravel 4.1` 要求 `^8.3`。本機是 8.4.20、VPS 上的 Dockerfile 用 8.4，OK
- **composer 平台**：composer.lock 重新生成後，需確認 production Docker build 也能重跑
- **k8s manifests**：[k8s/deployment.yaml.example](k8s/deployment.yaml.example) 沒寫死框架版本，預期不需改
- **失敗回滾**：如遇無法解決的 break，執行 `git checkout composer.json composer.lock && composer install` 還原

## Implementation Plan

1. **基線確認**：升級前先跑 `php artisan test --compact` 記錄通過數，確保我們知道升級前的綠基準
2. **更新 composer.json**：以 `composer require` 一次更新所有相關套件版本約束（framework + 連動套件 + dev 套件分開兩道指令）
3. **執行 `composer update`**：產生新的 composer.lock
4. **跑 migration**：`php artisan migrate:fresh --force`
5. **跑測試**：`php artisan test --compact`，記錄失敗
6. **修相容性問題**：依照測試錯誤訊息逐項修，重點關注：
   - `laravel/ai` API 變更（檢查 `app/Ai/`、`app/Http/Controllers/Api/` 中 AI 相關呼叫）
   - `inertia-laravel` v3 變更（檢查 `app/Http/Middleware/HandleInertiaRequests.php` 與 routes）
   - L13 框架本體 breaking（middleware、Carbon、scheduler 等）
7. **前端**：`npm install`（若有 peer dep 變動）+ `npm run build`
8. **手動煙測**：啟 `php artisan serve` 與 `npm run dev`，瀏覽 `/calculate` 頁面，跑一次 single mode 計算
9. **格式化**：`vendor/bin/pint --dirty --format agent`
10. **產出 progress.md**：列出實際做的、偏離 plan 的部分、剩餘風險

## Verification Plan

- **自動**：
  - `php artisan test --compact` — 全綠（與升級前同基準或更好）
  - `npm run build` — 無錯誤
  - `vendor/bin/pint --dirty --format agent` — 無錯
- **手動**（最後驗收）：
  - 在 Herd 環境訪問 `http://pi-k3s.test/calculate`
  - 點擊「Start」執行 100K single mode 計算 → 應顯示 π ≈ 3.14
  - 檢查 K8sStatus 卡片（會回 fallback 因為本機沒 k8s）→ 不該爆 500
  - 不驗 AI chat（需 OPENAI_API_KEY，留給用戶自測），但驗證 `POST /api/ai/ask` 不回 500
- **回滾條件**：如測試失敗超過 3 個無法在合理時間修復、或 `laravel/ai` API 變化太大需重寫 PiK3sExplainer，回報並還原 composer.json
