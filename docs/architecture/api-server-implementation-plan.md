# AIDataInsight `api-server` 后端计划

## Summary
新增独立后端项目 `api-server`，采用 `Python + FastAPI + SQLModel/SQLAlchemy`。v1 先用 SQLite 降低本地启动门槛，但按可迁移 PostgreSQL 的方式设计；先不接真实大模型，只跑通登录、聊天、历史、SSE 假流式回复等接口流程。后续可接 Ollama / vLLM / llama.cpp 这类本地模型服务。

## Key Changes
- 在仓库根目录新增 `api-server/`，作为多端共享 API 服务，不依附 Web 或某个客户端。
- 技术栈：
  - FastAPI：HTTP API、参数校验、自动 OpenAPI 文档。
  - SQLModel/SQLAlchemy：ORM、数据模型、后续迁移 PostgreSQL 的基础。
  - SQLite：v1 本地数据库，默认写入 `api-server/data/dev.db`。
  - Uvicorn：本地开发启动服务。
  - Pytest + HTTPX：接口测试。
- 默认监听 `http://127.0.0.1:3000`，对齐 `app-apple` 现有 local baseURL。
- 提供开发命令：
  - `python -m venv .venv`
  - `pip install -r requirements.txt`
  - `uvicorn app.main:app --host 127.0.0.1 --port 3000 --reload`
  - `pytest`

## API Behavior
- 全部 JSON 接口返回现有跨端 envelope：`code / msg / data / trace / tid`。
- 实现端点：
  - `POST /oauth2/login`
  - `GET /oauth2/refresh`
  - `GET /oauth2/logout`
  - `GET /oauth2/getUserInfo`
  - `GET /chat/template`
  - `GET /chat/function`
  - `GET /stream`
  - `GET /chart/{functionName}`
  - `GET /history/page`
  - `GET /history/detail`
  - `POST /history/like`
  - `GET /history/delete`
  - `GET /history/deleteAll`
- `/chat/function` 是 v1 核心流程：
  - 没有 `historyId` 时创建新历史会话。
  - 有 `historyId` 时追加到已有会话。
  - 保存用户问题和模拟助手结果。
  - 返回 `historyId`，让新对话自动进入历史。
- `/stream` 返回 SSE mock 分片，先不调用模型。
- 预留 `LLMProvider` 接口，v1 使用 `MockLLMProvider`，后续可接 `OllamaProvider`、`VLLMProvider` 或 OpenAI-compatible endpoint。

## Data Model
- `User`：内置 demo 用户。
- `SessionToken`：保存 access token、refresh token、用户、过期时间。
- `HistoryRecord`：历史会话主表，保存标题、创建/更新时间、用户信息。
- `HistoryDetail`：消息明细，保存用户消息、AI 文本、图表 JSON、点赞状态。
- 启动时自动创建本地表；v1 可内置 seed 数据，方便首次运行看到历史列表。

## Test Plan
- 单元/接口测试覆盖：
  - 登录成功返回 snake_case token 兼容字段。
  - refresh 返回新 access token。
  - 未带 token 的受保护接口返回业务错误。
  - 新问题创建历史会话。
  - 带 `historyId` 追加同一会话。
  - `/history/page` 能看到新会话。
  - `/history/detail` 能恢复消息明细。
  - 点赞、删除、清空历史能更新数据库。
  - `/stream` 返回合法 SSE 格式。
- 手动验收：
  - 启动 `api-server`。
  - Apple app 切到 local 环境。
  - 登录、发送新问题、打开历史、恢复详情、删除历史完整跑通。

## Assumptions
- v1 不做注册、多用户管理和复杂权限，只内置 demo 用户。
- v1 不部署服务器，只在本机运行。
- v1 不直接加载本地大模型，只预留模型 provider 边界。
- 后续接本地开源模型时，优先让 `api-server` 调用独立模型服务，而不是把推理模型直接塞进 API 进程。
