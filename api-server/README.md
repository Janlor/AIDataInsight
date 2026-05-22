# AIDataInsight API Server

`api-server` 是 AIDataInsight 的本地开发后端。它为 Apple、iOS、Android、HarmonyOS NEXT 和 Web 的 `local` 环境提供统一接口，包括登录、会话、推荐问题、图表数据、历史列表和历史详情。

## 技术栈

- Python
- FastAPI
- SQLModel / SQLAlchemy
- SQLite 本地数据库
- Pytest + HTTPX 接口测试

## 快速启动

```sh
cd api-server
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --host 127.0.0.1 --port 3000 --reload
```

默认本地地址：

```text
http://127.0.0.1:3000
```

默认账号：

```text
name: demo
pwd: demo@123
```

接口文档：

```text
http://127.0.0.1:3000/docs
```

## 测试

```sh
cd api-server
pytest
```

## 本地数据

- 默认数据库文件是 `data/dev.db`，该文件不会提交到 git。
- 首次创建数据库时，会自动导入 `fixtures/apifox-mock` 中的历史数据。
- 5 个推荐问题和对应图表会优先读取 `fixtures/apifox-mock` 中的 function/chart JSON。
- 修改历史 fixture 后，如果想重新导入本地数据库，删除 `data/dev.db` 后重启服务即可。

## 后续接入大模型

当前版本使用 fixture-backed mock provider，不直接加载本地大模型。后续可以在 `app/llm.py` 中替换或新增 provider，调用 Ollama、vLLM、llama.cpp 或其它 OpenAI-compatible 本地模型服务。
