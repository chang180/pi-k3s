# Pi-K3s

分散式圓周率計算展示平台：透過蒙地卡羅演算法展示 Kubernetes 的自動擴展（HPA）、負載均衡與分散式計算。

## 核心目標

- 以蒙地卡羅法估算 π，並在 K3s 上以多 Pod 分散計算
- 展示 HPA 依 CPU 負載自動擴縮（1 → 2 replicas，1C1G 可調為 3）
- 前端即時視覺化：投點動畫、圓周率收斂曲線、K8s 狀態與效能對比

## 技術棧

- **後端**：Laravel 12、PHP 8.4+、SQLite（輕量部署）
- **前端**：Vue 3、Inertia v2、Vite、Tailwind CSS v4、Chart.js、Canvas
- **部署**：Docker、K3s（輕量模式）、Let's Encrypt HTTPS（1C1G VPS 友善）

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

- **計算頁面**：http://localhost:8000/calculate — 可選擇點數（10 萬 / 100 萬 / 1000 萬）、模式（單機 single / 分散式 distributed），發起蒙地卡羅計算並顯示 π 與耗時。
- **K8s API**：`GET /api/k8s/status`（Pod 數、HPA 狀態）、`GET /api/k8s/metrics`（CPU/Memory 使用）

### 容器化測試（Docker）

```bash
docker build -t pi-k3s:test .
docker run -p 8080:80 pi-k3s:test
# 或使用 Docker Compose
docker compose up
```

訪問 http://localhost:8080（本地為 HTTP，容器會自動偵測 SSL 憑證）

### 本機 K3s + Ingress（http://pi-k3s.local）

透過 k3d 在本機建立 K3s 叢集與 Ingress，以 `http://pi-k3s.local` 存取（無需指定 port）：

```bash
# 1. 安裝 k3d（若尚未安裝）
curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash

# 2. 設定 hosts（需 sudo）
echo "127.0.0.1 pi-k3s.local" | sudo tee -a /etc/hosts

# 3. 執行本機 K3s 設定
./scripts/setup-local-k3s.sh
```

完成後訪問 **http://pi-k3s.local**

### VPS 部署（1C1G 優化）

正式環境部署在 VPS 主機上直接執行（登入 SSH 後 clone、建置、部署）。

#### 1. 複製範本並填入正式環境設定（於 VPS 上）

```bash
# K8s 環境設定（已從版控移除，需在 VPS 上手動建立）
cp k8s/secrets.yaml.example k8s/secrets.yaml       # 填入真正的 APP_KEY
cp k8s/configmap.yaml.example k8s/configmap.yaml   # 修改 APP_URL 為你的域名
cp k8s/deployment.yaml.example k8s/deployment.yaml # 啟用 HTTPS 則取消註解
```

#### 2. HTTPS 設定（Let's Encrypt，於 VPS 上）

```bash
# 在 VPS 上取得 SSL 憑證
sudo certbot certonly --standalone -d your-domain.example.com

# 在 k8s/deployment.yaml 中取消 HTTPS 相關的註解：
#   - hostPort 443
#   - letsencrypt volume mount
```

容器啟動時會自動偵測 `/etc/letsencrypt` 下的憑證，有則啟用 HTTPS + HTTP→HTTPS 跳轉。

#### 3. 部署（於 VPS 上執行）

```bash
# SSH 登入 VPS 後
git clone https://github.com/chang180/pi-k3s.git && cd pi-k3s
./scripts/deploy-on-vps.sh
```

腳本會：建置映像 → 匯入 K3s → 套用 manifests。詳見 [DEPLOY-NOW.md](DEPLOY-NOW.md)。

#### 優化細節

**K3s 輕量化**（省 ~200MB RAM）
- 停用 Traefik、servicelb；保留 metrics-server 供 HPA 使用
- 使用 `hostPort` 直接暴露服務，無需 ingress controller

**應用容器優化**
- PHP-FPM：static 模式、2 workers
- PHP `memory_limit`：64MB、OPcache：48MB
- Nginx：1 worker、256 connections
- 僅安裝 SQLite 擴充（移除 MySQL/PostgreSQL）

**系統優化**
- 自動建立 1GB swap（swappiness=10）
- 自動停用不必要的系統服務（multipathd、ModemManager、udisks2 等）

## 專案結構

```
├── app/                        # Laravel 應用程式碼
├── docker/
│   ├── nginx.conf              # Nginx 主配置（1 worker）
│   ├── default.conf            # Nginx server — HTTP only（本地開發）
│   ├── default-ssl.conf        # Nginx server — HTTPS + redirect（正式區）
│   ├── php-fpm-pool.conf       # PHP-FPM pool（2 workers, static）
│   ├── supervisord.conf        # Supervisor 程序管理
│   └── entrypoint.sh           # 容器啟動（自動偵測 SSL 憑證）
├── k8s/
│   ├── namespace.yaml          # K8s namespace
│   ├── secrets.yaml.example    # Secret 範本（APP_KEY）
│   ├── configmap.yaml.example  # ConfigMap 範本（APP_URL 等）
│   ├── deployment.yaml.example # Deployment 範本（含 HTTPS 註解）
│   ├── serviceaccount.yaml     # RBAC ServiceAccount
│   ├── role.yaml               # RBAC Role（pods、HPA）
│   ├── rolebinding.yaml        # RBAC RoleBinding
│   ├── ingressclass.yaml       # Traefik IngressClass（本機 k3d 用）
│   ├── hpa.yaml                # HPA（min=1, max=2，1C1G 可調）
│   ├── service.yaml            # ClusterIP service
│   └── ingress.yaml            # Traefik ingress
├── scripts/
│   ├── setup-local-k3s.sh      # 本機 k3d + Ingress 設定（http://pi-k3s.local）
│   ├── deploy-on-vps.sh        # VPS 端部署（正式環境主要入口）
│   └── deploy-vps.sh           # 本機→VPS 傳輸部署（保留，特殊情境用）
├── Dockerfile                  # 多階段建置（SQLite-only）
└── docker-compose.yml          # 本地開發用（HTTP）
```

> **注意**：`k8s/secrets.yaml`、`k8s/configmap.yaml`、`k8s/deployment.yaml` 包含環境特定設定（APP_KEY、域名、SSL），已從版控移除。部署時請從 `.example` 複製並填入實際值。

## 開發進度

| 階段 | 狀態 |
|------|------|
| Phase 1：核心計算與 API | 已完成 |
| Phase 2：容器化與 K8s | 已完成 |
| Phase 3：VPS 部署與 1C1G 優化 | 已完成 |
| Phase 4：HPA 與分散式計算 | 已完成 |
| Phase 5～6 | 待開發 |

## 專案計畫與分階段開發

- **完整計畫**：[.ai-dev/plan.md](.ai-dev/plan.md) — 技術棧、API 設計、K8s 架構、展示場景、開發工作流
- **分階段開發文件**：[.ai-dev/phases/README.md](.ai-dev/phases/README.md) — Phase 1～6 細部任務與驗收，供依序實作或由不同 AI 執行

## License

MIT
