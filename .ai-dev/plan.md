# Pi-K3s 專案開發計畫

## 專案概述

**專案名稱**：Pi-K3s - 分散式圓周率計算展示平台

**核心目標**：透過蒙地卡羅演算法展示 Kubernetes 的自動擴展（HPA）、負載均衡、分散式計算。1C1G VPS 精簡版：HPA min=1 max=2（可調 3）、無 MySQL/Redis。

**展示價值**：證明 K8s 能根據計算負載自動調配資源，將計算時間從單 Pod 的 35 秒優化到多 Pod 的 15 秒以內

**部署策略**：直接部署到 VPS K3s 環境，線上可訪問展示

---

## 技術棧

### 後端
- **Laravel 12** (最新版本)
- **PHP 8.4+**
- **SQLite**（1C1G 優化；Session/Cache 用 file、Queue 用 database）

### 前端
- **Vue 3** (Composition API)
- **Vite** (Laravel 12 預設)
- **Tailwind CSS** (樣式)
- **Chart.js** 或 **Recharts** (圖表視覺化)
- **Canvas API** (蒙地卡羅投點動畫)

### 容器化與編排
- **Docker** (容器化)
- **K3s** (輕量級 Kubernetes，適合 1C1G VPS)
- **HPA** (Horizontal Pod Autoscaler - 自動擴展，1C1G min=1 max=2)
- **Metrics Server** (K3s 內建資源監控)

### 資料庫與 Queue
- **SQLite**（Pod 內檔案；1C1G 不需額外 MySQL/Redis）
- **Laravel Database Queue**（jobs 表；無需 Redis）

### 開發環境（本機）
- **WSL2** (Ubuntu) + **Docker Desktop**
- PHP、Composer、Node.js 於 WSL2 內使用；容器化與 K8s 於 Docker Desktop 內測試
- 無時程壓力，依里程碑逐步完成

### 正式部署環境
- **VPS**：1C1G (Ubuntu)，具對外 IP，可線上訪問
- **K3s**：輕量級 Kubernetes
- **Traefik**：K3s 內建 Ingress Controller

---

## 核心功能模組

### 1. 蒙地卡羅計算引擎
- 單 Pod 計算邏輯
- 分散式計算協調器
- 進度追蹤與結果彙總
- 計算任務佇列管理

### 2. Kubernetes 整合
- K8s API 客戶端（取得 Pod 狀態）
- HPA 配置與監控
- Metrics 收集（CPU、Memory、Pod 數量）
- 負載均衡測試

### 3. 前端視覺化介面
- **控制面板**
  - 投點數量選擇（10萬 / 100萬 / 1000萬）
  - 開始/停止/重置按鈕
  - 計算模式選擇（單 Pod / 分散式）

- **即時視覺化區域**
  - 蒙地卡羅圓形圖（Canvas 動畫）
  - 圓周率收斂曲線（Chart.js）
  - 當前計算值顯示

- **K8s 狀態監控**
  - Pod 數量即時顯示
  - CPU/Memory 使用率
  - 計算進度條
  - 總耗時與預估剩餘時間

- **效能對比儀表板**
  - 不同 Pod 數量的效能對比
  - 擴展事件時間軸
  - 歷史計算記錄

### 4. API 設計
```
POST   /api/calculate          # 提交計算任務
GET    /api/calculate/{id}     # 查詢計算進度
GET    /api/k8s/status         # K8s 叢集狀態
GET    /api/k8s/metrics        # 即時監控數據
GET    /api/history            # 歷史計算記錄
DELETE /api/calculate/{id}     # 取消計算任務
```

### 5. 即時通訊
- **Server-Sent Events (SSE)** 優先（與 Laravel 相容佳、實作簡單）
- 即時推送：計算進度、Pod 狀態、CPU 使用率
- 前端自動更新所有視覺化元件
- 若後續需更複雜雙向互動再考慮 WebSocket

---

## Kubernetes 架構設計

### 部署元件（1C1G 精簡版，無 MySQL/Redis）
```
pi-k3s/
├── Namespace: pi-k3s
├── Deployments
│   └── laravel-app (1-2 replicas，HPA 控制；內含 SQLite + database queue)
├── HPA
│   └── laravel-app (min=1, max=2，CPU > 60% 觸發擴展)
├── Services
│   └── laravel-service (ClusterIP)
├── Ingress
│   └── pi-k3s-ingress (Traefik，外部訪問)
├── ConfigMap
│   └── app-config (環境變數)
└── Secrets
    └── app-secrets (APP_KEY 等)
```

