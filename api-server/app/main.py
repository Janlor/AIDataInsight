from contextlib import asynccontextmanager
from datetime import datetime
from math import ceil
from typing import List, Optional

from fastapi import Depends, FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse, StreamingResponse
from sqlmodel import Session, select

from .auth import get_current_user, issue_session_tokens, token_payload
from .database import create_db_and_tables, get_engine, get_session, seed_development_data
from .errors import BusinessError
from .llm import MockLLMProvider, chart_detail, compact_json
from .models import HistoryDetail, HistoryRecord, SessionToken, User
from .response import empty, envelope
from .schemas import LikeHistoryDetailRequest, LoginRequest, UpdatePasswordRequest


@asynccontextmanager
async def lifespan(app: FastAPI):
    create_db_and_tables()
    with Session(get_engine()) as session:
        seed_development_data(session)
    yield


app = FastAPI(title="AIDataInsight API Server", version="0.1.0", lifespan=lifespan)
llm_provider = MockLLMProvider()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.exception_handler(BusinessError)
def handle_business_error(request: Request, error: BusinessError) -> JSONResponse:
    return JSONResponse(envelope(None, code=error.code, msg=error.msg))


@app.get("/")
def root() -> dict:
    return envelope(
        {
            "name": "AIDataInsight API Server",
            "docs": "/docs",
            "health": "/health",
        }
    )


@app.get("/health")
def health() -> dict:
    return envelope({"status": "ok"})


@app.post("/oauth2/login")
def login(payload: LoginRequest, session: Session = Depends(get_session)) -> dict:
    user = session.exec(select(User).where(User.username == payload.name)).first()
    if user is None or user.password != payload.pwd:
        raise BusinessError(401, "Invalid username or password.")
    token = issue_session_tokens(session, user)
    return envelope(token_payload(user, token))


@app.get("/oauth2/refresh")
def refresh_token(refreshToken: str, session: Session = Depends(get_session)) -> dict:
    token = session.exec(
        select(SessionToken).where(SessionToken.refresh_token == refreshToken)
    ).first()
    if token is None or token.revoked_at is not None or token.refresh_expires_at < datetime.utcnow():
        raise BusinessError(401, "Invalid refresh token.")

    user = session.get(User, token.user_id)
    if user is None:
        raise BusinessError(401, "Invalid session.")
    token.revoked_at = datetime.utcnow()
    session.add(token)
    new_token = issue_session_tokens(session, user)
    return envelope(token_payload(user, new_token))


@app.get("/oauth2/logout")
def logout(
    request: Request,
    session: Session = Depends(get_session),
) -> dict:
    auth_header = request.headers.get("authorization") or request.headers.get("Authorization") or ""
    access_token = auth_header.replace("Bearer ", "", 1).strip()
    if access_token:
        token = session.exec(
            select(SessionToken).where(SessionToken.access_token == access_token)
        ).first()
        if token is not None:
            token.revoked_at = datetime.utcnow()
            session.add(token)
            session.commit()
    return empty()


@app.get("/oauth2/getUserInfo")
def get_user_info(user: User = Depends(get_current_user)) -> dict:
    return envelope(
        {
            "id": user.id,
            "username": user.username,
            "nickname": user.nickname,
            "phone": user.phone,
        }
    )


@app.post("/oauth2/updatePwd")
def update_password(
    payload: UpdatePasswordRequest,
    user: User = Depends(get_current_user),
    session: Session = Depends(get_session),
) -> dict:
    if user.password != payload.oldPwd:
        raise BusinessError(400, "Old password is incorrect.")
    user.password = payload.newPwd
    session.add(user)
    session.commit()
    return empty()


@app.get("/oauth2/menuTree")
def menu_tree(user: User = Depends(get_current_user)) -> dict:
    return envelope([])


@app.get("/chat/template")
def chat_template(user: User = Depends(get_current_user)) -> dict:
    return envelope(
        {
            "questions": [
                "今年第三季度销售额大于2亿的公司有哪些？",
                "查看仓库中煤炭库存大于5万吨的公司。",
                "列出公司FHJK应收余额超过5000万的客户。",
                "钢材存货金额余额最多的公司？",
                "查看各公司账龄超过180天的金额。",
            ]
        }
    )


@app.get("/chat/function")
def chat_function(
    question: str,
    historyId: Optional[int] = None,
    user: User = Depends(get_current_user),
    session: Session = Depends(get_session),
) -> dict:
    now = datetime.utcnow()
    record = None
    if historyId is not None:
        record = session.get(HistoryRecord, historyId)
        if record is not None and record.deleted_at is not None:
            record = None

    if record is None:
        record = HistoryRecord(
            name=question[:40] or "新对话",
            create_id=user.id or 0,
            update_id=user.id or 0,
            create_name=user.username,
            update_name=user.username,
            create_time=now,
            update_time=now,
        )
        session.add(record)
        session.commit()
        session.refresh(record)

    user_detail = HistoryDetail(
        history_id=record.id or 0,
        type="1",
        content_type="1",
        content=question,
        create_time=now,
        update_time=now,
    )
    session.add(user_detail)
    session.commit()

    result = llm_provider.analyze(question, record.id or 0)
    if result["hasTool"]:
        chart_payload = chart_detail(result.get("name"))
        assistant_detail = HistoryDetail(
            history_id=record.id or 0,
            type="2",
            content_type="2",
            content=compact_json(chart_payload),
            create_time=now,
            update_time=now,
        )
    else:
        assistant_detail = HistoryDetail(
            history_id=record.id or 0,
            type="2",
            content_type="1",
            content=compact_json(result),
            create_time=now,
            update_time=now,
        )
    session.add(assistant_detail)
    record.update_id = user.id or 0
    record.update_name = user.username
    record.update_time = now
    session.add(record)
    session.commit()
    session.refresh(assistant_detail)

    if result["hasTool"]:
        chart_payload["historyDetailId"] = assistant_detail.id
        assistant_detail.content = compact_json(chart_payload)
        session.add(assistant_detail)
        session.commit()

    return envelope(result)


