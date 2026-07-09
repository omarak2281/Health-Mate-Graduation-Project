"""bp_pipeline_fixes

Revision ID: bp_pipeline_fixes
Revises: bp_phase1
Create Date: 2026-07-02 06:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql
import sqlalchemy.dialects.postgresql as pg

# revision identifiers, used by Alembic.
revision = 'bp_pipeline_fixes'
down_revision = 'bp_phase1'
branch_labels = None
depends_on = None


def upgrade() -> None:
    # 1. Create registered_devices table
    op.create_table(
        'registered_devices',
        sa.Column('id', pg.UUID(as_uuid=True), primary_key=True),
        sa.Column('device_id', sa.String(length=100), unique=True, nullable=False, index=True),
        sa.Column('token_hash', sa.String(length=200), nullable=False),
        sa.Column('patient_id', pg.UUID(as_uuid=True), sa.ForeignKey('users.id', ondelete='CASCADE'), nullable=False, index=True),
        sa.Column('is_active', sa.Boolean(), nullable=False, server_default=sa.text('true')),
        sa.Column('registered_at', sa.DateTime(), nullable=False, server_default=sa.text('now()')),
    )

    # 2. Create patient_calibrations table
    op.create_table(
        'patient_calibrations',
        sa.Column('patient_id', pg.UUID(as_uuid=True), sa.ForeignKey('users.id', ondelete='CASCADE'), primary_key=True),
        sa.Column('sbp_scale', sa.Float(), nullable=False, server_default='1.0'),
        sa.Column('sbp_offset', sa.Float(), nullable=False, server_default='0.0'),
        sa.Column('dbp_scale', sa.Float(), nullable=False, server_default='1.0'),
        sa.Column('dbp_offset', sa.Float(), nullable=False, server_default='0.0'),
        sa.Column('samples_count', sa.Integer(), nullable=False, server_default='0'),
        sa.Column('last_calibrated_at', sa.DateTime(), nullable=True),
        sa.Column('calibration_status', sa.String(length=50), nullable=False, server_default='not_calibrated'),
    )

    # 3. Create calibration_samples table
    op.create_table(
        'calibration_samples',
        sa.Column('id', pg.UUID(as_uuid=True), primary_key=True),
        sa.Column('patient_id', pg.UUID(as_uuid=True), sa.ForeignKey('users.id', ondelete='CASCADE'), nullable=False, index=True),
        sa.Column('model_sbp', sa.Float(), nullable=False),
        sa.Column('model_dbp', sa.Float(), nullable=False),
        sa.Column('cuff_sbp', sa.Float(), nullable=False),
        sa.Column('cuff_dbp', sa.Float(), nullable=False),
        sa.Column('signal_quality', sa.Float(), nullable=False, server_default='1.0'),
        sa.Column('measured_at', sa.DateTime(), nullable=False, server_default=sa.text('now()')),
    )

    # 4. Add model & calibration columns to vital_signs
    op.add_column('vital_signs', sa.Column('model_systolic', sa.Float(), nullable=True))
    op.add_column('vital_signs', sa.Column('model_diastolic', sa.Float(), nullable=True))
    op.add_column('vital_signs', sa.Column('calibrated_systolic', sa.Float(), nullable=True))
    op.add_column('vital_signs', sa.Column('calibrated_diastolic', sa.Float(), nullable=True))
    op.add_column('vital_signs', sa.Column('calibration_status', sa.String(length=50), nullable=True))


def downgrade() -> None:
    # Remove columns from vital_signs
    op.drop_column('vital_signs', 'calibration_status')
    op.drop_column('vital_signs', 'calibrated_diastolic')
    op.drop_column('vital_signs', 'calibrated_systolic')
    op.drop_column('vital_signs', 'model_diastolic')
    op.drop_column('vital_signs', 'model_systolic')

    # Drop tables
    op.drop_table('calibration_samples')
    op.drop_table('patient_calibrations')
    op.drop_table('registered_devices')
