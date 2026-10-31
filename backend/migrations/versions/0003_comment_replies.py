"""Add replies to social post comments."""

from alembic import op
import sqlalchemy as sa

revision = "0003_comment_replies"
down_revision = "0002_account_settings"
branch_labels = None
depends_on = None


def upgrade() -> None:
    bind = op.get_bind()
    columns = {column["name"] for column in sa.inspect(bind).get_columns("comments")}
    if "parent_comment_id" in columns:
        return
    with op.batch_alter_table("comments") as batch:
        batch.add_column(sa.Column("parent_comment_id", sa.String(36), nullable=True))
        batch.create_foreign_key(
            "fk_comments_parent_comment_id_comments",
            "comments",
            ["parent_comment_id"],
            ["id"],
            ondelete="CASCADE",
        )
        batch.create_index("ix_comments_parent_comment_id", ["parent_comment_id"])


def downgrade() -> None:
    bind = op.get_bind()
    columns = {column["name"] for column in sa.inspect(bind).get_columns("comments")}
    if "parent_comment_id" not in columns:
        return
    with op.batch_alter_table("comments") as batch:
        batch.drop_index("ix_comments_parent_comment_id")
        batch.drop_constraint("fk_comments_parent_comment_id_comments", type_="foreignkey")
        batch.drop_column("parent_comment_id")
