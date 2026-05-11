# 系統架構

## 架構總覽

```mermaid
graph TB
    User([使用者<br/>Browser]) -->|HTTP/HTTPS| Ingress[Traefik Ingress<br/>or hostPort]

    subgraph K3s Cluster [K3s Cluster - 1C1G VPS]
        Ingress --> SVC[Service<br/>ClusterIP]
        SVC --> Web[laravel-app<br/>Web 1 replica<br/>Nginx + PHP-FPM]

        Web --> DB[(MariaDB<br/>shared data)]
        Web --> Redis[(Redis<br/>queue/cache/session/lock)]

        Redis --> Worker1[laravel-worker 1<br/>Queue Worker]
        Redis --> Worker2[laravel-worker 2<br/>Queue Worker]
        Worker1 --> DB
        Worker2 --> DB

        HPA[HPA<br/>CPU > 60%<br/>min=1, max=2] -->|scale| Worker1
        HPA -->|scale| Worker2
        MetricsServer[Metrics Server<br/>K3s 內建] -->|CPU/Memory| HPA
    end

    style User fill:#e0f2fe,stroke:#0284c7
    style HPA fill:#fef3c7,stroke:#d97706
    style MetricsServer fill:#fef3c7,stroke:#d97706
    style DB fill:#dbeafe,stroke:#3b82f6
    style Redis fill:#dcfce7,stroke:#16a34a
```

## 公開展示模式

Pi-K3s 目前定位為不需帳號的展示程式，使用者可直接從首頁進入 `/calculate` 操作。

- 展示入口：`/`、`/calculate`
- 首頁、頁首與側邊欄不顯示登入、註冊或 dashboard 入口
- `/calculate` 承載主要展示：single / distributed 計算、SSE 進度、K8s 狀態與 HPA 擴展觀察
- Fortify / auth 相關路徑保留於 Laravel starter kit 結構中，但不是公開 demo 的主要流程

## 蒙地卡羅演算法流程

蒙地卡羅法利用隨機採樣估算圓周率 π：

1. 在單位正方形 (0,0)-(1,1) 內隨機產生 N 個點
2. 計算落在四分之一圓（半徑 = 1，圓心在原點）內的點數 M
3. π ≈ 4 × M / N（因為四分之一圓面積 = π/4，正方形面積 = 1）

```mermaid
flowchart LR
    A[選擇點數 N] --> B{模式?}
    B -->|Single| C[單一程序計算<br/>N 個隨機點]
    B -->|Distributed| D[分割為 K 個 Chunk]
    D --> E1[Chunk 1<br/>Queue Job]
    D --> E2[Chunk 2<br/>Queue Job]
    D --> E3[Chunk K<br/>Queue Job]
    E1 --> F[彙總結果]
    E2 --> F
    E3 --> F
    C --> G[π = 4 × inside / total]
    F --> G
```

## 分散式計算協調

### Distributed 模式流程

1. **POST /api/calculate** (`mode=distributed`) 建立 `Calculation` 記錄
2. **DistributedCalculator** 將 total_points 切成多個 `CalculationChunk`
3. 每個 chunk 發派 `CalculatePiJob` 至設定的 Laravel queue（正式環境為 **Redis queue**）
4. **laravel-worker** Pod 消費 job，各自計算後回寫 chunk 結果
5. 最後一個 chunk 完成時，觸發彙總：加總 inside/total，計算最終 π
6. 前端透過 **SSE** (`GET /api/calculate/{id}/stream`) 輪詢 DB 取得即時進度

```mermaid
sequenceDiagram
    participant Browser
    participant Laravel
    participant Redis
    participant DB as MariaDB
    participant Worker as laravel-worker

    Browser->>Laravel: POST /api/calculate (distributed)
    Laravel->>DB: 建立 Calculation + Chunks
    Laravel->>Redis: 排入 CalculatePiJob × K
    Laravel-->>Browser: 202 Accepted

    Browser->>Laravel: GET /api/calculate/{id}/stream (SSE)

    loop 每個 Chunk
        Worker->>Redis: 取出 Job
        Worker->>Worker: 計算隨機點
        Worker->>DB: 更新 Chunk 結果
    end

    Note over Worker,DB: 最後一個 Chunk 完成時彙總

    Laravel-->>Browser: SSE event: {partial_pi, progress}
    Laravel-->>Browser: SSE event: {status: completed, result_pi}
```

## K8s 整合要點

### 部署元件

| 元件 | 用途 |
|------|------|
| Namespace `pi-k3s` | 隔離資源 |
| Deployment `laravel-app` | Web Pod（Nginx + PHP-FPM），固定 1 replica |
| Deployment `laravel-worker` | Queue Worker Pod，分散式計算的 HPA 擴縮目標 |
| Deployment `mariadb` | 正式環境共享資料庫 |
| Deployment `redis` | 同機輕量 Redis，供 queue/cache/session/lock 使用 |
| Service `laravel-service` | ClusterIP，指向 web pod |
| HPA | CPU > 60% 觸發 worker 擴展，min=1 max=2 |
| ServiceAccount + RBAC | 讓 Pod 內可查詢 K8s API（Pod 狀態、HPA） |
| ConfigMap / Secrets | 環境變數與敏感設定 |

### RBAC 設計

Pod 內的 `K8sClientService` 透過 ServiceAccount token 存取 K8s API：

- **Role**: 允許 `get`/`list` pods、pods/log、horizontalpodautoscalers（namespace 限定 `pi-k3s`）
- **ClusterRole**: 允許 `get`/`list` nodes、pods.metrics.k8s.io（跨 namespace metrics）

### 1C1G 限制與優化

- **web 固定 1 replica**：單節點 K3s 使用 hostPort 對外，避免 web pod port 衝突
- **worker 承接水平擴展**：HPA 只擴 `laravel-worker`，畫面可直接看到計算節點 1 → 2
- **MariaDB + Redis 共享狀態**：多 worker 共同讀寫計算結果、queue、cache lock
- **PHP-FPM static pool**：2 workers，避免動態 fork 的記憶體波動
- **OPcache 48MB**：預載 PHP bytecode，降低 CPU 使用
- **停用 Traefik**：正式 VPS 使用 hostPort 直接暴露，省約 100MB RAM

## API 端點

| 方法 | 路徑 | 說明 |
|------|------|------|
| POST | `/api/calculate` | 提交計算任務（single 返回 201，distributed 返回 202） |
| GET | `/api/calculate/{id}` | 查詢計算結果（支援 ID 或 UUID） |
| GET | `/api/calculate/{id}/stream` | SSE 即時進度串流 |
| GET | `/api/history` | 最近 30 筆已完成計算 |
| GET | `/api/k8s/status` | Pod 數量、HPA 狀態 |
| GET | `/api/k8s/metrics` | Pod CPU/Memory 指標 |
| POST | `/api/ai/ask` | AI 助手（SSE 串流，需 OPENAI_API_KEY） |
