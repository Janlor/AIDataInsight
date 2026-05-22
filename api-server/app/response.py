from typing import Any, Dict, Optional
from uuid import uuid4


def envelope(
    data: Any = None,
    code: int = 200,
    msg: str = "ok",
    trace: Optional[str] = None,
    tid: Optional[str] = None,
) -> Dict[str, Any]:
    return {
        "code": code,
        "msg": msg,
        "data": data,
        "trace": trace,
        "tid": tid or str(uuid4()),
    }


def empty() -> Dict[str, Any]:
    return envelope(None)
