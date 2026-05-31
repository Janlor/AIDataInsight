from typing import Any, Dict, Optional
from uuid import uuid4


def envelope(
    data: Any = None,
    code: int = 200,
    msg: str = "ok",
    trace: Optional[str] = None,
    tid: Optional[str] = None,
) -> Dict[str, Any]:
    """构造统一响应信封，字段名和 Apple 客户端契约保持一致。"""

    return {
        "code": code,
        "msg": msg,
        "data": data,
        "trace": trace,
        "tid": tid or str(uuid4()),
    }


def empty() -> Dict[str, Any]:
    """无业务数据接口的统一成功响应。"""

    return envelope(None)
