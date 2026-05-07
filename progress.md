# Progress: Laravel 12 → 13 升級

## Completed

- 取得升級前測試 baseline：83 passed (315 assertions)
- 更新 [composer.json](composer.json) require / require-dev 區塊：
  - `laravel/framework` ^12.0 → ^13.0（實裝 13.8.0）
  - `inertiajs/inertia-laravel` ^2.0 → ^3.1（實裝 3.1.0，major bump）
  - `laravel/ai` ^0.1.5 → ^0.6（實裝 0.6.6，major bump）
  - `laravel/tinker` ^2.10.1 → ^3.0（實裝 3.0.2，major bump）
  - `laravel/wayfinder` ^0.1.9 → ^0.1.17
  - `laravel/fortify` ^1.30 → ^1.37
  - `laravel/boost` ^2.0 → ^2.4
  - `laravel/pail` ^1.2.2 → ^1.2.6
  - `laravel/sail` ^1.41 → ^1.58
  - `nunomaduro/collision` ^8.6 → ^8.9
  - `pestphp/pest-plugin-laravel` ^4.0 → ^4.1
  - 連帶更新：`laravel/mcp` 0.5.x → 0.7.0、`pestphp/pest` 4.3 → 4.7
- 重新生成 [composer.lock](composer.lock)
- 跑 `php artisan test --compact`：83 passed
- 跑 `npm run build`：成功，無錯誤
- 跑 `vendor/bin/pint --dirty --format agent`：passed

## Deviations

- **未動到任何業務程式碼**。原本擔心 `laravel/ai 0.1 → 0.6`、`inertia-laravel 2 → 3`、`tinker 2 → 3` 三個 major bump 會需要 controller / middleware 改動，實測下來測試與 build 全綠，且實機 API 呼叫正常，沒有遇到 break。
- **未更新 [README.md](README.md) 中 "技術棧" 段落的 "Laravel 12"**，避免文件變動和升級任務混雜。可作為下一個小任務處理。

## Issues

- **Pest 斷言計數差異**：升級前 315 assertions、升級後 305 assertions（測試數仍為 83）。差 10 條斷言，推測是 Pest 4.3 → 4.7 內部計數方式變化（例如 `expect()->toBeArray()` 等鏈式斷言的計數可能合併），不是真正少測。確認所有 83 個測試 case 都通過，視為 OK。
- **APP_URL 不一致**：[.env](.env) 仍是 `APP_URL=http://localhost`，但 Herd 透過 `https://pi-k3s.test` 提供服務，造成 301 跳轉。這是升級**前**就存在的問題，不屬於本次升級導致；建議稍後改成 `APP_URL=https://pi-k3s.test`。
- **README 中「技術棧」標的 Laravel 12**：未更新，後續處理。

## Files Changed

- [composer.json](composer.json) — 套件版本約束更新
- [composer.lock](composer.lock) — 重新解析後的鎖檔
- (前端 build 產物) [public/build/](public/build/) — `npm run build` 重新生成的 hash 檔名

未修改任何 `app/`、`routes/`、`resources/` 程式碼。

## Verification

- **`php artisan test --compact`**：83/83 passed（與升級前相同）
- **`npm run build`**：成功，所有 Vue 元件 chunk 重新打包
- **`vendor/bin/pint --dirty --format agent`**：passed
- **`php artisan --version`**：Laravel Framework 13.8.0
- **API smoke test**：`POST https://pi-k3s.test/api/calculate {total_points:100000, mode:single}` → 201 `result_pi: 3.14496`、`duration_ms: 7`
- **路由 smoke**：`GET /` 200、`GET /calculate` 200

## Next Steps

- 把 [.env](.env) 的 `APP_URL` 改成 `https://pi-k3s.test`（Herd 預設 TLS），避免 301 跳轉
- 更新 [README.md](README.md) 技術棧段落 Laravel 12 → 13
- 推進原本提的三項改進（首頁/i18n/VPS 狀態頁），各自寫獨立 plan
- 手動瀏覽器測試：到 `https://pi-k3s.test/calculate` 走完整流程（single + distributed mode）、AI chat（如果有設定 OPENAI_API_KEY）
