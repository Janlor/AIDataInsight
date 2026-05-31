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
    """应用启动生命周期：创建表并写入本地开发种子数据。"""

    create_db_and_tables()
    with Session(get_engine()) as session:
        seed_development_data(session)
    yield


app = FastAPI(title="AIDataInsight API Server", version="0.1.0", lifespan=lifespan)
# 当前服务默认使用本地 mock provider，后续可替换为真实 LLM provider。
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
    """把业务异常转换成客户端统一响应信封。"""

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
    """账号密码登录，成功后签发 access/refresh token。"""

    user = session.exec(select(User).where(User.username == payload.name)).first()
    if user is None or user.password != payload.pwd:
        raise BusinessError(401, "Invalid username or password.")
    token = issue_session_tokens(session, user)
    return envelope(token_payload(user, token))


@app.get("/oauth2/refresh")
def refresh_token(refreshToken: str, session: Session = Depends(get_session)) -> dict:
    """使用 refresh token 换取新会话，并撤销旧 refresh token。"""

    token = session.exec(
        select(SessionToken).where(SessionToken.refresh_token == refreshToken)
    ).first()
    if token is None or token.revoked_at is not None or token.refresh_expires_at < datetime.utcnow():
        raise BusinessError(401, "Invalid refresh token.")

    user = session.get(User, token.user_id)
    if user is None:
        raise BusinessError(401, "Invalid session.")
    # refresh token 采用一次性轮换策略，降低旧 token 泄露后的可用窗口。
    token.revoked_at = datetime.utcnow()
    session.add(token)
    new_token = issue_session_tokens(session, user)
    return envelope(token_payload(user, new_token))


@app.get("/oauth2/logout")
def logout(
    request: Request,
    session: Session = Depends(get_session),
) -> dict:
    """退出登录时撤销当前 access token。"""

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
    """返回当前登录用户资料。"""

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
    """修改当前用户密码。"""

    if user.password != payload.oldPwd:
        raise BusinessError(400, "Old password is incorrect.")
    user.password = payload.newPwd
    session.add(user)
    session.commit()
    return empty()


@app.get("/oauth2/menuTree")
def menu_tree(user: User = Depends(get_current_user)) -> dict:
    """菜单树占位接口，保持和现有客户端契约兼容。"""

    return envelope([])


@app.get("/chat/template")
def chat_template(user: User = Depends(get_current_user)) -> dict:
    """返回首页推荐问题。"""

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
    """处理一次聊天问题：创建/续写历史、调用函数识别，并写入助手回复。"""

    now = datetime.utcnow()
    record = None
    if historyId is not None:
        record = session.get(HistoryRecord, historyId)
        if record is not None and record.deleted_at is not None:
            record = None

    if record is None:
        # 首次提问时创建会话，标题取问题前 40 个字符。
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
        # 工具调用结果在历史里存为图表 JSON，客户端按 contentType=2 解码。
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
        # 非工具回答存为普通文本类历史；这里保留完整 JSON，便于客户端复用 msg 等字段。
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
        # 图表历史明细 id 只有写库后才生成，回填到图表 payload 供点赞接口使用。
        chart_payload["historyDetailId"] = assistant_detail.id
        assistant_detail.content = compact_json(chart_payload)
        session.add(assistant_detail)
        session.commit()

    return envelope(result)


@app.get("/stream")
def stream(question: str, user: User = Depends(get_current_user)) -> StreamingResponse:
    """SSE 流式文本接口，作为结构化函数调用失败时的兜底回答。"""

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
    """按函数名返回图表详情；historyId 会透传为 historyDetailId 兼容客户端字段。"""

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
    """分页返回当前用户未删除的历史会话。"""

    page = max(currentPage, 1)
    size = max(min(pageSize, 100), 1)
    # 当前数据量很小，先内存分页；如果历史量变大可改为 SQL offset/limit。
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
    """返回指定会话及其明细列表。"""

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
    """更新历史回答的点赞/点踩状态。"""

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
    """软删除单个历史会话。"""

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
    """软删除当前用户所有历史会话。"""

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
    """将 HistoryRecord 转为前端契约字段。"""

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
    """将 HistoryDetail 转为前端契约字段。"""

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
    """统一输出前端当前可解析的日期时间格式。"""

    return value.strftime("%Y-%m-%d %H:%M:%S")