@app.get("/stream")
def stream(question: str, user: User = Depends(get_current_user)) -> StreamingResponse:
    def events():
        for chunk in llm_provider.stream(question):
            yield "data: " + chunk + "\n\n"
        yield "data: [DONE]\n\n"

    return StreamingResponse(
        events(),
        media_type="text/event-stream",
        headers={"Cache-Control": "no-cache, no-transform"},
    )


@app.get("/chart/{function_name}")
def chart(function_name: str, historyId: int, user: User = Depends(get_current_user)) -> dict:
    payload = chart_detail(function_name)
    payload["historyDetailId"] = historyId
    return envelope(payload)


@app.get("/history/page")
def history_page(
    currentPage: int,
    pageSize: int,
    user: User = Depends(get_current_user),
    session: Session = Depends(get_session),
) -> dict:
    page = max(currentPage, 1)
    size = max(min(pageSize, 100), 1)
    statement = (
        select(HistoryRecord)
        .where(HistoryRecord.create_id == (user.id or 0))
        .where(HistoryRecord.deleted_at.is_(None))
        .order_by(HistoryRecord.update_time.desc())
    )
    records = session.exec(statement).all()
    total = len(records)
    start = (page - 1) * size
    selected = records[start : start + size]
    return envelope(
        {
            "currentPage": page,
            "pageSize": size,
            "total": total,
            "pages": ceil(total / size) if total else 0,
            "cacheKey": "local-history-page",
            "records": [serialize_history_record(record, include_details=False) for record in selected],
        }
    )


@app.get("/history/detail")
def history_detail(
    historyId: int,
    user: User = Depends(get_current_user),
    session: Session = Depends(get_session),
) -> dict:
    record = session.get(HistoryRecord, historyId)
    if record is None or record.deleted_at is not None or record.create_id != user.id:
        raise BusinessError(404, "History not found.")
    details = session.exec(
        select(HistoryDetail)
        .where(HistoryDetail.history_id == historyId)
        .order_by(HistoryDetail.create_time.asc(), HistoryDetail.id.asc())
    ).all()
    return envelope(serialize_history_record(record, include_details=True, details=details))


@app.post("/history/like")
def like_history(
    payload: LikeHistoryDetailRequest,
    user: User = Depends(get_current_user),
    session: Session = Depends(get_session),
) -> dict:
    detail = session.get(HistoryDetail, payload.historyDetailId)
    if detail is None:
        raise BusinessError(404, "History detail not found.")
    record = session.get(HistoryRecord, detail.history_id)
    if record is None or record.create_id != user.id:
        raise BusinessError(404, "History detail not found.")
    detail.is_like = payload.like
    detail.update_time = datetime.utcnow()
    session.add(detail)
    session.commit()
    return empty()


@app.get("/history/delete")
def delete_history(
    historyId: int,
    user: User = Depends(get_current_user),
    session: Session = Depends(get_session),
) -> dict:
    record = session.get(HistoryRecord, historyId)
    if record is not None and record.create_id == user.id:
        record.deleted_at = datetime.utcnow()
        session.add(record)
        session.commit()
    return empty()


@app.get("/history/deleteAll")
def delete_all_history(
    user: User = Depends(get_current_user),
    session: Session = Depends(get_session),
) -> dict:
    records = session.exec(
        select(HistoryRecord)
        .where(HistoryRecord.create_id == (user.id or 0))
        .where(HistoryRecord.deleted_at.is_(None))
    ).all()
    now = datetime.utcnow()
    for record in records:
        record.deleted_at = now
        session.add(record)
    session.commit()
    return empty()


def serialize_history_record(
    record: HistoryRecord,
    include_details: bool,
    details: Optional[List[HistoryDetail]] = None,
) -> dict:
    payload = {
        "id": record.id,
        "name": record.name,
        "createId": record.create_id,
        "updateId": record.update_id,
        "createName": record.create_name,
        "updateName": record.update_name,
        "createTime": format_time(record.create_time),
        "updateTime": format_time(record.update_time),
    }
    if include_details:
        payload["detailList"] = [serialize_history_detail(detail) for detail in (details or [])]
    return payload


def serialize_history_detail(detail: HistoryDetail) -> dict:
    return {
        "id": detail.id,
        "historyId": detail.history_id,
        "type": detail.type,
        "contentType": detail.content_type,
        "content": detail.content,
        "isLike": detail.is_like,
        "createTime": format_time(detail.create_time),
        "updateTime": format_time(detail.update_time),
    }


def format_time(value: datetime) -> str:
    return value.strftime("%Y-%m-%d %H:%M:%S")
