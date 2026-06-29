"""add birth_date and gender to users

Revision ID: 004_user_profile_fields
Revises: 003_add_family
Create Date: 2026-01-20 01:18:00.000000

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = '004_user_profile_fields'
down_revision = '003_add_family'
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Add birth_date and gender columns
    op.add_column('users', sa.Column('birth_date', sa.String(length=50), nullable=True))
    op.add_column('users', sa.Column('gender', sa.String(length=20), nullable=True))


def downgrade() -> None:
    # Remove columns
    op.drop_column('users', 'gender')
    op.drop_column('users', 'birth_date')
