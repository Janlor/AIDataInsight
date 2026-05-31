from typing import Optional
from pydantic import BaseModel


class LoginRequest(BaseModel):
    """登录请求体，字段名兼容现有前端表单契约。"""

    name: str
    pwd: str


class UpdatePasswordRequest(BaseModel):
    """修改密码请求体。"""

    oldPwd: str
    newPwd: str


class LikeHistoryDetailRequest(BaseModel):
    """历史明细点赞/点踩请求体。"""

    historyDetailId: int
    like: str


class FunctionAnalysisResult(BaseModel):
    """聊天函数识别结果模型，保留给接口契约和测试复用。"""

    historyId: int
    hasTool: bool
    name: Optional[str] = None
    msg: Optional[str] = None
    arguments: Optional[dict] = None
