# AIDataInsight API Server

Local-first backend for AIDataInsight clients.

## Stack

- Python
- FastAPI
- SQLModel / SQLAlchemy
- SQLite for local development
- Pytest + HTTPX for API tests

## Quick Start

```sh
cd api-server
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --host 127.0.0.1 --port 3000 --reload
```

The default local API base URL is:

```text
http://127.0.0.1:3000
```

Demo login:

```text
name: demo
pwd: demo
```

Interactive API docs:

```text
http://127.0.0.1:3000/docs
```

## Tests

```sh
cd api-server
pytest
```

## Notes

- The database defaults to `data/dev.db`.
- The v1 LLM implementation is a mock provider. It is intentionally separated behind an `LLMProvider` protocol so future versions can call Ollama, vLLM, llama.cpp, or another OpenAI-compatible local model server.