### 1C1G 部署重點
- **HPA**：min=1、max=2（可依實測調為 3）；CPU > 60% 觸發擴展
- **需啟用 metrics-server**（K3s 預設內建；若以 --disable=metrics-server 安裝則 HPA 無效）
- **計算點數限制**：最多 1000 萬點（避免過載）

---

## 展示場景設計

### 場景一：基礎計算（不觸發擴展）
- 選擇 10 萬點
- 1 個 Pod 處理
- 約 1-2 秒完成
- 展示基本功能

### 場景二：高負載自動擴展（核心展示）
- 選擇 1000 萬點
- CPU 使用率飆升 → HPA 自動擴展：1 → 2 pods
- 前端即時顯示擴展過程

### 場景三：分散式模式
- `mode=distributed` 時由 database queue 分 chunk 處理

---

## 開發階段規劃

依可行性檢視：優先產出「蒙地卡羅單機 + API + 簡單前端」，再容器化與 K8s，最後補 HPA、分散式與完整視覺化。各階段無固定時程，完成一階段再進下一階段。

### Phase 1：核心計算與 API（本機 WSL2 + Docker Desktop 可選）
- [ ] 開發環境準備：WSL2 內 PHP、Composer、Node.js（專案已為 Laravel 12 + Inertia/Vue，無需重建）
- [ ] 蒙地卡羅計算邏輯實作（`MonteCarloService`）
- [ ] 基礎 API：`POST /api/calculate`、`GET /api/calculate/{id}`
- [ ] 簡單前端能選擇點數、發起計算、顯示 π 結果
- [ ] 本地驗證：`php artisan serve` + `npm run dev`

### Phase 2：容器化與最小 K8s 部署
- [ ] Dockerfile（多階段構建）、.dockerignore
- [ ] 最小 K8s 清單：`namespace`、`deployment`、`service`、`ingress`，先能從外網訪問單一 Laravel Pod
- [ ] 本機以 Docker Desktop 內 K8s（或 minikube/k3d）驗證
- [ ] 補 `configmap`、`secrets`（1C1G 不部署 MySQL/Redis，僅 SQLite）

### Phase 3：正式環境部署（1C1G VPS）
- [ ] VPS：Ubuntu、對外 IP 可用
- [ ] 安裝 K3s：`curl -sfL https://get.k3s.io | sh -`
- [ ] 驗證：`kubectl get nodes`，部署 `k8s/`，確認 Pod 與 Ingress
- [ ] 在 1C1G 上觀察單一 Pod 的記憶體與 CPU，作為 HPA 參數依據

### Phase 4：HPA 與分散式計算
- [ ] HPA：min=1、max=2，CPU 閾值 60%；需啟用 metrics-server
- [ ] 分散式計算協調器：任務切子任務、Laravel Queue（database driver）、Worker 消費並回寫進度
- [ ] K8s API 整合：RBAC、取得 Pod 狀態與 HPA（GET /api/k8s/status、GET /api/k8s/metrics）

### Phase 5：前端視覺化與即時通訊
- [ ] Vue 3 元件：控制面板、蒙地卡羅 Canvas、圓周率收斂圖、K8s 狀態、效能對比
- [ ] Chart.js 圖表、SSE 即時推送（計算進度、Pod 狀態、CPU）
- [ ] RWD 響應式設計

### Phase 6：測試、文件與可選 AI
- [ ] 端到端與效能測試、README、架構圖、截圖/GIF、Git 提交與 GitHub
- [ ] （可選）Laravel AI SDK：說明型 Agent + `/api/ai/ask` 串流；視需求再加 Tool 或監控解讀

---

## 專案檔案結構

