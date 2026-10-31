"""Authenticated REST endpoints for the initial DeepShield Social slice."""

from __future__ import annotations

import hashlib
import os
import re
import secrets
import json
import time
from datetime import datetime, timezone
from io import BytesIO
from pathlib import Path
from typing import Literal
from uuid import uuid4

from fastapi import APIRouter, Depends, File, HTTPException, Query, UploadFile, status
from fastapi.responses import FileResponse
from PIL import Image, ImageOps, UnidentifiedImageError
from pydantic import BaseModel, Field, field_validator, model_validator
from sqlalchemy import func, select
from sqlalchemy.dialects.mysql import insert as mysql_insert
from sqlalchemy.dialects.sqlite import insert as sqlite_insert
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session, joinedload

from .auth import _password_hash, current_user
from .database import get_db
from .models import (
    AccountSettings,
    Bookmark,
    Comment,
    Community,
    CommunityMember,
    ContentReport,
    Follow,
    Notification,
    Post,
    PostMedia,
    PostLike,
    ProfileAvatar,
    RateLimitBucket,
    ScanReport,
    User,
    UserBlock,
)

router = APIRouter(prefix="/api/v1", tags=["social"])
BACKEND_DIR = Path(__file__).resolve().parents[1]
PRIVATE_MEDIA_DIR = Path(os.getenv(
    "DEEPSHIELD_SOCIAL_MEDIA_DIR", str(BACKEND_DIR / "data" / "private_media")
)).expanduser().resolve()
MAX_SOCIAL_IMAGE_BYTES = 15 * 1024 * 1024
MAX_SOCIAL_VIDEO_BYTES = 50 * 1024 * 1024
MAX_PROFILE_AVATAR_BYTES = 5 * 1024 * 1024
SOCIAL_IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png"}
SOCIAL_VIDEO_EXTENSIONS = {".mp4", ".mov", ".avi", ".mkv", ".webm"}
MODERATOR_EMAILS = {
    email.strip().casefold()
    for email in os.getenv("DEEPSHIELD_MODERATOR_EMAILS", "").split(",")
    if email.strip()
}


class ProfileUpdate(BaseModel):
    name: str = Field(min_length=1, max_length=80)
    bio: str = Field(default="", max_length=280)

    @field_validator("name")
    @classmethod
    def validate_name(cls, value: str) -> str:
        if not value.strip():
            raise ValueError("Name cannot be blank.")
        return value.strip()


class PasswordChangeRequest(BaseModel):
    current_password: str = Field(min_length=8, max_length=128)
    new_password: str = Field(min_length=8, max_length=128)

    @field_validator("new_password")
    @classmethod
    def new_password_differs(cls, value: str, info: object) -> str:
        current = getattr(info, "data", {}).get("current_password")
        if current is not None and value == current:
            raise ValueError("Choose a password different from the current one.")
        return value


class AccountSettingsUpdate(BaseModel):
    show_in_creator_search: bool | None = None
    notify_likes: bool | None = None
    notify_comments: bool | None = None
    notify_follows: bool | None = None

    @model_validator(mode="after")
    def require_at_least_one_setting(self) -> AccountSettingsUpdate:
        if all(value is None for value in self.model_dump().values()):
            raise ValueError("Choose at least one setting to update.")
        return self


class CreatePost(BaseModel):
    body: str = Field(min_length=1, max_length=4000)
    community_id: str | None = None
    scan_report_id: str | None = None


class CreateComment(BaseModel):
    body: str = Field(min_length=1, max_length=2000)
    parent_comment_id: str | None = None


class CreateCommunity(BaseModel):
    name: str = Field(min_length=3, max_length=100)
    description: str = Field(min_length=1, max_length=500)


class ContentReportRequest(BaseModel):
    reason: Literal["spam", "harassment", "misinformation", "other"]
    details: str | None = Field(default=None, max_length=1000)


class ModerationReviewRequest(BaseModel):
    action: Literal["dismiss", "remove_content"]


class ShareScanReportRequest(BaseModel):
    scan_result: dict[str, object]
    caption: str = Field(default="", max_length=1000)


class UserSummary(BaseModel):
    id: str
    name: str
    bio: str | None = None
    avatar_url: str | None = None


class PostView(BaseModel):
    id: str
    body: str
    created_at: datetime
    author: UserSummary
    community: str | None = None
    likes_count: int
    comments_count: int
    liked: bool
    bookmarked: bool
    scan_report: dict[str, object] | None = None
    media: list[dict[str, str]] = Field(default_factory=list)


def _uid(user: dict[str, str | None]) -> str:
    return str(user["id"])


def _is_moderator(user: dict[str, str | None]) -> bool:
    return (user.get("email") or "").casefold() in MODERATOR_EMAILS


def _require_moderator(user: dict[str, str | None]) -> None:
    if not _is_moderator(user):
        raise HTTPException(status_code=403, detail="Moderator access is required.")


def _notify(db: Session, *, recipient: str, actor: str, kind: str, post_id: str | None = None) -> None:
    if recipient == actor:
        return
    settings = db.get(AccountSettings, recipient)
    preference = {
        "like": "notify_likes",
        "comment": "notify_comments",
        "follow": "notify_follows",
    }.get(kind)
    if preference is not None and settings is not None and not getattr(settings, preference):
        return
    db.add(Notification(
        id=str(uuid4()), user_id=recipient, actor_id=actor, kind=kind, post_id=post_id
    ))


def _post_payload(db: Session, post: Post, viewer_id: str) -> dict[str, object]:
    report_summary = None
    if post.scan_report_id:
        report = db.get(ScanReport, post.scan_report_id)
        if report is not None:
            report_data = json.loads(report.result_json)
            extra_data = report_data.get("extra_data")
            if not isinstance(extra_data, dict):
                extra_data = {}
            report_summary = {
                "id": report.id,
                "scan_type": report_data.get("scan_type"),
                "target": report_data.get("target"),
                "prediction": extra_data.get("prediction"),
                "ai_generation_score": extra_data.get("ai_generated_probability"),
                "face_manipulation_score": extra_data.get("face_manipulation_probability"),
                "video_fake_score": extra_data.get("fake_probability"),
                "model_version": extra_data.get("model_version") or report_data.get("model_version"),
                "scanned_at": report_data.get("scanned_at"),
                "disclaimer": "This is a user-shared automated model estimate, not proof of authenticity.",
            }
    return {
        "id": post.id,
        "body": post.body,
        "created_at": post.created_at,
        "author": {
            "id": post.author.id,
            "name": post.author.name,
            "bio": post.author.bio,
            "avatar_url": post.author.avatar_url,
        },
        "community": post.community.name if post.community else None,
        "likes_count": db.scalar(select(func.count()).select_from(PostLike).where(PostLike.post_id == post.id)) or 0,
        "comments_count": db.scalar(select(func.count()).select_from(Comment).where(Comment.post_id == post.id)) or 0,
        "liked": db.get(PostLike, (viewer_id, post.id)) is not None,
        "bookmarked": db.get(Bookmark, (viewer_id, post.id)) is not None,
        "scan_report": report_summary,
        "media": [
            {
                "id": media.id,
                "media_type": media.media_type,
                "filename": media.filename,
                "url": f"/social/media/{media.id}",
            }
            for media in post.media
        ],
    }


