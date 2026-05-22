from typing import Optional
from pydantic import BaseModel


class LoginRequest(BaseModel):
    name: str
    pwd: str


class UpdatePasswordRequest(BaseModel):
    oldPwd: str
    newPwd: str


class LikeHistoryDetailRequest(BaseModel):
    historyDetailId: int
    like: str


class FunctionAnalysisResult(BaseModel):
    historyId: int
    hasTool: bool
    name: Optional[str] = None
    msg: Optional[str] = None
    arguments: Optional[dict] = None