```
pi-k3s/
├── app/                        # Laravel 應用
│   ├── Http/Controllers/
│   │   ├── CalculateController.php
│   │   └── K8sStatusController.php
│   ├── Services/
│   │   ├── MonteCarloService.php
│   │   ├── DistributedCalculator.php
│   │   └── K8sClientService.php
│   ├── Jobs/
│   │   └── CalculatePiJob.php
│   └── Ai/                     # 可選：Laravel AI SDK
│       ├── Agents/
│       │   └── PiK3sExplainer.php
│       └── Tools/
│
├── resources/
│   ├── js/
│   │   ├── components/
│   │   │   ├── ControlPanel.vue
│   │   │   ├── MonteCarloCanvas.vue
│   │   │   ├── PiChart.vue
│   │   │   ├── K8sStatus.vue
│   │   │   └── PerformanceComparison.vue
│   │   └── app.js
│   └── views/
│       └── app.blade.php
│
├── docker/
│   ├── nginx.conf
│   └── supervisord.conf
│
├── k8s/
│   ├── namespace.yaml
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── ingress.yaml
│   ├── hpa.yaml
│   ├── configmap.yaml
│   └── secrets.yaml
│
├── docs/
│   ├── architecture.md
│   └── deployment-guide.md
│
├── Dockerfile
├── .dockerignore
├── .env.example
├── composer.json
├── package.json
└── README.md
```

---

## 技術重點與注意事項

### 可行性要點
- 技術棧與現有專案（Laravel 12 + Inertia/Vue）一致；K8s 整合可用 PHP Kubernetes Client 或 `kubectl`，需在叢集內配置 RBAC（ServiceAccount + Role）讓 Laravel Pod 讀取 HPA/Pod/Metrics。
- 分散式計算：Laravel 為協調者，任務切子任務後丟 Laravel Database Queue（jobs 表），多 Worker Pod 消費並回寫進度，由 Laravel 彙總結果。1C1G 不部署 Redis。
- 1C1G VPS：設好 Pod 資源 limits、HPA maxReplicas=2（可調 3）、計算點數上限。需啟用 metrics-server。

### K3s 特性
- 內建 Traefik Ingress Controller（不需額外安裝）
- 內建 Local Path Provisioner（自動處理 PVC）
- 內建 Metrics Server（HPA 必需，勿以 --disable=metrics-server 安裝）
- 輕量級設計（512MB RAM 即可運行）

### VPS 資源限制
- 1C1G 環境，需謹慎設定資源限制
- Pod 資源配置：
  ```yaml
  resources:
    requests:
      memory: "128Mi"
      cpu: "100m"
    limits:
      memory: "256Mi"
      cpu: "500m"
  ```
- HPA min=1、max=2（1C1G 可調 3）
- 計算點數限制在 1000 萬以內

### K8s 整合關鍵
- 使用 Kubernetes PHP Client 或直接 `kubectl` 指令
- 需要正確的 RBAC 權限配置
- ServiceAccount 綁定適當的 Role

### 效能優化
- 計算結果存 SQLite（或可選 file cache）
- Laravel Database Queue 處理長時間計算（1C1G 無 Redis）
- SSE 連接池管理
- 前端節流（Throttle）更新頻率

### 安全性
- API Rate Limiting
- CORS 配置
- Secrets 管理（不要硬編碼）
- 使用 K8s Secrets 儲存敏感資訊

---

## 展示與作品集呈現

### README 必備內容
1. **專案簡介**：一句話說明專案目的
2. **線上展示**：VPS 訪問網址
3. **技術架構圖**：視覺化展示系統架構
4. **核心特性**：列出 4-5 個亮點
   - K3s 輕量級部署
   - HPA 自動擴展
   - 分散式計算
   - 即時視覺化
5. **展示 GIF**：30 秒自動擴展過程
6. **快速部署**：K3s 部署指令
7. **效能數據**：實際測試結果對比
8. **技術細節**：HPA 配置、分散式計算邏輯

### 截圖與 GIF 重點
- **GIF 1**：完整的自動擴展過程（1 pod → 3 pods → 1 pod）
- **GIF 2**：蒙地卡羅投點動畫
- **截圖 1**：三合一儀表板（計算+K8s+效能）
- **截圖 2**：kubectl 顯示 HPA 擴展狀態

### 面試準備話題
- 為什麼選擇 K3s 而非完整 K8s？
- 1C1G VPS 如何優化資源配置？
- HPA 的擴展策略如何設計？
- 分散式計算的結果如何彙總？
- 如果要部署到雲端（AWS/GCP）需要調整什麼？
- K3s 與 K8s 的差異與選擇考量

---

## 成功指標

### 功能完整性
- [x] 蒙地卡羅計算正確無誤
- [x] HPA 能根據負載自動擴展
- [x] 前端即時顯示所有狀態
- [x] 分散式計算結果正確彙總
- [x] VPS 線上可訪問