def _post_or_404(db: Session, post_id: str) -> Post:
    post = db.scalar(
        select(Post).options(joinedload(Post.author), joinedload(Post.community)).where(Post.id == post_id)
    )
    if post is None:
        raise HTTPException(status_code=404, detail="Post not found.")
    return post


@router.get("/profiles/me")
def get_my_profile(
    user: dict[str, str | None] = Depends(current_user), db: Session = Depends(get_db)
) -> dict[str, object]:
    return _profile_payload(db, _uid(user), viewer_id=_uid(user))


@router.patch("/profiles/me")
def update_my_profile(
    body: ProfileUpdate,
    user: dict[str, str | None] = Depends(current_user),
    db: Session = Depends(get_db),
) -> dict[str, object]:
    account = db.get(User, _uid(user))
    if account is None:
        raise HTTPException(status_code=404, detail="Account not found.")
    account.name = body.name.strip()
    account.bio = body.bio.strip() or None
    db.commit()
    return _profile_payload(db, account.id, viewer_id=account.id)


@router.post("/profiles/me/password")
def change_my_password(
    body: PasswordChangeRequest,
    user: dict[str, str | None] = Depends(current_user),
    db: Session = Depends(get_db),
) -> dict[str, bool]:
    account = db.get(User, _uid(user))
    if account is None:
        raise HTTPException(status_code=404, detail="Account not found.")
    current_hash = _password_hash(body.current_password, bytes.fromhex(account.password_salt)).hex()
    if not secrets.compare_digest(current_hash, account.password_hash):
        raise HTTPException(status_code=400, detail="Current password is incorrect.")
    salt = secrets.token_bytes(16)
    account.password_salt = salt.hex()
    account.password_hash = _password_hash(body.new_password, salt).hex()
    db.commit()
    return {"success": True}


@router.post("/profiles/me/avatar")
async def upload_my_avatar(
    file: UploadFile = File(...),
    user: dict[str, str | None] = Depends(current_user),
    db: Session = Depends(get_db),
) -> dict[str, object]:
    account = db.get(User, _uid(user))
    if account is None:
        raise HTTPException(status_code=404, detail="Account not found.")
    _enforce_rate_limit(db, account.id, "profile-avatar", limit=5, window_seconds=300)
    filename = Path(file.filename or "avatar").name
    extension = Path(filename).suffix.lower()
    expected_format = {".jpg": "JPEG", ".jpeg": "JPEG", ".png": "PNG"}.get(extension)
    if expected_format is None:
        raise HTTPException(status_code=415, detail="Choose a JPG or PNG profile photo.")
    content = await file.read(MAX_PROFILE_AVATAR_BYTES + 1)
    if not content or len(content) > MAX_PROFILE_AVATAR_BYTES:
        raise HTTPException(status_code=413, detail="The profile photo must be smaller than 5 MB.")
    try:
        with Image.open(BytesIO(content)) as image:
            if image.format != expected_format or image.width * image.height > 25_000_000:
                raise HTTPException(status_code=415, detail="The image format or dimensions are not supported.")
            image.verify()
        with Image.open(BytesIO(content)) as image:
            normalized = ImageOps.exif_transpose(image)
            normalized.thumbnail((512, 512), Image.Resampling.LANCZOS)
            output = BytesIO()
            normalized.save(output, format=expected_format, optimize=True)
            safe_content = output.getvalue()
    except (UnidentifiedImageError, OSError, Image.DecompressionBombError) as error:
        raise HTTPException(status_code=415, detail="The profile photo is invalid.") from error

    avatar_dir = (PRIVATE_MEDIA_DIR / "avatars").resolve()
    avatar_dir.mkdir(parents=True, exist_ok=True)
    avatar_id = str(uuid4())
    storage_key = f"avatars/{avatar_id}{extension}"
    stored_path = (PRIVATE_MEDIA_DIR / storage_key).resolve()
    try:
        stored_path.relative_to(PRIVATE_MEDIA_DIR)
    except ValueError as error:
        raise HTTPException(status_code=400, detail="Invalid avatar storage path.") from error
    stored_path.write_bytes(safe_content)

    avatar = db.get(ProfileAvatar, account.id)
    previous_path = _stored_media_path(avatar) if avatar is not None else None
    if avatar is None:
        avatar = ProfileAvatar(
            user_id=account.id,
            storage_key=storage_key,
            filename=filename[:255],
            media_type="image/jpeg" if expected_format == "JPEG" else "image/png",
            sha256=hashlib.sha256(safe_content).hexdigest(),
        )
        db.add(avatar)
    else:
        avatar.storage_key = storage_key
        avatar.filename = filename[:255]
        avatar.media_type = "image/jpeg" if expected_format == "JPEG" else "image/png"
        avatar.sha256 = hashlib.sha256(safe_content).hexdigest()
        avatar.updated_at = datetime.now(timezone.utc)
    account.avatar_url = f"/profiles/{account.id}/avatar"
    try:
        db.commit()
    except IntegrityError as error:
        db.rollback()
        stored_path.unlink(missing_ok=True)
        raise HTTPException(status_code=409, detail="The profile photo could not be saved.") from error
    if previous_path is not None and previous_path != stored_path:
        previous_path.unlink(missing_ok=True)
    return _profile_payload(db, account.id, viewer_id=account.id)


@router.delete("/profiles/me/avatar")
def delete_my_avatar(
    user: dict[str, str | None] = Depends(current_user),
    db: Session = Depends(get_db),
) -> dict[str, bool]:
    account = db.get(User, _uid(user))
    if account is None:
        raise HTTPException(status_code=404, detail="Account not found.")
    avatar = db.get(ProfileAvatar, account.id)
    previous_path = _stored_media_path(avatar) if avatar is not None else None
    if avatar is not None:
        db.delete(avatar)
    account.avatar_url = None
    db.commit()
    if previous_path is not None:
        previous_path.unlink(missing_ok=True)
    return {"success": True}


@router.get("/profiles/{user_id}/avatar")
def get_profile_avatar(
    user_id: str,
    user: dict[str, str | None] = Depends(current_user),
    db: Session = Depends(get_db),
) -> FileResponse:
    viewer_id = _uid(user)
    account = db.get(User, user_id)
    avatar = db.get(ProfileAvatar, user_id)
    if account is None or avatar is None:
        raise HTTPException(status_code=404, detail="Profile photo not found.")
    if _users_blocked(db, viewer_id, user_id):
        raise HTTPException(status_code=404, detail="Profile photo not found.")
    path = _stored_media_path(avatar)
    if not path.is_file():
        raise HTTPException(status_code=404, detail="Profile photo not found.")
    return FileResponse(
        path,
        media_type=avatar.media_type,
        filename=avatar.filename,
        content_disposition_type="inline",
        headers={"Cache-Control": "private, no-store", "X-Content-Type-Options": "nosniff"},
    )


