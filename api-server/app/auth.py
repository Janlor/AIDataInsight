from datetime import datetime, timedelta
from typing import Optional
from uuid import uuid4

from fastapi import Depends, Request
from sqlmodel import Session, select

from .database import get_session
from .errors import BusinessError
from .models import SessionToken, User


ACCESS_TOKEN_SECONDS = 60 * 30
REFRESH_TOKEN_SECONDS = 60 * 60 * 24 * 7


def issue_session_tokens(session: Session, user: User) -> SessionToken:
    now = datetime.utcnow()
    token = SessionToken(
        user_id=user.id or 0,
        access_token="aid-access-" + uuid4().hex,
        refresh_token="aid-refresh-" + uuid4().hex,
        access_expires_at=now + timedelta(seconds=ACCESS_TOKEN_SECONDS),
        refresh_expires_at=now + timedelta(seconds=REFRESH_TOKEN_SECONDS),
    )
    session.add(token)
    session.commit()
    session.refresh(token)
    return token


def token_payload(user: User, token: SessionToken) -> dict:
    return {
        "access_token": token.access_token,
        "refresh_token": token.refresh_token,
        "org_id": user.org_id,
        "accessToken": token.access_token,
        "refreshToken": token.refresh_token,
        "orgId": user.org_id,
        "expires_in": ACCESS_TOKEN_SECONDS,
        "refresh_expires_in": REFRESH_TOKEN_SECONDS,
        "client_id": "ai-data-local-api",
        "scope": "ai-data-local-api",
        "openid": None,
    }


def read_bearer_token(request: Request) -> Optional[str]:
    value = request.headers.get("authorization") or request.headers.get("Authorization")
    if not value:
        return None
    prefix = "Bearer "
    if not value.startswith(prefix):
        return None
    return value[len(prefix):].strip()


def get_current_user(
    request: Request,
    session: Session = Depends(get_session),
) -> User:
    access_token = read_bearer_token(request)
    if not access_token:
        raise BusinessError(401, "Missing access token.")

    token = session.exec(
        select(SessionToken).where(SessionToken.access_token == access_token)
    ).first()
    if token is None or token.revoked_at is not None:
        raise BusinessError(401, "Invalid session.")
    if token.access_expires_at < datetime.utcnow():
        raise BusinessError(402, "Access token expired.")

    user = session.get(User, token.user_id)
    if user is None:
        raise BusinessError(401, "Invalid session.")
    return user
