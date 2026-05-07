# Progress: Pi-K3s 專案改進

## Status

- **目前 phase**：Phase 2 待開始
- **已完成 phase**：Phase 1
- **上次 commit**：（將於本 phase 結束建立）

## Completed

- ✅ Laravel 13 升級（前置任務，已 push）
- ✅ Phase 1: 基礎清理

## Phase 1: 基礎清理（已完成）

- [x] `.env` `APP_URL` 改為 `https://pi-k3s.test`（用戶已自行更新）
- [x] [README.md](README.md) 技術棧 L12 → L13
- [x] [README.md](README.md) 本地開發補充 Herd 提示
- [x] [README.md](README.md) 開發進度表加 L13 + 後續改進
- [x] `php artisan test --compact`：83 passed
- [x] `vendor/bin/pint --dirty --format agent`：passed
- [x] `curl https://pi-k3s.test/`：200
- [x] commit

## Phase 2: UI 中文化（待開始）

## Phase 3: 首頁重設計（待開始）

## Phase 4: /calculate UI 重整（待開始）

## Phase 5: K8s 狀態強化（待開始）

## Phase 6: 部署文件強化（待開始）

---

## Deviations

- Phase 1 原訂自己改 `.env` `APP_URL`，但用戶已先行修改，跳過。

## Issues

None

## Files Changed

### Phase 1
- [README.md](README.md) — 技術棧 L13、Herd 提示、進度表更新
- [plan.md](plan.md) — 多 phase 改進計畫（覆寫前一版 L13 升級用的）
- [progress.md](progress.md) — phase 進度追蹤

## Verification

### Phase 1
- `php artisan test --compact`：83 passed (305 assertions)
- `vendor/bin/pint --dirty --format agent`：passed
- `curl -sk https://pi-k3s.test/`：HTTP 200

## Next Steps

Phase 2：UI 中文化。先建 `lang/zh_TW/`，調整 `APP_LOCALE`，再批次翻譯各 Vue 元件。
