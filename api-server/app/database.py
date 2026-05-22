from datetime import datetime
from pathlib import Path
from typing import Generator, Optional

from sqlmodel import Session, SQLModel, create_engine, select

from .config import get_settings
from .models import HistoryDetail, HistoryRecord, User


_engine = None
_database_url_override: Optional[str] = None


def get_engine():
    global _engine
    if _engine is None:
        settings = get_settings()
        database_url = _database_url_override or settings.database_url
        if database_url.startswith("sqlite:///"):
            db_path = Path(database_url.replace("sqlite:///", "", 1))
            db_path.parent.mkdir(parents=True, exist_ok=True)
        connect_args = {"check_same_thread": False} if database_url.startswith("sqlite") else {}
        _engine = create_engine(database_url, connect_args=connect_args)
    return _engine


def reset_engine_for_tests(database_url: str) -> None:
    global _engine, _database_url_override
    _database_url_override = database_url
    _engine = None


def create_db_and_tables() -> None:
    SQLModel.metadata.create_all(get_engine())


def get_session() -> Generator[Session, None, None]:
    with Session(get_engine()) as session:
        yield session


def seed_development_data(session: Session) -> None:
    user = session.exec(select(User).where(User.username == "demo")).first()
    if user is None:
        user = User(username="demo", password="demo", nickname="Demo User", phone=None, org_id=1)
        session.add(user)
        session.commit()
        session.refresh(user)

    history_count = len(session.exec(select(HistoryRecord)).all())
    if history_count > 0:
        return

    now = datetime.utcnow()
    greeting = HistoryRecord(
        id=456,
        name="你好",
        create_id=user.id or 1,
        update_id=user.id or 1,
        create_name=user.username,
        update_name=user.username,
        create_time=now,
        update_time=now,
    )
    sales = HistoryRecord(
        id=123,
        name="查看一月销售额",
        create_id=user.id or 1,
        update_id=user.id or 1,
        create_name=user.username,
        update_name=user.username,
        create_time=now,
        update_time=now,
    )
    session.add(greeting)
    session.add(sales)
    session.commit()

    details = [
        HistoryDetail(
            id=2001,
            history_id=456,
            type="1",
            content_type="1",
            content="你好",
            create_time=now,
            update_time=now,
        ),
        HistoryDetail(
            id=2002,
            history_id=456,
            type="2",
            content_type="1",
            content='{"historyId":456,"hasTool":false,"name":null,"msg":"你好，我可以帮你分析经营数据。","arguments":null}',
            create_time=now,
            update_time=now,
        ),
        HistoryDetail(
            id=1001,
            history_id=123,
            type="1",
            content_type="1",
            content="查看一月销售额",
            create_time=now,
            update_time=now,
        ),
        HistoryDetail(
            id=1002,
            history_id=123,
            type="2",
            content_type="2",
            content='{"funcType":"querySalesGroupByMonth","chartCommonVoList":[{"bizId":"2026-01","name":"2026-01","value":128800.5}],"accountAgeGroupVoList":null}',
            is_like="1",
            create_time=now,
            update_time=now,
        ),
    ]
    session.add_all(details)
    session.commit()
