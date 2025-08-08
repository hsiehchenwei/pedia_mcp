#!/bin/bash

# Pedia MCP Docker Compose 部署腳本
# 使用方法: ./deploy.sh [dev|prod] [domain] [email]

set -e

# 預設值
MODE=${1:-dev}
DOMAIN=${2:-localhost}
EMAIL=${3:-admin@example.com}

echo "🚀 部署 Pedia MCP (模式: $MODE)"

# 檢查必要檔案
if [ ! -f ".env" ]; then
    echo "⚠️  .env 檔案不存在，建立範本..."
    cat > .env <<EOF
# 教育百科 API Key (必填)
PEDIA_API_KEY=your_api_key_here

# MCP 服務設定
MCP_TRANSPORT=http
MCP_HOST=0.0.0.0
MCP_PORT=8001
MCP_PATH=/mcp_pedia
PEDIA_CACHE_TTL_SECONDS=60

# 網域設定 (生產環境用)
DOMAIN=$DOMAIN
EMAIL=$EMAIL
EOF
    echo "📝 請編輯 .env 檔案，填入正確的 PEDIA_API_KEY"
    exit 1
fi

# 載入環境變數
source .env

if [ "$PEDIA_API_KEY" = "your_api_key_here" ] || [ -z "$PEDIA_API_KEY" ]; then
    echo "❌ 請在 .env 中設定正確的 PEDIA_API_KEY"
    exit 1
fi

# 停止現有服務
echo "🛑 停止現有服務..."
docker-compose down --remove-orphans || true

# 建立映像檔
echo "🔨 建立 Docker 映像檔..."
docker-compose build --no-cache

if [ "$MODE" = "prod" ]; then
    echo "🌐 生產模式部署..."
    
    # 檢查 SSL 憑證
    if [ ! -f "ssl/fullchain.pem" ] || [ ! -f "ssl/privkey.pem" ]; then
        echo "📜 SSL 憑證不存在，需要先取得憑證"
        echo "請執行以下步驟："
        echo "1. 確保網域 $DOMAIN 指向此伺服器"
        echo "2. 執行: sudo certbot certonly --standalone -d $DOMAIN -m $EMAIL --agree-tos"
        echo "3. 複製憑證到 ssl/ 目錄："
        echo "   sudo cp /etc/letsencrypt/live/$DOMAIN/fullchain.pem ssl/"
        echo "   sudo cp /etc/letsencrypt/live/$DOMAIN/privkey.pem ssl/"
        echo "   sudo chown \$(whoami):\$(whoami) ssl/*.pem"
        exit 1
    fi
    
    # 啟用 HTTPS 配置
    sed -i 's/^# server {/server {/' nginx/conf.d/pedia_mcp.conf
    sed -i 's/^#     /    /' nginx/conf.d/pedia_mcp.conf
    sed -i 's/^# }/}/' nginx/conf.d/pedia_mcp.conf
    sed -i "s/your.domain.com/$DOMAIN/g" nginx/conf.d/pedia_mcp.conf
else
    echo "🔧 開發模式部署..."
fi

# 啟動服務
echo "▶️  啟動服務..."
docker-compose up -d

# 等待服務啟動
echo "⏳ 等待服務啟動..."
sleep 10

# 檢查服務狀態
echo "🔍 檢查服務狀態..."
docker-compose ps

# 健康檢查
echo "🏥 健康檢查..."
if curl -f http://localhost/health >/dev/null 2>&1; then
    echo "✅ Nginx 健康檢查通過"
else
    echo "❌ Nginx 健康檢查失敗"
fi

if curl -f http://localhost/mcp_pedia/ >/dev/null 2>&1; then
    echo "✅ MCP 服務健康檢查通過"
else
    echo "❌ MCP 服務健康檢查失敗"
fi

echo "🎉 部署完成！"
echo ""
echo "📍 服務端點："
if [ "$MODE" = "prod" ]; then
    echo "   - HTTPS: https://$DOMAIN/mcp_pedia/"
    echo "   - SSE:   https://$DOMAIN/mcp_pedia/sse"
else
    echo "   - HTTP:  http://localhost/mcp_pedia/"
    echo "   - SSE:   http://localhost/mcp_pedia/sse"
fi
echo ""
echo "🔧 管理指令："
echo "   - 查看日誌: docker-compose logs -f"
echo "   - 停止服務: docker-compose down"
echo "   - 重啟服務: docker-compose restart"
echo "   - 更新服務: git pull && ./deploy.sh $MODE $DOMAIN $EMAIL"
