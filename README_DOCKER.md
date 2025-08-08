# Pedia MCP Docker Compose 部署指南

## 專案結構

```
pedia_mcp/
├── Dockerfile                 # 主應用程式容器定義
├── docker-compose.yml         # Docker Compose 配置
├── requirements.txt           # Python 依賴
├── deploy.sh                  # 自動部署腳本
├── .env                       # 環境變數配置
├── .dockerignore             # Docker 忽略檔案
├── pedia_fastmcp_server.py   # 主程式
├── nginx/                    # Nginx 配置
│   ├── nginx.conf           # 主配置檔
│   └── conf.d/
│       └── pedia_mcp.conf   # 站台配置
└── ssl/                      # SSL 憑證目錄
```

## 快速開始

### 1. 環境設定

```bash
# 複製並編輯環境變數
cp .env.example .env
# 編輯 .env，填入你的 PEDIA_API_KEY
```

### 2. 開發模式部署

```bash
# 自動部署（開發模式）
./deploy.sh dev

# 或手動執行
docker-compose up -d
```

### 3. 生產模式部署

```bash
# 設定網域和 email
./deploy.sh prod your.domain.com you@example.com
```

## 服務端點

- **開發模式**: http://localhost/mcp_pedia/
- **生產模式**: https://your.domain.com/mcp_pedia/
- **SSE 端點**: `/mcp_pedia/sse`
- **健康檢查**: `/health`

## 管理指令

### 基本操作

```bash
# 啟動服務
docker-compose up -d

# 停止服務
docker-compose down

# 重啟服務
docker-compose restart

# 查看狀態
docker-compose ps
```

### 日誌查看

```bash
# 查看所有服務日誌
docker-compose logs -f

# 查看特定服務日誌
docker-compose logs -f pedia-mcp
docker-compose logs -f nginx
```

### 更新部署

```bash
# 拉取最新代碼並重新部署
git pull
./deploy.sh [dev|prod] [domain] [email]
```

## 環境變數說明

| 變數名                    | 說明              | 預設值       |
| ------------------------- | ----------------- | ------------ |
| `PEDIA_API_KEY`           | 教育百科 API 金鑰 | 必填         |
| `MCP_TRANSPORT`           | 傳輸協定          | `http`       |
| `MCP_HOST`                | 綁定位址          | `0.0.0.0`    |
| `MCP_PORT`                | 服務埠號          | `8001`       |
| `MCP_PATH`                | 服務路徑          | `/mcp_pedia` |
| `PEDIA_CACHE_TTL_SECONDS` | 快取時間          | `60`         |

## SSL/HTTPS 設定

### 自動取得 Let's Encrypt 憑證

```bash
# 1. 確保網域指向伺服器
# 2. 停止現有的 nginx 服務
docker-compose stop nginx

# 3. 取得憑證
sudo certbot certonly --standalone -d your.domain.com -m you@example.com --agree-tos

# 4. 複製憑證
sudo cp /etc/letsencrypt/live/your.domain.com/fullchain.pem ssl/
sudo cp /etc/letsencrypt/live/your.domain.com/privkey.pem ssl/
sudo chown $(whoami):$(whoami) ssl/*.pem

# 5. 啟用 HTTPS 並重啟
./deploy.sh prod your.domain.com you@example.com
```

### 憑證更新

```bash
# 設定自動更新 cron job
echo "0 3 * * * certbot renew --quiet && docker-compose restart nginx" | sudo crontab -
```

## 故障排除

### 常見問題

1. **容器無法啟動**

   ```bash
   docker-compose logs pedia-mcp
   ```

2. **Nginx 502 錯誤**

   ```bash
   # 檢查後端服務
   docker-compose exec pedia-mcp curl http://localhost:8001/mcp_pedia/
   ```

3. **SSL 憑證問題**
   ```bash
   # 檢查憑證檔案
   ls -la ssl/
   openssl x509 -in ssl/fullchain.pem -text -noout
   ```

### 重置部署

```bash
# 完全重置（會刪除所有容器和映像檔）
docker-compose down --rmi all --volumes --remove-orphans
./deploy.sh [dev|prod]
```

## 效能調校

### 生產環境建議

1. **調整 worker 數量**

   - 編輯 `nginx/nginx.conf`
   - 設定 `worker_processes` 為 CPU 核心數

2. **啟用快取**

   - 可在 nginx 配置中加入適當的快取設定

3. **監控設定**
   - 考慮加入 Prometheus + Grafana 監控

## 開發指南

### 本機開發

```bash
# 只啟動後端服務（不含 nginx）
docker-compose up pedia-mcp

# 直接存取服務
curl http://localhost:8001/mcp_pedia/
```

### 重建映像檔

```bash
# 重建並啟動
docker-compose up --build -d

# 清除快取重建
docker-compose build --no-cache
```
