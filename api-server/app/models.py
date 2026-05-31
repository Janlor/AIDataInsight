from datetime import datetime
from typing import Optional
from sqlmodel import Field, SQLModel


class User(SQLModel, table=True):
    """本地演示用户表。"""

    id: Optional[int] = Field(default=None, primary_key=True)
    username: str = Field(index=True, unique=True)
    password: str
    nickname: Optional[str] = None
    phone: Optional[str] = None
    org_id: int = 1
    created_at: datetime = Field(default_factory=datetime.utcnow)


class SessionToken(SQLModel, table=True):
    """访问令牌和刷新令牌表，支持过期判断和主动撤销。"""

    id: Optional[int] = Field(default=None, primary_key=True)
    user_id: int = Field(foreign_key="user.id", index=True)
    access_token: str = Field(index=True, unique=True)
    refresh_token: str = Field(index=True, unique=True)
    access_expires_at: datetime
    refresh_expires_at: datetime
    revoked_at: Optional[datetime] = None
    created_at: datetime = Field(default_factory=datetime.utcnow)


class HistoryRecord(SQLModel, table=True):
    """一次聊天会话记录，deleted_at 用于软删除。"""

    id: Optional[int] = Field(default=None, primary_key=True)
    name: str
    create_id: int = Field(foreign_key="user.id", index=True)
    update_id: int = Field(foreign_key="user.id")
    create_name: str
    update_name: str
    create_time: datetime = Field(default_factory=datetime.utcnow, index=True)
    update_time: datetime = Field(default_factory=datetime.utcnow, index=True)
    deleted_at: Optional[datetime] = Field(default=None, index=True)


class HistoryDetail(SQLModel, table=True):
    """会话中的单条明细，type/content_type 沿用前端和 Apifox 契约枚举。"""

    id: Optional[int] = Field(default=None, primary_key=True)
    history_id: int = Field(foreign_key="historyrecord.id", index=True)
    type: str
    content_type: str
    content: str
    is_like: Optional[str] = None
    create_time: datetime = Field(default_factory=datetime.utcnow, index=True)
    update_time: datetime = Field(default_factory=datetime.utcnow)
