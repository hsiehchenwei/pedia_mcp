FROM python:3.11-slim

LABEL maintainer="hsiehchenwei"
LABEL description="Pedia MCP FastMCP Server"

WORKDIR /app

# 安裝系統依賴
RUN apt-get update && apt-get install -y \
    curl \
    && rm -rf /var/lib/apt/lists/*

# 複製需求檔案並安裝 Python 依賴
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# 複製應用程式碼
COPY pedia_fastmcp_server.py .

# 建立非 root 使用者
RUN useradd -m -s /bin/bash appuser && \
    chown -R appuser:appuser /app
USER appuser

# 暴露埠號
EXPOSE 8001

# 健康檢查
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8001/mcp_pedia/ || exit 1

# 啟動命令
CMD ["python", "pedia_fastmcp_server.py"]
