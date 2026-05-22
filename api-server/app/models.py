from datetime import datetime
from typing import Optional
from sqlmodel import Field, SQLModel


class User(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    username: str = Field(index=True, unique=True)
    password: str
    nickname: Optional[str] = None
    phone: Optional[str] = None
    org_id: int = 1
    created_at: datetime = Field(default_factory=datetime.utcnow)


class SessionToken(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    user_id: int = Field(foreign_key="user.id", index=True)
    access_token: str = Field(index=True, unique=True)
    refresh_token: str = Field(index=True, unique=True)
    access_expires_at: datetime
    refresh_expires_at: datetime
    revoked_at: Optional[datetime] = None
    created_at: datetime = Field(default_factory=datetime.utcnow)


class HistoryRecord(SQLModel, table=True):
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
    id: Optional[int] = Field(default=None, primary_key=True)
    history_id: int = Field(foreign_key="historyrecord.id", index=True)
    type: str
    content_type: str
    content: str
    is_like: Optional[str] = None
    create_time: datetime = Field(default_factory=datetime.utcnow, index=True)
    update_time: datetime = Field(default_factory=datetime.utcnow)
