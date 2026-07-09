"""add_bp_reminders_table

Revision ID: a1b2c3d4e5f6
Revises: 4183fce1d0c9
Create Date: 2026-07-03 12:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


# revision identifiers, used by Alembic.
revision: str = 'a1b2c3d4e5f6'
down_revision: Union[str, None] = '4183fce1d0c9'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        'bp_reminders',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column('patient_id', postgresql.UUID(as_uuid=True),
                  sa.ForeignKey('users.id', ondelete='CASCADE'), nullable=False),
        sa.Column('scheduled_time', sa.String(length=5), nullable=False),
        sa.Column('created_at', sa.DateTime(), nullable=False),
    )
    op.create_index('idx_bp_reminders_patient', 'bp_reminders', ['patient_id'])


def downgrade() -> None:
    op.drop_index('idx_bp_reminders_patient', table_name='bp_reminders')
    op.drop_table('bp_reminders')
