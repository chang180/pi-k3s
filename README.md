# Pi-K3s

分散式圓周率計算展示平台：透過蒙地卡羅演算法展示 Kubernetes 的自動擴展（HPA）、負載均衡與分散式計算。

## 核心目標

- 以蒙地卡羅法估算 π，並在 K3s 上以多 Pod 分散計算
- 展示 HPA 依 CPU 負載自動擴縮（1 → 3 replicas）
- 前端即時視覺化：投點動畫、圓周率收斂曲線、K8s 狀態與效能對比

## 技術棧

- **後端**：Laravel 12、PHP 8.4+、SQLite（輕量部署）
- **前端**：Vue 3、Inertia v2、Vite、Tailwind CSS v4、Chart.js、Canvas
- **部署**：Docker、K3s（輕量模式）、hostPort 直連（1C1G VPS 友善）

## 本地開發

```bash
# 安裝依賴
composer install
cp .env.example .env
php artisan key:generate
php artisan migrate

npm install

# 啟動
php artisan serve --host=0.0.0.0 --port=8000
# 另一終端
npm run dev
```

瀏覽 http://localhost:8000

- **計算頁面**：http://localhost:8000/calculate — 可選擇點數（10 萬 / 100 萬 / 1000 萬）、發起蒙地卡羅計算並顯示 π 與耗時。

### 容器化測試（Docker）

```bash
docker build -t pi-k3s:test .
docker run -p 8080:80 pi-k3s:test
# 或使用 Docker Compose
docker compose up
```

訪問 http://localhost:8080

### VPS 部署（1C1G 優化）

本專案已針對 1 核 1GB RAM 的 VPS 做了全面優化：

**K3s 輕量化**
- 停用 Traefik、metrics-server、servicelb（省 ~200MB RAM）
- 使用 `hostPort: 80` 直接暴露服務，無需 ingress controller
- API server 並行請求數限制，降低記憶體開銷

**應用容器優化**
- PHP-FPM：static 模式、2 workers
- PHP `memory_limit`：64MB、OPcache：48MB
- Nginx：1 worker、256 connections
- 僅安裝 SQLite 擴充（移除 MySQL/PostgreSQL）

**系統優化**
- 自動建立 1GB swap（swappiness=10）
- 自動停用不必要的系統服務（multipathd、ModemManager、udisks2 等）

```bash
# 從本地機器執行（需要 Docker 和 SSH 存取 VPS）
./scripts/deploy-vps.sh
```

自動化腳本會：建置映像 → 傳輸至 VPS → 安裝輕量 K3s → 匯入映像 → 部署應用。

## 專案結構

```
├── app/                    # Laravel 應用程式碼
├── docker/                 # Docker 配置
│   ├── nginx.conf          # Nginx 主配置（1 worker）
│   ├── default.conf        # Nginx server 配置
│   ├── php-fpm-pool.conf   # PHP-FPM pool（2 workers, static）
│   ├── supervisord.conf    # Supervisor 程序管理
│   └── entrypoint.sh       # 容器啟動腳本
├── k8s/                    # Kubernetes manifests
│   ├── namespace.yaml
│   ├── configmap.yaml
│   ├── secrets.yaml
│   ├── deployment.yaml     # hostPort: 80, 低資源限制
│   ├── service.yaml
│   └── ingress.yaml        # Traefik 用（預設停用）
├── scripts/
│   ├── deploy-vps.sh       # VPS 自動部署腳本
│   └── deploy-on-vps.sh    # 部署入口
├── Dockerfile              # 多階段建置（SQLite-only）
└── docker-compose.yml      # 本地開發用
```

## 開發進度

| 階段 | 狀態 |
|------|------|
| Phase 1：核心計算與 API | 已完成 |
| Phase 2：容器化與 K8s | 已完成 |
| Phase 3：VPS 部署與 1C1G 優化 | 已完成 |
| Phase 4～6 | 待開發 |

## 專案計畫與分階段開發

- **完整計畫**：[.ai-dev/plan.md](.ai-dev/plan.md) — 技術棧、API 設計、K8s 架構、展示場景、開發工作流
- **分階段開發文件**：[.ai-dev/phases/README.md](.ai-dev/phases/README.md) — Phase 1～6 細部任務與驗收，供依序實作或由不同 AI 執行

## License

MIT