@router.get("/profiles/{user_id}")
def get_profile(
    user_id: str,
    user: dict[str, str | None] = Depends(current_user),
    db: Session = Depends(get_db),
) -> dict[str, object]:
    return _profile_payload(db, user_id, viewer_id=_uid(user))


def _profile_payload(db: Session, user_id: str, viewer_id: str) -> dict[str, object]:
    account = db.get(User, user_id)
    if account is None:
        raise HTTPException(status_code=404, detail="Profile not found.")
    posts_count = db.scalar(select(func.count()).select_from(Post).where(Post.user_id == user_id)) or 0
    followers = db.scalar(select(func.count()).select_from(Follow).where(Follow.followed_id == user_id)) or 0
    following = db.scalar(select(func.count()).select_from(Follow).where(Follow.follower_id == user_id)) or 0
    is_following = db.get(Follow, (viewer_id, user_id)) is not None
    return {
        "id": account.id,
        "name": account.name,
        "email": account.email if user_id == viewer_id else None,
        "bio": account.bio,
        "avatar_url": account.avatar_url,
        "created_at": account.created_at,
        "posts_count": posts_count,
        "followers_count": followers,
        "following_count": following,
        "is_following": is_following,
        "is_moderator": user_id == viewer_id and account.email.casefold() in MODERATOR_EMAILS,
    }


@router.get("/profiles/me/posts", response_model=list[PostView])
def get_my_posts(
    limit: int = Query(default=50, ge=1, le=100),
    user: dict[str, str | None] = Depends(current_user),
    db: Session = Depends(get_db),
) -> list[dict[str, object]]:
    viewer_id = _uid(user)
    posts = db.scalars(
        select(Post)
        .where(Post.user_id == viewer_id)
        .options(joinedload(Post.author), joinedload(Post.community))
        .order_by(Post.created_at.desc())
        .limit(limit)
    ).unique().all()
    return [_post_payload(db, post, viewer_id) for post in posts]


def _account_settings_payload(settings: AccountSettings | None) -> dict[str, bool]:
    return {
        "show_in_creator_search": settings.show_in_creator_search if settings else True,
        "notify_likes": settings.notify_likes if settings else True,
        "notify_comments": settings.notify_comments if settings else True,
        "notify_follows": settings.notify_follows if settings else True,
    }


@router.get("/profiles/me/settings")
def get_my_settings(
    user: dict[str, str | None] = Depends(current_user),
    db: Session = Depends(get_db),
) -> dict[str, bool]:
    return _account_settings_payload(db.get(AccountSettings, _uid(user)))


@router.patch("/profiles/me/settings")
def update_my_settings(
    body: AccountSettingsUpdate,
    user: dict[str, str | None] = Depends(current_user),
    db: Session = Depends(get_db),
) -> dict[str, bool]:
    settings = db.get(AccountSettings, _uid(user))
    if settings is None:
        settings = AccountSettings(user_id=_uid(user))
        db.add(settings)
    for key, value in body.model_dump(exclude_unset=True).items():
        if value is not None:
            setattr(settings, key, value)
    db.commit()
    db.refresh(settings)
    return _account_settings_payload(settings)


@router.get("/profiles/me/communities")
def get_my_communities(
    user: dict[str, str | None] = Depends(current_user),
    db: Session = Depends(get_db),
) -> list[dict[str, object]]:
    viewer_id = _uid(user)
    communities = db.scalars(
        select(Community)
        .join(CommunityMember, CommunityMember.community_id == Community.id)
        .where(CommunityMember.user_id == viewer_id)
        .order_by(Community.name.asc())
    ).all()
    return [
        {
            "id": community.id,
            "name": community.name,
            "description": community.description,
            "members_count": db.scalar(
                select(func.count())
                .select_from(CommunityMember)
                .where(CommunityMember.community_id == community.id)
            ) or 0,
            "joined": True,
        }
        for community in communities
    ]


@router.get("/social/feed", response_model=list[PostView])
def get_feed(
    feed: Literal["for_you", "following", "trending"] = "for_you",
    limit: int = Query(default=20, ge=1, le=50),
    offset: int = Query(default=0, ge=0),
    user: dict[str, str | None] = Depends(current_user),
    db: Session = Depends(get_db),
) -> list[dict[str, object]]:
    viewer_id = _uid(user)
    query = select(Post).options(joinedload(Post.author), joinedload(Post.community))
    blocked_by_viewer = select(UserBlock.blocked_id).where(UserBlock.blocker_id == viewer_id)
    blocked_viewer = select(UserBlock.blocker_id).where(UserBlock.blocked_id == viewer_id)
    query = query.where(Post.user_id.not_in(blocked_by_viewer)).where(Post.user_id.not_in(blocked_viewer))
    if feed == "following":
        followed_ids = select(Follow.followed_id).where(Follow.follower_id == viewer_id)
        query = query.where(Post.user_id.in_(followed_ids))
    if feed == "trending":
        likes = (
            select(PostLike.post_id.label("post_id"), func.count().label("likes"))
            .group_by(PostLike.post_id)
            .subquery()
        )
        query = query.outerjoin(likes, Post.id == likes.c.post_id).order_by(
            func.coalesce(likes.c.likes, 0).desc(), Post.created_at.desc()
        )
    else:
        query = query.order_by(Post.created_at.desc())
    posts = db.scalars(query.offset(offset).limit(limit)).unique().all()
    return [_post_payload(db, post, viewer_id) for post in posts]


@router.get("/social/search", response_model=list[PostView])
def search_posts(
    q: str = Query(min_length=2, max_length=100),
    limit: int = Query(default=20, ge=1, le=50),
    offset: int = Query(default=0, ge=0),
    user: dict[str, str | None] = Depends(current_user),
    db: Session = Depends(get_db),
) -> list[dict[str, object]]:
    """Search public post captions without exposing blocked users' content."""
    viewer_id = _uid(user)
    term = q.strip()
    if len(term) < 2:
        return []
    blocked_by_viewer = select(UserBlock.blocked_id).where(UserBlock.blocker_id == viewer_id)
    blocked_viewer = select(UserBlock.blocker_id).where(UserBlock.blocked_id == viewer_id)
    query = (
        select(Post)
        .join(Post.author)
        .options(joinedload(Post.author), joinedload(Post.community))
        .where(func.lower(Post.body).contains(term.casefold(), autoescape=True))
        .where(Post.user_id.not_in(blocked_by_viewer))
        .where(Post.user_id.not_in(blocked_viewer))
        .order_by(Post.created_at.desc())
    )
    posts = db.scalars(query.offset(offset).limit(limit)).unique().all()
    return [_post_payload(db, post, viewer_id) for post in posts]


