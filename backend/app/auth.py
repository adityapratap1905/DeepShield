"""Email and password authentication backed by the configured SQL database."""

from __future__ import annotations

import hashlib
import hmac
import os
import secrets
import time
from datetime import datetime, timezone
from uuid import uuid4

from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from pydantic import BaseModel, EmailStr, Field, field_validator
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from .database import get_db
from .models import RevokedToken, User

TOKEN_SECRET = os.getenv("DEEPSHIELD_AUTH_SECRET", "").encode()
TOKEN_LIFETIME_SECONDS = 60 * 60 * 24 * 30
PBKDF2_ITERATIONS = 310_000

router = APIRouter(prefix="/api/v1/auth", tags=["authentication"])
bearer = HTTPBearer(auto_error=False)


class Credentials(BaseModel):
    email: EmailStr
    password: str = Field(min_length=8, max_length=128)


class Registration(Credentials):
    name: str = Field(min_length=1, max_length=80)

    @field_validator("name")
    @classmethod
    def name_not_blank(cls, value: str) -> str:
        value = value.strip()
        if not value:
            raise ValueError("Name cannot be blank.")
        return value


def _password_hash(password: str, salt: bytes) -> bytes:
    return hashlib.pbkdf2_hmac("sha256", password.encode(), salt, PBKDF2_ITERATIONS)


def _user_payload(user: User) -> dict[str, str | None]:
    return {
        "id": user.id,
        "name": user.name,
        "email": user.email,
        "created_at": user.created_at,
        "bio": user.bio,
        "avatar_url": user.avatar_url,
    }


def _issue_token(user_id: str) -> str:
    if not TOKEN_SECRET:
        raise HTTPException(status_code=503, detail="Authentication is not configured. Set DEEPSHIELD_AUTH_SECRET.")
    expires = int(time.time()) + TOKEN_LIFETIME_SECONDS
    # The nonce makes tokens unique even when several sessions are issued in
    # the same second. The expiry remains readable and compatible with legacy
    # tokens, which contain only the integer timestamp.
    expiry_field = f"{expires}.{secrets.token_urlsafe(12)}"
    payload = f"{user_id}:{expiry_field}"
    signature = hmac.new(TOKEN_SECRET, payload.encode(), hashlib.sha256).hexdigest()
    return f"{payload}:{signature}"


def _expiry_seconds(expiry_field: str) -> int:
    return int(expiry_field.partition(".")[0])


def _token_expiry_seconds(token: str) -> int:
    try:
        _, expiry_field, _ = token.rsplit(":", 2)
        return _expiry_seconds(expiry_field)
    except (ValueError, TypeError):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid or expired session.") from None


def _token_user_id(token: str, *, allow_expired: bool = False) -> str:
    try:
        user_id, expiry_field, signature = token.rsplit(":", 2)
        expiry = _expiry_seconds(expiry_field)
        payload = f"{user_id}:{expiry_field}"
        expected = hmac.new(TOKEN_SECRET, payload.encode(), hashlib.sha256).hexdigest()
        expired_too_long = expiry + TOKEN_LIFETIME_SECONDS < time.time()
        if (
            not TOKEN_SECRET
            or not hmac.compare_digest(signature, expected)
            or (expiry <= time.time() and (not allow_expired or expired_too_long))
        ):
            raise ValueError
    except (ValueError, TypeError):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid or expired session.") from None
    return user_id


def current_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer),
    db: Session = Depends(get_db),
) -> dict[str, str | None]:
    if credentials is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Authentication required.")
    user_id = _token_user_id(credentials.credentials)
    token_hash = hashlib.sha256(credentials.credentials.encode()).hexdigest()
    if db.get(RevokedToken, token_hash) is not None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Session has been signed out.")
    user = db.get(User, user_id)
    if user is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Account no longer exists.")
    return _user_payload(user)


def _session(user: User) -> dict[str, object]:
    return {"access_token": _issue_token(user.id), "token_type": "bearer", "user": _user_payload(user)}


@router.post("/register", status_code=status.HTTP_201_CREATED)
def register(body: Registration, db: Session = Depends(get_db)) -> dict[str, object]:
    email = str(body.email).strip().lower()
    salt = secrets.token_bytes(16)
    user = User(
        id=str(uuid4()),
        name=body.name.strip(),
        email=email,
        password_hash=_password_hash(body.password, salt).hex(),
        password_salt=salt.hex(),
        created_at=datetime.now(timezone.utc).isoformat(),
    )
    db.add(user)
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(status_code=409, detail="An account with this email already exists.") from None
    db.refresh(user)
    return _session(user)


@router.post("/login")
def login(body: Credentials, db: Session = Depends(get_db)) -> dict[str, object]:
    email = str(body.email).strip().lower()
    user = db.scalar(select(User).where(User.email == email))
    if user is None or not hmac.compare_digest(
        _password_hash(body.password, bytes.fromhex(user.password_salt)).hex(), user.password_hash
    ):
        raise HTTPException(status_code=401, detail="Invalid email or password.")
    return _session(user)


@router.get("/me")
def me(user: dict[str, str | None] = Depends(current_user)) -> dict[str, str | None]:
    return user


@router.post("/refresh")
def refresh(
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer),
    db: Session = Depends(get_db),
) -> dict[str, object]:
    if credentials is None:
        raise HTTPException(status_code=401, detail="Authentication required.")
    user_id = _token_user_id(credentials.credentials, allow_expired=True)
    token_hash = hashlib.sha256(credentials.credentials.encode()).hexdigest()
    if db.get(RevokedToken, token_hash) is not None:
        raise HTTPException(status_code=401, detail="Session has already been rotated or signed out.")
    expiry = _token_expiry_seconds(credentials.credentials)
    db.add(RevokedToken(token_hash=token_hash, expires_at=expiry))
    db.commit()
    account = db.get(User, user_id)
    if account is None:
        raise HTTPException(status_code=401, detail="Account no longer exists.")
    return _session(account)


@router.post("/logout")
def logout(
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer),
    user: dict[str, str | None] = Depends(current_user),
    db: Session = Depends(get_db),
) -> dict[str, bool]:
    if credentials is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Authentication required.")
    token_hash = hashlib.sha256(credentials.credentials.encode()).hexdigest()
    expiry = _token_expiry_seconds(credentials.credentials)
    db.query(RevokedToken).filter(RevokedToken.expires_at < int(time.time())).delete()
    if db.get(RevokedToken, token_hash) is None:
        db.add(RevokedToken(token_hash=token_hash, expires_at=expiry))
    db.commit()
    return {"success": True}
