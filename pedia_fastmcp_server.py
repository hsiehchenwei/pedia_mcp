from __future__ import annotations

"""
fastmcp 版 Pedia MCP 伺服器（單檔、可直接移出至獨立專案）

- 依賴：fastmcp、python-dotenv
- 工具：
  - pedia_list(keyword: str, page: int=1) -> dict
  - pedia_detail(term: str) -> dict
- 對外：可用 HTTP/SSE/STDIO 三種 transport，預設 HTTP。

環境變數：
- PEDIA_API_KEY：教育百科 API Key（必要）
- MCP_TRANSPORT：http|sse|stdio（預設 http）
- MCP_HOST：預設 127.0.0.1
- MCP_PORT：預設 8001
- MCP_PATH：預設 /mcp_pedia（僅 http 模式）
"""

import json
import os
import time
from typing import Any, Dict, Tuple
from urllib.parse import quote
from urllib.request import Request, urlopen

from fastmcp import FastMCP
from dotenv import load_dotenv


BASE_URL_LIST = "https://pedia.cloud.edu.tw/api/v2/List"
BASE_URL_DETAIL = "https://pedia.cloud.edu.tw/api/v2/Detail"


def _build_list_url(keyword: str, page: int, api_key: str) -> str:
    encoded_keyword = quote(keyword, safe="")
    return f"{BASE_URL_LIST}?keyword={encoded_keyword}&page={page}&api_key={api_key}"


def _build_detail_url(term: str, api_key: str) -> str:
    encoded_term = quote(term, safe="")
    return f"{BASE_URL_DETAIL}?term={encoded_term}&api_key={api_key}"


def _http_get_json(url: str, timeout_seconds: int = 20) -> Any:
    request = Request(
        url,
        headers={
            "Accept": "application/json",
            "User-Agent": "pedia-fastmcp/1.0 (+https://github.com/)",
        },
    )
    with urlopen(request, timeout=timeout_seconds) as resp:
        data = resp.read()
    try:
        return json.loads(data)
    except json.JSONDecodeError:
        return {"raw": data.decode("utf-8", errors="replace")}


_CACHE: Dict[str, Tuple[float, Any]] = {}
_CACHE_TTL_SECONDS = int(os.getenv("PEDIA_CACHE_TTL_SECONDS", "60"))


def _get_with_cache(url: str) -> Any:
    now = time.time()
    hit = _CACHE.get(url)
    if hit and now - hit[0] <= _CACHE_TTL_SECONDS:
        return hit[1]

    last_exc: Exception | None = None
    for attempt in range(3):
        try:
            result = _http_get_json(url)
            _CACHE[url] = (now, result)
            return result
        except Exception as exc:
            last_exc = exc
            time.sleep(0.4 * (attempt + 1))
    raise RuntimeError(f"Upstream fetch error: {last_exc}")


mcp = FastMCP("Pedia MCP")

load_dotenv()  # 讀取專案根目錄的 .env

@mcp.tool
def pedia_list(keyword: str, page: int = 1) -> dict:
    """教育百科 List 查詢。"""
    if not keyword:
        return {"error": {"code": "INVALID_PARAM", "message": "keyword is required"}}
    api_key = os.getenv("PEDIA_API_KEY")
    if not api_key:
        return {"error": {"code": "MISSING_API_KEY", "message": "PEDIA_API_KEY is required"}}
    url = _build_list_url(keyword=keyword, page=int(page), api_key=api_key)
    data = _get_with_cache(url)
    return {"ok": True, "data": data}


@mcp.tool
def pedia_detail(term: str) -> dict:
    """教育百科 Detail 查詢。"""
    if not term:
        return {"error": {"code": "INVALID_PARAM", "message": "term is required"}}
    api_key = os.getenv("PEDIA_API_KEY")
    if not api_key:
        return {"error": {"code": "MISSING_API_KEY", "message": "PEDIA_API_KEY is required"}}
    url = _build_detail_url(term=term, api_key=api_key)
    data = _get_with_cache(url)
    return {"ok": True, "data": data}


if __name__ == "__main__":
    transport = os.getenv("MCP_TRANSPORT", "http").lower()
    host = os.getenv("MCP_HOST", "127.0.0.1")
    port = int(os.getenv("MCP_PORT", "8001"))
    path = os.getenv("MCP_PATH", "/mcp_pedia")

    if transport == "http":
        # 推薦用於 Remote MCP 對接（會自動提供 /sse 與 POST 端點）
        mcp.run(transport="http", host=host, port=port, path=path)
    elif transport == "sse":
        # 僅 SSE 模式（部分客戶端使用）
        mcp.run(transport="sse", host=host, port=port)
    else:
        # 預設 STDIO（本地工具/命令列）
        mcp.run(transport="stdio")


