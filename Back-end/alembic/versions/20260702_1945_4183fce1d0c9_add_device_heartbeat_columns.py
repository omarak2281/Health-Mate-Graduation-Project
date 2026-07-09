"""add_device_heartbeat_columns

Revision ID: 4183fce1d0c9
Revises: c134f0dd5d2c
Create Date: 2026-07-02 19:45:34.239376

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '4183fce1d0c9'
down_revision: Union[str, None] = 'c134f0dd5d2c'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column('registered_devices', sa.Column('last_seen_at', sa.DateTime(), nullable=True))
    op.add_column('registered_devices', sa.Column('last_leads_connected', sa.Boolean(), nullable=True))
    op.add_column('registered_devices', sa.Column('last_finger_detected', sa.Boolean(), nullable=True))


def downgrade() -> None:
    op.drop_column('registered_devices', 'last_finger_detected')
    op.drop_column('registered_devices', 'last_leads_connected')
    op.drop_column('registered_devices', 'last_seen_at')

