"""Store profile discoverability and in-app notification preferences."""

from alembic import op

from app.models import AccountSettings

revision = "0002_account_settings"
down_revision = "0001_social_schema"
branch_labels = None
depends_on = None


def upgrade() -> None:
    AccountSettings.__table__.create(bind=op.get_bind(), checkfirst=True)


def downgrade() -> None:
    AccountSettings.__table__.drop(bind=op.get_bind(), checkfirst=True)
