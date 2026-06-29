"""Create initial tables

Revision ID: 001_initial
Revises: 
Create Date: 2026-01-06 17:30:00

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = '001_initial'
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Create all initial tables"""
    # This is a placeholder - tables are auto-created by SQLAlchemy in development
    # For production, use: alembic revision --autogenerate -m "description"
    pass


def downgrade() -> None:
    """Drop all tables"""
    pass