### 視覺效果
- [x] 三個動態圖表流暢運行
- [x] Pod 擴展過程清晰可見
- [x] 效能提升數據明確展示

### 部署便利性
- [x] K3s 一鍵部署成功
- [x] README 步驟清晰可執行
- [x] 線上環境穩定運行

### 作品集價值
- [x] 展示 K8s 核心能力
- [x] 證明分散式系統理解
- [x] 視覺化呈現專業度
- [x] 技術深度足以面試討論
- [x] 展示資源優化能力（1C1G VPS）

---

## 開發工作流

### 本機開發（WSL2）
```bash
cd ~/projects/pi-k3s
php artisan serve --host=0.0.0.0 --port=8000

# 另一終端
npm run dev

# 訪問：http://localhost:8000
```

### 本機容器化測試（Docker Desktop）
```bash
docker build -t pi-k3s:test .
docker run -p 8080:80 pi-k3s:test
# 訪問：http://localhost:8080
```
亦可使用 Docker Desktop 內建 K8s 或 k3d/minikube 先驗證 K8s 清單。

### 正式部署（1C1G VPS，對外 IP）
```bash
# 方法 1：直接在 VPS 操作
ssh root@你的VPS_IP
git clone https://github.com/你的帳號/pi-k3s
cd pi-k3s
kubectl apply -f k8s/

# 方法 2：從 WSL 遠端操作
export KUBECONFIG=~/.kube/config-vps
kubectl apply -f k8s/
```

### 更新部署
```bash
# 1. 修改程式碼
# 2. Build 新 Image
docker build -t your-dockerhub/pi-k3s:v1.1 .
docker push your-dockerhub/pi-k3s:v1.1

# 3. 更新 K8s
kubectl set image deployment/laravel laravel=your-dockerhub/pi-k3s:v1.1 -n pi-k3s

# 4. 查看滾動更新狀態
kubectl rollout status deployment/laravel -n pi-k3s
```

---

## 備註

- **優先順序**：核心計算與 API → 容器化與最小 K8s → 正式 VPS 部署 → 分散式與 K8s API → 視覺化與 SSE → 測試、文件與可選 AI
- **VPS 限制**：1C1G 嚴控資源，HPA max=2（可調 3）、Pod requests/limits、計算點數上限須設好，避免 OOM
- **文件與 Git**：README 和架構圖與程式碼同等重要；各階段完成後提交，方便回溯

---

## Laravel AI SDK 整合方案（可選）

### 套件與環境