@router.post("/social/posts", response_model=PostView, status_code=status.HTTP_201_CREATED)
def create_post(
    body: CreatePost,
    user: dict[str, str | None] = Depends(current_user),
    db: Session = Depends(get_db),
) -> dict[str, object]:
    author_id = _uid(user)
    community_id = body.community_id
    scan_report_id = body.scan_report_id
    if community_id is not None and db.get(CommunityMember, (community_id, author_id)) is None:
        raise HTTPException(status_code=403, detail="Join this community before posting.")
    if scan_report_id is not None:
        report = db.get(ScanReport, scan_report_id)
        if report is None or report.user_id != author_id:
            raise HTTPException(status_code=404, detail="Your scan report was not found.")
        if db.scalar(select(Post.id).where(Post.scan_report_id == scan_report_id)) is not None:
            raise HTTPException(status_code=409, detail="This scan report has already been shared.")
    post = Post(
        id=str(uuid4()), user_id=author_id, community_id=community_id,
        scan_report_id=scan_report_id, body=body.body.strip()
    )
    if not post.body:
        raise HTTPException(status_code=422, detail="A post cannot be blank.")
    _enforce_rate_limit(db, author_id, "social-post", limit=10)
    db.add(post)
    db.commit()
    post = _post_or_404(db, post.id)
    return _post_payload(db, post, author_id)


@router.post("/scan-reports/share", status_code=status.HTTP_201_CREATED)
def share_scan_report(
    body: ShareScanReportRequest,
    user: dict[str, str | None] = Depends(current_user),
    db: Session = Depends(get_db),
) -> dict[str, object]:
    incoming = body.scan_result
    if incoming.get("is_demo") is not False:
        raise HTTPException(status_code=422, detail="Only completed, non-demo scan results can be shared.")
    required = {"scan_type", "target", "scanned_at", "recommendation", "reasons"}
    if not required.issubset(incoming):
        raise HTTPException(status_code=422, detail="The scan result is incomplete.")
    if incoming.get("scan_type") not in {"file", "video"}:
        raise HTTPException(status_code=422, detail="Only completed photo or video scans can be shared.")
    if not isinstance(incoming.get("target"), str) or not isinstance(incoming.get("reasons"), list):
        raise HTTPException(status_code=422, detail="The scan result fields are invalid.")
    allowed = {
        "id", "scan_type", "target", "threat_level", "confidence_score", "is_safe",
        "reasons", "recommendation", "scan_duration_ms", "scanned_at", "extra_data", "is_demo",
    }
    sanitized = {key: incoming[key] for key in allowed if key in incoming}
    try:
        encoded = json.dumps(sanitized, ensure_ascii=False, separators=(",", ":"))
    except (TypeError, ValueError):
        raise HTTPException(status_code=422, detail="The scan result could not be stored.") from None
    if len(encoded.encode("utf-8")) > 64 * 1024:
        raise HTTPException(status_code=413, detail="The scan report is too large to share.")
    report_id = str(uuid4())
    owner_id = _uid(user)
    _enforce_rate_limit(db, owner_id, "scan-report-share", limit=6, window_seconds=300)
    report = ScanReport(id=report_id, user_id=owner_id, result_json=encoded)
    caption = body.caption.strip()
    target = str(sanitized.get("target", "media"))[:180]
    post_body = caption or f"I scanned {target}. Here is the result and model context."
    post = Post(id=str(uuid4()), user_id=owner_id, scan_report_id=report_id, body=post_body)
    db.add_all([report, post])
    db.commit()
    post = _post_or_404(db, post.id)
    return {"report_id": report_id, "post": _post_payload(db, post, owner_id)}


@router.get("/scan-reports/{report_id}")
def get_scan_report(
    report_id: str,
    user: dict[str, str | None] = Depends(current_user),
    db: Session = Depends(get_db),
) -> dict[str, object]:
    report = db.get(ScanReport, report_id)
    if report is None:
        raise HTTPException(status_code=404, detail="Scan report not found.")
    is_shared = db.scalar(select(Post.id).where(Post.scan_report_id == report_id)) is not None
    if report.user_id != _uid(user) and not is_shared:
        raise HTTPException(status_code=404, detail="Scan report not found.")
    return {"id": report.id, "result": json.loads(report.result_json), "created_at": report.created_at}


@router.get("/social/posts/{post_id}", response_model=PostView)
def get_post(
    post_id: str,
    user: dict[str, str | None] = Depends(current_user),
    db: Session = Depends(get_db),
) -> dict[str, object]:
    return _post_payload(db, _post_or_404(db, post_id), _uid(user))


@router.delete("/social/posts/{post_id}")
def delete_post(
    post_id: str,
    user: dict[str, str | None] = Depends(current_user),
    db: Session = Depends(get_db),
) -> dict[str, bool]:
    post = db.get(Post, post_id)
    if post is None:
        raise HTTPException(status_code=404, detail="Post not found.")
    if post.user_id != _uid(user):
        raise HTTPException(status_code=403, detail="You can only delete your own posts.")
    stored_paths = [
        _stored_media_path(item)
        for item in db.scalars(select(PostMedia).where(PostMedia.post_id == post_id)).all()
    ]
    db.delete(post)
    db.commit()
    for stored_path in stored_paths:
        try:
            stored_path.unlink(missing_ok=True)
        except OSError:
            pass
    return {"success": True}


def _stored_media_path(media: PostMedia | ProfileAvatar) -> Path:
    path = (PRIVATE_MEDIA_DIR / media.storage_key).resolve()
    try:
        path.relative_to(PRIVATE_MEDIA_DIR)
    except ValueError as error:
        raise HTTPException(status_code=500, detail="Stored media path is invalid.") from error
    return path


def _users_blocked(db: Session, first_id: str, second_id: str) -> bool:
    return db.scalar(
        select(UserBlock.blocker_id).where(
            ((UserBlock.blocker_id == first_id) & (UserBlock.blocked_id == second_id))
            | ((UserBlock.blocker_id == second_id) & (UserBlock.blocked_id == first_id))
        )
    ) is not None


