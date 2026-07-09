"""add spo2 and rejection_reason to vital_signs

Revision ID: b7c8d9e0f1a2
Revises: a1b2c3d4e5f6
Create Date: 2026-07-03 15:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'b7c8d9e0f1a2'
down_revision: Union[str, None] = 'a1b2c3d4e5f6'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column('vital_signs', sa.Column('spo2', sa.Integer(), nullable=True))
    op.add_column('vital_signs', sa.Column('rejection_reason', sa.String(length=50), nullable=True))


def downgrade() -> None:
    op.drop_column('vital_signs', 'rejection_reason')
    op.drop_column('vital_signs', 'spo2')