- **套件**：官方 [Laravel AI SDK](https://laravel.com/docs/12.x/ai-sdk)（`laravel/ai`），支援多種 Provider（OpenAI、Anthropic、Gemini、Ollama 等）、Agents、Tools、Structured Output、Streaming。
- **安裝**：
  ```bash
  composer require laravel/ai
  php artisan vendor:publish --provider="Laravel\Ai\AiServiceProvider"
  php artisan migrate
  ```
- **設定**：在 `config/ai.php` 或 `.env` 設定 `OPENAI_API_KEY`（或其它 Provider），並可選用 `RemembersConversations` 存對話到 DB。

### 在 Pi-K3s 中的整合情境

| 情境 | 說明 | 實作要點 |
|------|------|----------|
| **1. 說明型 Agent（教育/展示）** | 用自然語言回答「什麼是蒙地卡羅法？」、「K8s 如何部署？」 | 建立一個 `PiK3sExplainer` Agent，`instructions()` 寫入專案與 K8s 的簡短說明，可選 `RemembersConversations` 做多輪問答；用 `prompt()` 或 `stream()` 回傳。 |
| **2. 自然語言觸發計算** | 用戶輸入「用 100 萬點跑一次分散式」→ 解析意圖並呼叫既有 `POST /api/calculate` | Agent 使用 **Structured Output**（例如 `points`, `mode`）或 **Tools**：Tool 內呼叫 `MonteCarloService` 或 HTTP 觸發計算，回傳任務 ID 給前端。 |
| **3. 監控與建議** | 根據當前 K8s 狀態與歷史，用 AI 產出簡短說明或建議 | 在 `GET /api/k8s/status` 或獨立 `/api/insights` 中，把 Pod 數、CPU 等塞進 prompt，呼叫 Agent 回傳一段文字（或 Structured Output）；可放進 Queue 避免拖慢 API。 |
| **4. 對話式儀表板** | 儀表板旁加一個「問 Pi-K3s」輸入框，串接 Agent | 前端送訊息到 `POST /api/ai/chat`，後端用 Agent 的 `stream()` 回傳 SSE，前端用同一 SSE 或 Vercel AI SDK 協議消費；可搭配 `forUser($user)->prompt()` 做簡單多輪對話。 |

### 建議的整合順序

1. **先完成核心功能**：蒙地卡羅、K8s 狀態、前端視覺化與 SSE，再加 AI，避免範圍過大。
2. **第一階段 AI**：只做「說明型 Agent」+ 一個簡單 `POST /api/ai/ask`（或 `/api/ai/chat`），用 `stream()` 回傳 SSE，前端一個輸入框 + 串流顯示即可。
3. **第二階段**：視需求加 Tool（觸發計算、查歷史）或 Structured Output（解析「100 萬點 / 分散式」），並可選用 `RemembersConversations` 或自建 `Conversational` 存歷史。
4. **部署注意**：AI 呼叫為外部 API，需在 K8s/ConfigMap 或 Secret 中設定 `OPENAI_API_KEY` 等；若用 Queue 處理 AI，確保 Worker 能讀到相同 env。

### 與現有計畫的銜接

- **不影響既有 API**：AI 以額外路由（如 `/api/ai/*`）與 Agent/Tool 存在，`/api/calculate`、`/api/k8s/*` 保持原樣。
- **可共用 SSE**：若前端已接計算進度 SSE，可同一頁加「AI 說明」區塊，用另一條 SSE 串流 AI 回覆。
- **檔案結構建議**：Agent 放在 `app/Ai/Agents/`（如 `PiK3sExplainer`），Tool 放在 `app/Ai/Tools/`（如 `StartCalculation`、`GetK8sStatus`），與計畫中的 `app/Services/` 並存，Service 專注業務邏輯，Agent 專注與使用者的對話與意圖。

---

## 分階段開發文件

本計畫已拆成六個階段的獨立開發文件，供不同 AI 依序執行，每階段一份細部工作清單與驗收條件：

- **索引與指引**：[.ai-dev/phases/README.md](.ai-dev/phases/README.md) — 階段一覽、依賴關係、給執行 AI 的通用指引（必讀 plan.md、CLAUDE.md/AGENTS.md、測試與 Pint）。
- **階段文件**：[.ai-dev/phases/phase-1.md](.ai-dev/phases/phase-1.md) ～ [.ai-dev/phases/phase-6.md](.ai-dev/phases/phase-6.md)，依序為：核心計算與 API、容器化與最小 K8s、正式 VPS 部署、分散式計算與 K8s API、前端視覺化與 SSE、測試與文件與可選 AI。

執行時僅需讀取被指派的 `phase-N.md` 與本 plan.md 即可獨立完成該階段並與下一階段交接。

---

## 參考資源

- Laravel 12 文檔：https://laravel.com/docs/12.x
- Laravel AI SDK：https://laravel.com/docs/12.x/ai-sdk
- K3s 官方文檔：https://docs.k3s.io/
- Kubernetes 官方文檔：https://kubernetes.io/docs/
- Vue 3 文檔：https://vuejs.org/
- Chart.js：https://www.chartjs.org/
- Traefik 文檔：https://doc.traefik.io/traefik/

---

## 檢查清單

### 開發環境（本機）
- [ ] WSL2：PHP、Composer、Node.js 可用
- [ ] Docker Desktop 已安裝（容器化與 K8s 本機測試）
- [ ] 專案於本機可運行（`php artisan serve` + `npm run dev`）

### 正式部署環境
- [ ] 1C1G VPS (Ubuntu) 已準備，具對外 IP
- [ ] Docker Hub 帳號（推送 Image）
- [ ] （可選）GitHub 倉庫

### 階段里程碑
- [ ] Phase 1：蒙地卡羅 + API + 簡單前端可跑出 π
- [ ] Phase 2：Docker + 最小 K8s 清單可於本機或 VPS 跑通
- [ ] Phase 3：應用已部署至 VPS 並可從外網訪問
- [ ] Phase 4：分散式計算與 K8s API 驗證通過
- [ ] Phase 5：前端視覺化與 SSE 完成
- [ ] Phase 6：測試、README、架構圖、截圖/GIF、Git 整理完成