def _enforce_rate_limit(
    db: Session,
    user_id: str,
    action: str,
    *,
    limit: int,
    window_seconds: int = 60,
) -> None:
    """Atomically count authenticated writes in shared SQLite/MySQL buckets."""
    now = int(time.time())
    window_start = now - now % window_seconds
    db.query(RateLimitBucket).filter(
        RateLimitBucket.user_id == user_id,
        RateLimitBucket.action == action,
        RateLimitBucket.window_start < window_start - 86_400,
    ).delete(synchronize_session=False)

    values = {
        "user_id": user_id,
        "action": action,
        "window_start": window_start,
        "request_count": 1,
    }
    if db.bind is None:
        raise RuntimeError("Rate limiting requires a configured database.")
    if db.bind.dialect.name == "sqlite":
        statement = sqlite_insert(RateLimitBucket).values(**values).on_conflict_do_update(
            index_elements=["user_id", "action", "window_start"],
            set_={"request_count": RateLimitBucket.request_count + 1},
        )
        db.execute(statement)
    elif db.bind.dialect.name == "mysql":
        statement = mysql_insert(RateLimitBucket).values(**values).on_duplicate_key_update(
            request_count=RateLimitBucket.request_count + 1,
        )
        db.execute(statement)
    else:
        bucket = db.get(RateLimitBucket, (user_id, action, window_start))
        if bucket is None:
            bucket = RateLimitBucket(**values)
            db.add(bucket)
        else:
            bucket.request_count += 1

    count = db.scalar(
        select(RateLimitBucket.request_count).where(
            RateLimitBucket.user_id == user_id,
            RateLimitBucket.action == action,
            RateLimitBucket.window_start == window_start,
        )
    ) or 0
    db.commit()
    if count > limit:
        retry_after = max(1, window_start + window_seconds - now)
        raise HTTPException(
            status_code=429,
            detail="Too many requests. Please wait and try again.",
            headers={"Retry-After": str(retry_after)},
        )


@router.post("/social/posts/{post_id}/media", status_code=status.HTTP_201_CREATED)
async def upload_post_media(
    post_id: str,
    file: UploadFile = File(...),
    user: dict[str, str | None] = Depends(current_user),
    db: Session = Depends(get_db),
) -> dict[str, object]:
    post = db.get(Post, post_id)
    if post is None:
        raise HTTPException(status_code=404, detail="Post not found.")
    if post.user_id != _uid(user):
        raise HTTPException(status_code=403, detail="You can only attach media to your own posts.")
    if db.scalar(select(PostMedia.id).where(PostMedia.post_id == post_id)) is not None:
        raise HTTPException(status_code=409, detail="This post already has an attachment.")
    _enforce_rate_limit(db, _uid(user), "social-media-upload", limit=8)

    filename = Path(file.filename or "upload").name
    extension = Path(filename).suffix.lower()
    if extension in SOCIAL_IMAGE_EXTENSIONS:
        media_type = "image"
        max_bytes = MAX_SOCIAL_IMAGE_BYTES
    elif extension in SOCIAL_VIDEO_EXTENSIONS:
        media_type = "video"
        max_bytes = MAX_SOCIAL_VIDEO_BYTES
    else:
        raise HTTPException(status_code=415, detail="Use a JPG, PNG, MP4, MOV, AVI, MKV, or WebM file.")

    content = await file.read(max_bytes + 1)
    if not content or len(content) > max_bytes:
        raise HTTPException(status_code=413, detail="The selected file is empty or exceeds the upload limit.")

    if media_type == "image":
        try:
            with Image.open(BytesIO(content)) as image:
                if image.format not in {"JPEG", "PNG"} or image.width * image.height > 40_000_000:
                    raise HTTPException(status_code=415, detail="The image format or dimensions are not supported.")
                image.verify()
        except (UnidentifiedImageError, OSError) as error:
            raise HTTPException(status_code=415, detail="The image file is invalid.") from error
    else:
        valid_video = (
            (extension in {".mp4", ".mov"} and len(content) >= 12 and content[4:8] == b"ftyp")
            or (extension == ".avi" and content.startswith(b"RIFF") and content[8:12] == b"AVI ")
            or (extension in {".mkv", ".webm"} and content.startswith(bytes.fromhex("1a45dfa3")))
        )
        if not valid_video:
            raise HTTPException(status_code=415, detail="The video file signature does not match its extension.")

    media_id = str(uuid4())
    storage_key = f"{media_id}{extension}"
    PRIVATE_MEDIA_DIR.mkdir(parents=True, exist_ok=True)
    stored_path = (PRIVATE_MEDIA_DIR / storage_key).resolve()
    try:
        stored_path.relative_to(PRIVATE_MEDIA_DIR)
    except ValueError as error:
        raise HTTPException(status_code=400, detail="Invalid media filename.") from error
    stored_path.write_bytes(content)

    media = PostMedia(
        id=media_id,
        post_id=post_id,
        media_type=media_type,
        filename=filename[:255],
        storage_key=storage_key,
        sha256=hashlib.sha256(content).hexdigest(),
    )
    db.add(media)
    try:
        db.commit()
    except IntegrityError as error:
        db.rollback()
        stored_path.unlink(missing_ok=True)
        raise HTTPException(status_code=409, detail="This post already has an attachment.") from error
    return {
        "id": media.id,
        "media_type": media.media_type,
        "filename": media.filename,
        "url": f"/social/media/{media.id}",
    }


@router.get("/social/media/{media_id}")
def get_post_media(
    media_id: str,
    user: dict[str, str | None] = Depends(current_user),
    db: Session = Depends(get_db),
) -> FileResponse:
    media = db.get(PostMedia, media_id)
    if media is None:
        raise HTTPException(status_code=404, detail="Media not found.")
    post = db.get(Post, media.post_id)
    if post is None:
        raise HTTPException(status_code=404, detail="Media not found.")
    viewer_id = _uid(user)
    if _users_blocked(db, viewer_id, post.user_id):
        raise HTTPException(status_code=404, detail="Media not found.")
    path = _stored_media_path(media)
    if not path.is_file():
        raise HTTPException(status_code=404, detail="Media file not found.")
    content_type = {
        ".jpg": "image/jpeg",
        ".jpeg": "image/jpeg",
        ".png": "image/png",
        ".mp4": "video/mp4",
        ".mov": "video/quicktime",
        ".avi": "video/x-msvideo",
        ".mkv": "video/x-matroska",
        ".webm": "video/webm",
    }.get(path.suffix.lower(), "application/octet-stream")
    return FileResponse(
        path,
        media_type=content_type,
        filename=media.filename,
        content_disposition_type="inline",
        headers={"Cache-Control": "private, no-store", "X-Content-Type-Options": "nosniff"},
    )


@router.post("/social/posts/{post_id}/like")
def like_post(
    post_id: str,
    user: dict[str, str | None] = Depends(current_user),
    db: Session = Depends(get_db),
) -> dict[str, bool]:
    post = db.get(Post, post_id)
    if post is None:
        raise HTTPException(status_code=404, detail="Post not found.")
    viewer_id = _uid(user)
    if db.get(PostLike, (viewer_id, post_id)) is None:
        db.add(PostLike(user_id=viewer_id, post_id=post_id))
        _notify(db, recipient=post.user_id, actor=viewer_id, kind="like", post_id=post_id)
        db.commit()
    return {"liked": True}


