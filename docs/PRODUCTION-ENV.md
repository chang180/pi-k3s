# 正式環境設定說明

Pi-K3s 在本地開發與正式環境使用不同的基礎設施：

- 本地開發：SQLite 為主，可不啟用 Redis。
- 正式環境（K3s）：web + worker + MariaDB + Redis。

## 重要觀念

正式環境 **不是直接讀取 repo 內的 `.env` 檔**。  
K3s 部署使用：

- `k8s/configmap.yaml`
- `k8s/secrets.yaml`

來注入環境變數。

如果你平常先把值寫在 VPS 上的 `.env`，部署前需要手動同步到 K8s manifests。

## 本地開發建議

建議維持下列設定：

```env
DB_CONNECTION=sqlite
QUEUE_CONNECTION=database
CACHE_STORE=database
SESSION_DRIVER=database
```

如需本地測 Redis，可自行改成：

```env
QUEUE_CONNECTION=redis
CACHE_STORE=redis
SESSION_DRIVER=redis
REDIS_HOST=127.0.0.1
REDIS_PORT=6379
REDIS_PASSWORD=null
```

## 正式環境建議

`k8s/configmap.yaml`：

```yaml
DB_CONNECTION: "mysql"
DB_HOST: "mariadb"
DB_PORT: "3306"
DB_DATABASE: "pi_k3s"
DB_USERNAME: "pi_k3s"
CACHE_STORE: "redis"
QUEUE_CONNECTION: "redis"
SESSION_DRIVER: "redis"
REDIS_CLIENT: "phpredis"
REDIS_HOST: "your-redis-host"
REDIS_PORT: "6379"
```

`k8s/secrets.yaml`：

```yaml
APP_KEY: <base64>
DB_PASSWORD: <base64>
MARIADB_ROOT_PASSWORD: <base64>
REDIS_PASSWORD: <base64>
```

## K3s 拓樸

- `laravel-app`：web 單副本，保留 `hostPort` 對外。
- `laravel-worker`：背景計算 worker，可由 HPA 擴縮。
- `mariadb`：單副本共享資料庫。

這樣做的原因是 K3s 單節點下，web 若直接擴副本會被 `hostPort` 卡住；把可擴展能力放在 worker 比較符合目前正式環境。
