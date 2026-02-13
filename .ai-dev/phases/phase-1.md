# Phase 1：核心計算與 API

## 階段目標與產出

- **一句話目標**：實作蒙地卡羅單機計算、`POST/GET /api/calculate` API，以及簡單前端可選點數並顯示 π。
- **可驗證產出**：
  - `POST /api/calculate` 可建立計算任務並回傳 `id`、`uuid`、`status`，完成時含 `result_pi`、`duration_ms`。
  - `GET /api/calculate/{id}` 可查詢單筆計算狀態與結果。
  - 前端頁面可選擇點數（10 萬 / 100 萬 / 1000 萬）、送出後顯示 π 與耗時。
  - 本機 `php artisan serve` + `npm run dev` 可完整驗證。

---

## 前置條件

- **環境**：WSL2 內 PHP、Composer、Node.js 可用；專案已為 Laravel 12 + Inertia/Vue，無需重建專案。
- **必須已完成的階段**：無（Phase 1 為起點）。
- **需存在的檔案或設定**：專案可正常啟動（`php artisan serve`、`npm run dev`），資料庫可遷移（SQLite 或 MySQL 皆可）。

---

## 參考

- [plan.md](../plan.md)：技術棧（Laravel 12、Vue 3、Vite）、核心功能模組 1（蒙地卡羅計算引擎）、API 設計、專案檔案結構、技術重點與注意事項。
- 專案 [CLAUDE.md](../../CLAUDE.md)：Pest、Form Request、Pint、Laravel 慣例。

---

## 細部工作清單

### 後端

1. **新增** [app/Services/MonteCarloService.php](app/Services/MonteCarloService.php)
   - 方法：`calculate(int $totalPoints): array`
   - 回傳形狀：`['pi' => float, 'inside' => int, 'total' => int, 'duration_ms' => int]`
   - 點數限制：定義常數（例如 `MIN_POINTS = 100_000`、`MAX_POINTS = 10_000_000`），僅接受此區間；超出時可拋出 `InvalidArgumentException` 或由呼叫端驗證。
   - 演算法：π ≈ 4 * (inside / total)，使用隨機數在單位圓內投點；計時並回傳 `duration_ms`。

2. **新增** Model + Migration：`Calculation`
   - 欄位：`id`, `uuid` (string, unique), `total_points` (unsigned integer), `mode` (string 或 enum：`single` / `distributed`), `status` (string 或 enum：`pending` / `running` / `completed` / `failed` / `cancelled`), `result_pi` (decimal, nullable), `result_inside` (unsigned integer, nullable), `result_total` (unsigned integer, nullable), `duration_ms` (unsigned integer, nullable), `created_at`, `updated_at`.
   - Model 放在 [app/Models/Calculation.php](app/Models/Calculation.php)，Migration 使用 `php artisan make:model Calculation -m` 或 `php artisan make:migration create_calculations_table`。
   - 若使用 Enum：可放在 `app/Enums/`，例如 `CalculationMode`、`CalculationStatus`；若用字串則在 Form Request 與 Controller 中驗證即可。

3. **註冊 API 路由**
   - 若專案尚無 `routes/api.php`：新增 [routes/api.php](routes/api.php)，並在 [bootstrap/app.php](bootstrap/app.php) 的 `withRouting()` 中加入 `api: __DIR__.'/../routes/api.php'`（Laravel 12 寫法）。
   - 或於 [routes/web.php](routes/web.php) 使用 `Route::prefix('api')->group(...)` 定義 API 路由（二擇一，與專案慣例一致即可）。

4. **新增** Form Request：[app/Http/Requests/StoreCalculationRequest.php](app/Http/Requests/StoreCalculationRequest.php)
   - 驗證規則：`total_points` 必填、整數、介於 100_000 ～ 10_000_000；`mode` 可選、in:single,distributed，預設 `single`。
   - 自訂錯誤訊息（依專案慣例，陣列或字串規則皆可）。