@router.delete("/social/posts/{post_id}/like")
def unlike_post(
    post_id: str,
    user: dict[str, str | None] = Depends(current_user),
    db: Session = Depends(get_db),
) -> dict[str, bool]:
    if db.get(Post, post_id) is None:
        raise HTTPException(status_code=404, detail="Post not found.")
    db.query(PostLike).filter_by(user_id=_uid(user), post_id=post_id).delete()
    db.commit()
    return {"liked": False}


@router.post("/social/posts/{post_id}/bookmark")
def bookmark_post(
    post_id: str,
    user: dict[str, str | None] = Depends(current_user),
    db: Session = Depends(get_db),
) -> dict[str, bool]:
    if db.get(Post, post_id) is None:
        raise HTTPException(status_code=404, detail="Post not found.")
    viewer_id = _uid(user)
    if db.get(Bookmark, (viewer_id, post_id)) is None:
        db.add(Bookmark(user_id=viewer_id, post_id=post_id))
        db.commit()
    return {"bookmarked": True}


@router.delete("/social/posts/{post_id}/bookmark")
def unbookmark_post(
    post_id: str,
    user: dict[str, str | None] = Depends(current_user),
    db: Session = Depends(get_db),
) -> dict[str, bool]:
    if db.get(Post, post_id) is None:
        raise HTTPException(status_code=404, detail="Post not found.")
    db.query(Bookmark).filter_by(user_id=_uid(user), post_id=post_id).delete()
    db.commit()
    return {"bookmarked": False}


@router.get("/social/bookmarks", response_model=list[PostView])
def get_bookmarks(
    user: dict[str, str | None] = Depends(current_user),
    db: Session = Depends(get_db),
) -> list[dict[str, object]]:
    viewer_id = _uid(user)
    posts = db.scalars(
        select(Post)
        .join(Bookmark, Bookmark.post_id == Post.id)
        .where(Bookmark.user_id == viewer_id)
        .options(joinedload(Post.author), joinedload(Post.community))
        .order_by(Bookmark.created_at.desc())
    ).unique().all()
    return [_post_payload(db, post, viewer_id) for post in posts]


@router.get("/social/posts/{post_id}/comments")
def get_comments(
    post_id: str,
    limit: int = Query(default=50, ge=1, le=100),
    user: dict[str, str | None] = Depends(current_user),
    db: Session = Depends(get_db),
) -> list[dict[str, object]]:
    if db.get(Post, post_id) is None:
        raise HTTPException(status_code=404, detail="Post not found.")
    comments = db.scalars(
        select(Comment).options(joinedload(Comment.post), joinedload(Comment.post, Post.author))
        .where(Comment.post_id == post_id).order_by(Comment.created_at.asc()).limit(limit)
    ).unique().all()
    result = []
    for comment in comments:
        author = db.get(User, comment.user_id)
        parent = db.get(Comment, comment.parent_comment_id) if comment.parent_comment_id else None
        parent_author = db.get(User, parent.user_id) if parent is not None else None
        result.append({
            "id": comment.id,
            "body": comment.body,
            "created_at": comment.created_at,
            "author": {"id": author.id, "name": author.name, "avatar_url": author.avatar_url},
            "parent_comment_id": comment.parent_comment_id,
            "reply_to": parent_author.name if parent_author is not None else None,
        })
    return result


@router.post("/social/posts/{post_id}/comments", status_code=status.HTTP_201_CREATED)
def create_comment(
    post_id: str,
    body: CreateComment,
    user: dict[str, str | None] = Depends(current_user),
    db: Session = Depends(get_db),
) -> dict[str, object]:
    post = db.get(Post, post_id)
    if post is None:
        raise HTTPException(status_code=404, detail="Post not found.")
    author_id = _uid(user)
    comment = Comment(
        id=str(uuid4()),
        post_id=post_id,
        user_id=author_id,
        parent_comment_id=body.parent_comment_id,
        body=body.body.strip(),
    )
    if not comment.body:
        raise HTTPException(status_code=422, detail="A comment cannot be blank.")
    parent = None
    if body.parent_comment_id is not None:
        parent = db.get(Comment, body.parent_comment_id)
        if parent is None or parent.post_id != post_id:
            raise HTTPException(status_code=404, detail="The comment to reply to was not found.")
        if parent.parent_comment_id is not None:
            raise HTTPException(status_code=422, detail="Replies must target a top-level comment.")
    _enforce_rate_limit(db, author_id, "social-comment", limit=30)
    db.add(comment)
    _notify(db, recipient=post.user_id, actor=author_id, kind="comment", post_id=post_id)
    if parent is not None and parent.user_id != post.user_id:
        _notify(db, recipient=parent.user_id, actor=author_id, kind="comment", post_id=post_id)
    db.commit()
    return {
        "id": comment.id,
        "body": comment.body,
        "created_at": comment.created_at,
        "author": user,
        "parent_comment_id": comment.parent_comment_id,
    }


@router.delete("/social/comments/{comment_id}")
def delete_comment(
    comment_id: str,
    user: dict[str, str | None] = Depends(current_user),
    db: Session = Depends(get_db),
) -> dict[str, bool]:
    comment = db.get(Comment, comment_id)
    if comment is None:
        raise HTTPException(status_code=404, detail="Comment not found.")
    if comment.user_id != _uid(user):
        raise HTTPException(status_code=403, detail="You can only delete your own comments.")
    db.delete(comment)
    db.commit()
    return {"success": True}


@router.post("/users/{target_id}/follow")
def follow_user(
    target_id: str,
    user: dict[str, str | None] = Depends(current_user),
    db: Session = Depends(get_db),
) -> dict[str, bool]:
    actor_id = _uid(user)
    if target_id == actor_id:
        raise HTTPException(status_code=400, detail="You cannot follow your own account.")
    target = db.get(User, target_id)
    if target is None:
        raise HTTPException(status_code=404, detail="User not found.")
    if db.get(UserBlock, (target_id, actor_id)) is not None:
        raise HTTPException(status_code=403, detail="This user does not accept follows from this account.")
    if db.get(Follow, (actor_id, target_id)) is None:
        db.add(Follow(follower_id=actor_id, followed_id=target_id))
        _notify(db, recipient=target_id, actor=actor_id, kind="follow")
        db.commit()
    return {"following": True}


@router.get("/users/search")
def search_users(
    q: str = Query(min_length=2, max_length=80),
    limit: int = Query(default=20, ge=1, le=50),
    user: dict[str, str | None] = Depends(current_user),
    db: Session = Depends(get_db),
) -> list[dict[str, object]]:
    viewer_id = _uid(user)
    term = q.strip()
    if len(term) < 2:
        return []
    matches = db.scalars(
        select(User)
        .where(User.id != viewer_id, User.name.ilike(f"%{term}%"))
        .where(User.id.not_in(
            select(AccountSettings.user_id).where(AccountSettings.show_in_creator_search.is_(False))
        ))
        .where(User.id.not_in(select(UserBlock.blocked_id).where(UserBlock.blocker_id == viewer_id)))
        .where(User.id.not_in(select(UserBlock.blocker_id).where(UserBlock.blocked_id == viewer_id)))
        .order_by(User.name.asc())
        .limit(limit)
    ).all()
    result = []
    for account in matches:
        followers = db.scalar(
            select(func.count()).select_from(Follow).where(Follow.followed_id == account.id)
        ) or 0
        result.append({
            "id": account.id,
            "name": account.name,
            "bio": account.bio,
            "avatar_url": account.avatar_url,
            "followers_count": followers,
            "is_following": db.get(Follow, (viewer_id, account.id)) is not None,
        })
    return result


