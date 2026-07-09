"""add_calibration_drift_columns

Revision ID: c134f0dd5d2c
Revises: bp_pipeline_fixes
Create Date: 2026-07-02 18:34:10.224813

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'c134f0dd5d2c'
down_revision: Union[str, None] = 'bp_pipeline_fixes'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column('patient_calibrations', sa.Column('baseline_raw_mean_sbp', sa.Float(), nullable=True))
    op.add_column('patient_calibrations', sa.Column('baseline_raw_mean_dbp', sa.Float(), nullable=True))
    op.add_column('patient_calibrations', sa.Column('drift_flag', sa.Boolean(), nullable=False, server_default=sa.text('false')))
    op.add_column('patient_calibrations', sa.Column('drift_reason', sa.String(length=50), nullable=True))
    op.add_column('patient_calibrations', sa.Column('drift_flagged_at', sa.DateTime(), nullable=True))
    op.add_column('patient_calibrations', sa.Column('last_drift_notification_at', sa.DateTime(), nullable=True))


def downgrade() -> None:
    op.drop_column('patient_calibrations', 'last_drift_notification_at')
    op.drop_column('patient_calibrations', 'drift_flagged_at')
    op.drop_column('patient_calibrations', 'drift_reason')
    op.drop_column('patient_calibrations', 'drift_flag')
    op.drop_column('patient_calibrations', 'baseline_raw_mean_dbp')
    op.drop_column('patient_calibrations', 'baseline_raw_mean_sbp')
