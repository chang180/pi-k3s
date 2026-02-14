# Pi-K3s

分散式圓周率計算展示平台：透過蒙地卡羅演算法展示 Kubernetes 的自動擴展（HPA）、負載均衡與分散式計算。

## 核心目標

- 以蒙地卡羅法估算 π，並在 K3s 上以多 Pod 分散計算
- 展示 HPA 依 CPU 負載自動擴縮（1 → 3 replicas）
- 前端即時視覺化：投點動畫、圓周率收斂曲線、K8s 狀態與效能對比

## 技術棧

- **後端**：Laravel 12、PHP 8.4+、Redis（Queue / 快取）
- **前端**：Vue 3、Inertia、Vite、Tailwind CSS、Chart.js、Canvas
- **部署**：Docker、K3s、Traefik、HPA（1C1G VPS 友善）

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
# 或執行測試腳本
bash docker/test.sh
```

訪問 http://localhost:8080、http://localhost:8080/api/calculate

### 本機 K8s（pi-k3s.local）

```bash
kubectl apply -f k8s/
```

在 /etc/hosts 加入 `127.0.0.1 pi-k3s.local`，訪問 http://pi-k3s.local。詳細步驟見 [k8s/SETUP.md](k8s/SETUP.md)。

### VPS 正式部署（1C1G）

```bash
./scripts/deploy-vps.sh
```

自動化腳本會建置 image、傳輸至 VPS、安裝 K3s、部署應用。資源監控：`./scripts/monitor-resources.sh`。完整說明見 [docs/VPS-DEPLOYMENT.md](docs/VPS-DEPLOYMENT.md)。

## 開發進度

| 階段 | 狀態 |
|------|------|
| Phase 1：核心計算與 API | 已完成 |
| Phase 2：容器化與 K8s | 已完成 |
| Phase 3：VPS 部署腳本與文件 | 已完成 |
| Phase 4～6 | 待開發 |

## 專案計畫與分階段開發

- **完整計畫**：[.ai-dev/plan.md](.ai-dev/plan.md) — 技術棧、API 設計、K8s 架構、展示場景、開發工作流
- **分階段開發文件**：[.ai-dev/phases/README.md](.ai-dev/phases/README.md) — Phase 1～6 細部任務與驗收，供依序實作或由不同 AI 執行

## License

MIT