@router.delete("/users/{target_id}/follow")
def unfollow_user(
    target_id: str,
    user: dict[str, str | None] = Depends(current_user),
    db: Session = Depends(get_db),
) -> dict[str, bool]:
    db.query(Follow).filter_by(follower_id=_uid(user), followed_id=target_id).delete()
    db.commit()
    return {"following": False}


@router.post("/users/{target_id}/block")
def block_user(
    target_id: str,
    user: dict[str, str | None] = Depends(current_user),
    db: Session = Depends(get_db),
) -> dict[str, bool]:
    blocker_id = _uid(user)
    if target_id == blocker_id:
        raise HTTPException(status_code=400, detail="You cannot block your own account.")
    if db.get(User, target_id) is None:
        raise HTTPException(status_code=404, detail="User not found.")
    _enforce_rate_limit(db, blocker_id, "user-block", limit=20, window_seconds=3600)
    if db.get(UserBlock, (blocker_id, target_id)) is None:
        db.add(UserBlock(blocker_id=blocker_id, blocked_id=target_id))
    db.query(Follow).filter(
        ((Follow.follower_id == blocker_id) & (Follow.followed_id == target_id))
        | ((Follow.follower_id == target_id) & (Follow.followed_id == blocker_id))
    ).delete(synchronize_session=False)
    db.commit()
    return {"blocked": True}


@router.delete("/users/{target_id}/block")
def unblock_user(
    target_id: str,
    user: dict[str, str | None] = Depends(current_user),
    db: Session = Depends(get_db),
) -> dict[str, bool]:
    db.query(UserBlock).filter_by(blocker_id=_uid(user), blocked_id=target_id).delete()
    db.commit()
    return {"blocked": False}


@router.get("/users/blocked")
def list_blocked_users(
    user: dict[str, str | None] = Depends(current_user),
    db: Session = Depends(get_db),
) -> list[dict[str, object]]:
    viewer_id = _uid(user)
    rows = db.execute(
        select(User, UserBlock.created_at)
        .join(UserBlock, UserBlock.blocked_id == User.id)
        .where(UserBlock.blocker_id == viewer_id)
        .order_by(UserBlock.created_at.desc())
    ).all()
    return [
        {
            "id": account.id,
            "name": account.name,
            "bio": account.bio,
            "avatar_url": account.avatar_url,
            "blocked_at": blocked_at,
        }
        for account, blocked_at in rows
    ]


@router.post("/social/posts/{post_id}/report", status_code=status.HTTP_201_CREATED)
def report_post(
    post_id: str,
    body: ContentReportRequest,
    user: dict[str, str | None] = Depends(current_user),
    db: Session = Depends(get_db),
) -> dict[str, str]:
    if db.get(Post, post_id) is None:
        raise HTTPException(status_code=404, detail="Post not found.")
    _enforce_rate_limit(db, _uid(user), "content-report", limit=10, window_seconds=3600)
    report = ContentReport(
        id=str(uuid4()), reporter_id=_uid(user), post_id=post_id,
        reason=body.reason, details=body.details.strip() if body.details else None,
    )
    db.add(report)
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(status_code=409, detail="You have already reported this post.") from None
    return {"id": report.id, "status": "open"}


@router.post("/social/comments/{comment_id}/report", status_code=status.HTTP_201_CREATED)
def report_comment(
    comment_id: str,
    body: ContentReportRequest,
    user: dict[str, str | None] = Depends(current_user),
    db: Session = Depends(get_db),
) -> dict[str, str]:
    if db.get(Comment, comment_id) is None:
        raise HTTPException(status_code=404, detail="Comment not found.")
    _enforce_rate_limit(db, _uid(user), "content-report", limit=10, window_seconds=3600)
    report = ContentReport(
        id=str(uuid4()), reporter_id=_uid(user), comment_id=comment_id,
        reason=body.reason, details=body.details.strip() if body.details else None,
    )
    db.add(report)
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(status_code=409, detail="You have already reported this comment.") from None
    return {"id": report.id, "status": "open"}


@router.get("/moderation/reports")
def list_moderation_reports(
    report_status: Literal["open", "dismissed", "actioned"] = Query(default="open", alias="status"),
    limit: int = Query(default=50, ge=1, le=100),
    user: dict[str, str | None] = Depends(current_user),
    db: Session = Depends(get_db),
) -> list[dict[str, object]]:
    _require_moderator(user)
    _enforce_rate_limit(db, _uid(user), "moderation-read", limit=120)
    reports = db.scalars(
        select(ContentReport)
        .where(ContentReport.status == report_status)
        .order_by(ContentReport.created_at.asc())
        .limit(limit)
    ).all()
    result = []
    for report in reports:
        post = db.get(Post, report.post_id) if report.post_id else None
        comment = db.get(Comment, report.comment_id) if report.comment_id else None
        target = post or comment
        author = db.get(User, target.user_id) if target is not None else None
        result.append({
            "id": report.id,
            "content_type": "post" if post is not None else "comment",
            "content_id": report.post_id or report.comment_id,
            "content": post.body if post is not None else comment.body if comment is not None else "Content was removed.",
            "author_name": author.name if author is not None else "Unknown user",
            "reason": report.reason,
            "details": report.details,
            "status": report.status,
            "created_at": report.created_at,
        })
    return result


