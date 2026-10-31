"""Database configuration and session management.

MySQL is selected with ``DEEPSHIELD_DATABASE_URL``. SQLite remains the
zero-configuration local development default and can reuse the existing auth
database with ``DEEPSHIELD_AUTH_DB_PATH``.
"""

from __future__ import annotations

import os
import uuid
from pathlib import Path
from typing import Generator

from sqlalchemy import create_engine
from sqlalchemy.engine import Engine
from sqlalchemy.orm import DeclarativeBase, Session, sessionmaker
from dotenv import load_dotenv


BACKEND_DIR = Path(__file__).resolve().parents[1]
load_dotenv(BACKEND_DIR / ".env", override=False)
DEFAULT_SQLITE_PATH = Path(
    os.getenv("DEEPSHIELD_AUTH_DB_PATH", str(BACKEND_DIR / "data" / "auth.sqlite3"))
).expanduser().resolve()
DATABASE_URL = os.getenv("DEEPSHIELD_DATABASE_URL", "").strip()
if not DATABASE_URL:
    DEFAULT_SQLITE_PATH.parent.mkdir(parents=True, exist_ok=True)
    DATABASE_URL = f"sqlite:///{DEFAULT_SQLITE_PATH.as_posix()}"

_engine_options: dict[str, object] = {"pool_pre_ping": True}
if DATABASE_URL.startswith("sqlite:"):
    _engine_options["connect_args"] = {"check_same_thread": False, "timeout": 10}

engine: Engine = create_engine(DATABASE_URL, **_engine_options)
SessionLocal = sessionmaker(bind=engine, autoflush=False, expire_on_commit=False)


class Base(DeclarativeBase):
    pass


def get_db() -> Generator[Session, None, None]:
    session = SessionLocal()
    try:
        yield session
    finally:
        session.close()


def initialize_database() -> None:
    """Create new tables and add nullable profile columns to legacy auth DBs."""
    from sqlalchemy import inspect, text

    from . import models  # noqa: F401  Register model metadata before create_all.

    Base.metadata.create_all(bind=engine)
    inspector = inspect(engine)
    if "users" not in inspector.get_table_names():
        return
    columns = {column["name"] for column in inspector.get_columns("users")}
    # The initial auth implementation predates SQLAlchemy and has this table.
    # These nullable additions preserve existing users without copying passwords.
    if "bio" not in columns:
        with engine.begin() as connection:
            connection.execute(text("ALTER TABLE users ADD COLUMN bio TEXT NULL"))
    if "avatar_url" not in columns:
        with engine.begin() as connection:
            connection.execute(text("ALTER TABLE users ADD COLUMN avatar_url VARCHAR(500) NULL"))

    from .models import Community

    initial_communities = (
        ("deepfake-detection", "Deepfake Detection", "Discuss media forensics, detector results, and verification methods."),
        ("ai-machine-learning", "AI & Machine Learning", "Talk about AI systems, datasets, and machine learning research."),
        ("cybersecurity", "Cybersecurity", "Share practical cybersecurity knowledge and threat awareness."),
        ("digital-awareness", "Digital Awareness", "Build stronger habits for checking and sharing online information."),
        ("online-safety", "Online Safety", "Discuss privacy, account safety, and safer online communities."),
        ("technology-discussions", "Technology Discussions", "Open discussions about technology and its impact."),
    )
    with SessionLocal() as session:
        for slug, name, description in initial_communities:
            if session.query(Community).filter_by(slug=slug).first() is None:
                session.add(Community(id=str(uuid.uuid4()), slug=slug, name=name, description=description))
        session.commit()


def is_sqlite() -> bool:
    return engine.dialect.name == "sqlite"
