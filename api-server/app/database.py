import json
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, Generator, List, Optional

from sqlmodel import Session, SQLModel, create_engine, select

from .config import get_settings
from .models import HistoryDetail, HistoryRecord, User


_engine = None
_database_url_override: Optional[str] = None
_fixtures_dir_override: Optional[Path] = None
DEMO_USERNAME = "demo"
DEMO_PASSWORD = "demo@123"


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


def reset_engine_for_tests(database_url: str, fixtures_dir: Optional[Path] = None) -> None:
    global _engine, _database_url_override, _fixtures_dir_override
    _database_url_override = database_url
    _fixtures_dir_override = fixtures_dir
    _engine = None


def create_db_and_tables() -> None:
    SQLModel.metadata.create_all(get_engine())


def get_session() -> Generator[Session, None, None]:
    with Session(get_engine()) as session:
        yield session


def seed_development_data(session: Session) -> None:
    user = session.exec(select(User).where(User.username == DEMO_USERNAME)).first()
    if user is None:
        user = User(
            username=DEMO_USERNAME,
            password=DEMO_PASSWORD,
            nickname="Demo User",
            phone=None,
            org_id=1,
        )
        session.add(user)
        session.commit()
        session.refresh(user)
    elif user.password != DEMO_PASSWORD:
        user.password = DEMO_PASSWORD
        session.add(user)
        session.commit()
        session.refresh(user)

    history_count = len(session.exec(select(HistoryRecord)).all())
    if history_count > 0:
        return

    imported_count = seed_apifox_history_fixtures(session, user)
    if imported_count > 0:
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


def seed_apifox_history_fixtures(session: Session, user: User) -> int:
    fixtures_dir = _fixtures_dir_override or get_settings().fixtures_dir
    if not fixtures_dir.exists():
        return 0

    imported = 0
    page_payload = load_fixture_payload(fixtures_dir / "history" / "page.json")
    records = extract_records(page_payload)
    for record_payload in records:
        if upsert_history_record(session, user, record_payload) is not None:
            imported += 1

    detail_dir = fixtures_dir / "history" / "detail"
    for path in sorted(detail_dir.glob("*.json")) if detail_dir.exists() else []:
        detail_payload = load_fixture_payload(path)
        if not detail_payload:
            continue
        record_payload = unwrap_envelope(detail_payload)
        record = upsert_history_record(session, user, record_payload)
        if record is None:
            continue
        replace_history_details(session, record.id or 0, record_payload.get("detailList") or [])
        imported += 1

    session.commit()
    return imported


def load_fixture_payload(path: Path) -> Optional[Any]:
    if not path.exists():
        return None
    raw = path.read_text(encoding="utf-8").strip()
    if not raw:
        return None
    try:
        return json.loads(raw)
    except json.JSONDecodeError as error:
        raise ValueError(f"Invalid JSON fixture: {path}") from error


def unwrap_envelope(payload: Any) -> Any:
    if isinstance(payload, dict) and "data" in payload and "code" in payload:
        return payload.get("data")
    return payload


def extract_records(payload: Optional[Any]) -> List[Dict[str, Any]]:
    if payload is None:
        return []
    data = unwrap_envelope(payload)
    if isinstance(data, dict) and isinstance(data.get("records"), list):
        return [record for record in data["records"] if isinstance(record, dict)]
    if isinstance(data, list):
        return [record for record in data if isinstance(record, dict)]
    return []


def upsert_history_record(
    session: Session,
    user: User,
    payload: Any,
) -> Optional[HistoryRecord]:
    if not isinstance(payload, dict):
        return None

    record_id = payload.get("id") or payload.get("historyId")
    if record_id is None:
        return None

    existing = session.get(HistoryRecord, int(record_id))
    record_name = payload.get("name") or infer_history_name(payload) or f"History {record_id}"
    create_time = parse_time(payload.get("createTime")) or datetime.utcnow()
    update_time = parse_time(payload.get("updateTime")) or create_time

    if existing is None:
        existing = HistoryRecord(
            id=int(record_id),
            name=str(record_name),
            create_id=user.id or 1,
            update_id=user.id or 1,
            create_name=str(payload.get("createName") or user.username),
            update_name=str(payload.get("updateName") or user.username),
            create_time=create_time,
            update_time=update_time,
        )
    else:
        existing.name = str(record_name)
        existing.update_time = update_time
        existing.deleted_at = None

    session.add(existing)
    session.commit()
    session.refresh(existing)
    return existing


def replace_history_details(
    session: Session,
    history_id: int,
    details_payload: List[Any],
) -> None:
    existing_details = session.exec(
        select(HistoryDetail).where(HistoryDetail.history_id == history_id)
    ).all()
    for detail in existing_details:
        session.delete(detail)

    for detail_payload in details_payload:
        if not isinstance(detail_payload, dict):
            continue
        content = detail_payload.get("content")
        if content is None:
            content = ""
        elif not isinstance(content, str):
            content = json.dumps(content, ensure_ascii=False, separators=(",", ":"))

        detail_id = detail_payload.get("id")
        detail = HistoryDetail(
            id=int(detail_id) if detail_id is not None else None,
            history_id=history_id,
            type=str(detail_payload.get("type") or "1"),
            content_type=str(detail_payload.get("contentType") or detail_payload.get("content_type") or "1"),
            content=content,
            is_like=detail_payload.get("isLike") or detail_payload.get("is_like"),
            create_time=parse_time(detail_payload.get("createTime")) or datetime.utcnow(),
            update_time=parse_time(detail_payload.get("updateTime")) or datetime.utcnow(),
        )
        session.add(detail)


def infer_history_name(payload: Dict[str, Any]) -> Optional[str]:
    details = payload.get("detailList")
    if not isinstance(details, list):
        return None
    for detail in details:
        if isinstance(detail, dict) and str(detail.get("type")) == "1" and detail.get("content"):
            return str(detail["content"])[:40]
    return None


def parse_time(value: Any) -> Optional[datetime]:
    if not isinstance(value, str) or not value.strip():
        return None
    text = value.strip()
    formats = [
        "%Y-%m-%d %H:%M:%S",
        "%Y-%m-%dT%H:%M:%S",
        "%Y-%m-%dT%H:%M:%S.%f",
        "%Y-%m-%d",
    ]
    for date_format in formats:
        try:
            return datetime.strptime(text.removesuffix("Z"), date_format)
        except ValueError:
            continue
    return None