@router.post("/moderation/reports/{report_id}/review")
def review_moderation_report(
    report_id: str,
    body: ModerationReviewRequest,
    user: dict[str, str | None] = Depends(current_user),
    db: Session = Depends(get_db),
) -> dict[str, str]:
    _require_moderator(user)
    _enforce_rate_limit(db, _uid(user), "moderation-review", limit=60)
    report = db.get(ContentReport, report_id)
    if report is None:
        raise HTTPException(status_code=404, detail="Report not found.")
    if report.status != "open":
        raise HTTPException(status_code=409, detail="This report has already been reviewed.")
    if body.action == "dismiss":
        report.status = "dismissed"
        db.commit()
        return {"status": report.status}

    stored_paths: list[Path] = []
    if report.post_id:
        post = db.get(Post, report.post_id)
        if post is not None:
            stored_paths = [_stored_media_path(media) for media in post.media]
            comment_ids = db.scalars(select(Comment.id).where(Comment.post_id == post.id)).all()
            if comment_ids:
                comment_reports = db.scalars(
                    select(ContentReport).where(ContentReport.comment_id.in_(comment_ids))
                ).all()
                for child_report in comment_reports:
                    child_report.comment_id = None
                    child_report.status = "actioned"
            post_reports = db.scalars(
                select(ContentReport).where(ContentReport.post_id == post.id)
            ).all()
            for post_report in post_reports:
                post_report.post_id = None
                post_report.status = "actioned"
            db.flush()
            db.delete(post)
    elif report.comment_id:
        comment = db.get(Comment, report.comment_id)
        if comment is not None:
            comment_reports = db.scalars(
                select(ContentReport).where(ContentReport.comment_id == comment.id)
            ).all()
            for comment_report in comment_reports:
                comment_report.comment_id = None
                comment_report.status = "actioned"
            db.flush()
            db.delete(comment)
    else:
        report.status = "actioned"
    db.commit()
    for stored_path in stored_paths:
        try:
            stored_path.unlink(missing_ok=True)
        except OSError:
            pass
    return {"status": "actioned"}


@router.get("/communities")
def list_communities(
    search: str = Query(default="", max_length=100),
    user: dict[str, str | None] = Depends(current_user),
    db: Session = Depends(get_db),
) -> list[dict[str, object]]:
    viewer_id = _uid(user)
    query = select(Community)
    term = search.strip()
    if term:
        query = query.where(Community.name.ilike(f"%{term}%"))
    communities = db.scalars(query.order_by(Community.name.asc()).limit(100)).all()
    result = []
    for community in communities:
        members = db.scalar(
            select(func.count()).select_from(CommunityMember).where(CommunityMember.community_id == community.id)
        ) or 0
        result.append({
            "id": community.id,
            "slug": community.slug,
            "name": community.name,
            "description": community.description,
            "members_count": members,
            "joined": db.get(CommunityMember, (community.id, viewer_id)) is not None,
        })
    return result


@router.post("/communities", status_code=status.HTTP_201_CREATED)
def create_community(
    body: CreateCommunity,
    user: dict[str, str | None] = Depends(current_user),
    db: Session = Depends(get_db),
) -> dict[str, object]:
    slug_base = re.sub(r"[^a-z0-9]+", "-", body.name.casefold()).strip("-")[:70] or "community"
    slug = slug_base
    while db.scalar(select(Community.id).where(Community.slug == slug)) is not None:
        slug = f"{slug_base}-{secrets.token_hex(3)}"
    community = Community(id=str(uuid4()), slug=slug, name=body.name.strip(), description=body.description.strip())
    db.add(community)
    db.flush()
    db.add(CommunityMember(community_id=community.id, user_id=_uid(user)))
    db.commit()
    return {"id": community.id, "slug": community.slug, "name": community.name, "description": community.description, "members_count": 1, "joined": True}


@router.post("/communities/{community_id}/join")
def join_community(
    community_id: str,
    user: dict[str, str | None] = Depends(current_user),
    db: Session = Depends(get_db),
) -> dict[str, bool]:
    if db.get(Community, community_id) is None:
        raise HTTPException(status_code=404, detail="Community not found.")
    membership = (community_id, _uid(user))
    if db.get(CommunityMember, membership) is None:
        db.add(CommunityMember(community_id=membership[0], user_id=membership[1]))
        db.commit()
    return {"joined": True}


@router.delete("/communities/{community_id}/join")
def leave_community(
    community_id: str,
    user: dict[str, str | None] = Depends(current_user),
    db: Session = Depends(get_db),
) -> dict[str, bool]:
    db.query(CommunityMember).filter_by(community_id=community_id, user_id=_uid(user)).delete()
    db.commit()
    return {"joined": False}


@router.get("/communities/{community_id}/feed", response_model=list[PostView])
def community_feed(
    community_id: str,
    sort: Literal["latest", "popular"] = "latest",
    limit: int = Query(default=20, ge=1, le=50),
    user: dict[str, str | None] = Depends(current_user),
    db: Session = Depends(get_db),
) -> list[dict[str, object]]:
    if db.get(Community, community_id) is None:
        raise HTTPException(status_code=404, detail="Community not found.")
    viewer_id = _uid(user)
    blocked_by_viewer = select(UserBlock.blocked_id).where(UserBlock.blocker_id == viewer_id)
    blocked_viewer = select(UserBlock.blocker_id).where(UserBlock.blocked_id == viewer_id)
    query = (
        select(Post)
        .where(Post.community_id == community_id)
        .where(Post.user_id.not_in(blocked_by_viewer))
        .where(Post.user_id.not_in(blocked_viewer))
        .options(joinedload(Post.author), joinedload(Post.community))
    )
    if sort == "popular":
        likes = (
            select(PostLike.post_id.label("post_id"), func.count().label("likes"))
            .group_by(PostLike.post_id)
            .subquery()
        )
        query = query.outerjoin(likes, Post.id == likes.c.post_id).order_by(
            func.coalesce(likes.c.likes, 0).desc(), Post.created_at.desc()
        )
    else:
        query = query.order_by(Post.created_at.desc())
    posts = db.scalars(query.limit(limit)).unique().all()
    return [_post_payload(db, post, viewer_id) for post in posts]


@router.get("/notifications")
def get_notifications(
    limit: int = Query(default=50, ge=1, le=100),
    user: dict[str, str | None] = Depends(current_user),
    db: Session = Depends(get_db),
) -> list[dict[str, object]]:
    viewer_id = _uid(user)
    blocked_actor_ids = select(UserBlock.blocker_id).where(UserBlock.blocked_id == viewer_id)
    blocked_target_ids = select(UserBlock.blocked_id).where(UserBlock.blocker_id == viewer_id)
    notifications = db.scalars(
        select(Notification).where(Notification.user_id == viewer_id)
        .where(Notification.actor_id.is_(None) | Notification.actor_id.not_in(blocked_actor_ids))
        .where(Notification.actor_id.is_(None) | Notification.actor_id.not_in(blocked_target_ids))
        .order_by(Notification.created_at.desc()).limit(limit)
    ).all()
    result = []
    for item in notifications:
        actor = db.get(User, item.actor_id) if item.actor_id else None
        result.append({
            "id": item.id,
            "kind": item.kind,
            "post_id": item.post_id,
            "is_read": item.is_read,
            "created_at": item.created_at,
            "actor": {"id": actor.id, "name": actor.name} if actor else None,
        })
    return result


@router.post("/notifications/{notification_id}/read")
def mark_notification_read(
    notification_id: str,
    user: dict[str, str | None] = Depends(current_user),
    db: Session = Depends(get_db),
) -> dict[str, bool]:
    item = db.get(Notification, notification_id)
    if item is None or item.user_id != _uid(user):
        raise HTTPException(status_code=404, detail="Notification not found.")
    item.is_read = True
    db.commit()
    return {"is_read": True}
