"""add family to contact_type enum

Revision ID: 003_add_family
Revises: 002_firebase_auth
Create Date: 2026-01-13 18:30:00.000000

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = '003_add_family'
down_revision = '002_firebase_auth'
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Add 'family' to ContactType enum
    # PostgreSQL doesn't allow ALTER TYPE ... ADD VALUE in a transaction until PG 12+, 
    # but Alembic can handle it if we use autocommit.
    # However, for simplicity in dev/production, we use this:
    with op.get_context().autocommit_block():
        op.execute("ALTER TYPE contacttype ADD VALUE IF NOT EXISTS 'family'")


def downgrade() -> None:
    # Removing an enum value is not directly supported in PostgreSQL ALTER TYPE.
    # Usually requires recreating the type or just leaving it.
    pass