5. **新增** Controller：[app/Http/Controllers/Api/CalculateController.php](app/Http/Controllers/Api/CalculateController.php)
   - `store(StoreCalculationRequest $request)`：建立 `Calculation`（status 先設為 `pending` 或 `running`），本階段僅支援 `mode=single`，同步呼叫 `MonteCarloService::calculate($request->validated('total_points'))`，將結果寫回 `Calculation`（result_pi, result_inside, result_total, duration_ms, status=completed），回傳 JSON：`{ id, uuid, status, result_pi?, result_inside?, result_total?, duration_ms?, ... }`。
   - `show(Calculation $calculation)` 或 `show(string $id)`：以 `id` 或 `uuid` 查詢單筆，回傳 JSON；若不存在回傳 404。
   - 路由：`POST /api/calculate` → `store`，`GET /api/calculate/{calculation}`（或 `{uuid}`）→ `show`；若使用 route model binding，請確保以 `uuid` 或 `id` 可解析。

### 前端

6. **新增** Inertia 頁面：[resources/js/pages/Calculate.vue](resources/js/pages/Calculate.vue)（或整合進既有 Dashboard）
   - 表單：點數選擇（10 萬 / 100 萬 / 1000 萬）、模式（本階段僅 single，可隱藏或唯讀）。
   - 送出後呼叫 `POST /api/calculate`（使用 Wayfinder 產生的 action 或 axios/`fetch`），取得回傳後顯示 `result_pi`、`duration_ms`；錯誤時顯示驗證或伺服器錯誤訊息。
   - 可選：提供「查詢」輸入框，呼叫 `GET /api/calculate/{id}` 顯示該筆結果。

7. **修改** [routes/web.php](routes/web.php)：新增對應 Inertia 路由（例如 `Route::get('/calculate', ...)->name('calculate')` 指向 `Calculate.vue`），並在導航中加入連結（可選，視既有 layout 而定）。

### 測試

8. **新增** Feature Test（Pest）：例如 [tests/Feature/CalculateControllerTest.php](tests/Feature/CalculateControllerTest.php) 或 [tests/Feature/Api/CalculateTest.php](tests/Feature/Api/CalculateTest.php)
   - `POST /api/calculate`：傳入合法 `total_points`（與 `mode`）回傳 201/200，JSON 含 `id`、`uuid`、`status`、完成時含 `result_pi`、`duration_ms`。
   - `POST /api/calculate`：傳入無效 `total_points`（過小、過大、非整數）回傳 422。
   - `GET /api/calculate/{id}`：存在時回傳 200 與該筆資料；不存在時回傳 404。

9. **可選** Unit Test：[tests/Unit/MonteCarloServiceTest.php](tests/Unit/MonteCarloServiceTest.php) — 驗證 `MonteCarloService::calculate` 回傳結構與 `pi` 在合理範圍（例如 3.0～3.3 對大樣本）。

### 專案慣例

- 遵循 [CLAUDE.md](../../CLAUDE.md)：Pest、Form Request、Pint；不新增 composer/npm 依賴。

---

## 驗收條件

1. **測試**：執行 `php artisan test --filter=Calculate`（或對應的 test 名稱），全部通過。
2. **API**：
   - `curl -X POST http://localhost:8000/api/calculate -H "Content-Type: application/json" -d '{"total_points":100000,"mode":"single"}'` 回傳 JSON 含 `id`、`uuid`、`status`、完成後含 `result_pi`、`duration_ms`。
   - `curl http://localhost:8000/api/calculate/{id}` 回傳該筆計算。
3. **前端**：本機開啟 `/calculate`（或設定的路徑），選擇點數、送出後畫面顯示 π 與耗時。

---

## 交接給下一階段

Phase 2 執行前需具備：

- [app/Services/MonteCarloService.php](app/Services/MonteCarloService.php)
- [app/Models/Calculation.php](app/Models/Calculation.php) 及對應 migration 已執行
- [app/Http/Controllers/Api/CalculateController.php](app/Http/Controllers/Api/CalculateController.php)
- [app/Http/Requests/StoreCalculationRequest.php](app/Http/Requests/StoreCalculationRequest.php)
- 已註冊 `POST /api/calculate`、`GET /api/calculate/{id}`（或 `{uuid}`）
- 可運行的前端頁面（例如 [resources/js/pages/Calculate.vue](resources/js/pages/Calculate.vue)）

Queue / Redis 本階段尚未使用；Phase 4 才會引入分散式與 Queue。
