"""Create the social schema while retaining pre-existing authentication tables.

Revision ID: 0001_social_schema
Revises:
"""

from alembic import op
from sqlalchemy import Column, String, Text, inspect

from app import models  # noqa: F401
from app.database import Base

revision = "0001_social_schema"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    bind = op.get_bind()
    Base.metadata.create_all(bind=bind)
    inspector = inspect(bind)
    user_columns = {column["name"] for column in inspector.get_columns("users")}
    if "bio" not in user_columns:
        op.add_column("users", Column("bio", Text(), nullable=True))
    if "avatar_url" not in user_columns:
        op.add_column("users", Column("avatar_url", String(500), nullable=True))


def downgrade() -> None:
    # Keep users and revoked_tokens so existing accounts and login sessions survive.
    bind = op.get_bind()
    inspector = inspect(bind)
    tables = set(inspector.get_table_names())
    for table in (
        "reports",
        "notifications",
        "scan_reports",
        "community_members",
        "follows",
        "comments",
        "bookmarks",
        "likes",
        "post_media",
        "rate_limit_buckets",
        "profile_avatars",
        "posts",
        "communities",
    ):
        if table in tables:
            op.drop_table(table)
