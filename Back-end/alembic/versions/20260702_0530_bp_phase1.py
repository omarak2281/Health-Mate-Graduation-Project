"""bp_phase1

Revision ID: bp_phase1
Revises: phase7_notify_bp_link
Create Date: 2026-07-02 05:30:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql
import sqlalchemy.dialects.postgresql as pg

# revision identifiers, used by Alembic.
revision = 'bp_phase1'
down_revision = 'phase7_notify_bp_link'
branch_labels = None
depends_on = None


def upgrade() -> None:
    # 1. Update vital_signs table
    measurement_status_enum = sa.Enum('completed', 'completed_pending_bp', 'rejected', name='measurementstatus')
    measurement_status_enum.create(op.get_bind(), checkfirst=True)
    
    op.add_column('vital_signs', sa.Column('measurement_status', measurement_status_enum, nullable=False, server_default='completed'))
    op.add_column('vital_signs', sa.Column('device_id', sa.String(length=100), nullable=True))
    
    op.alter_column('vital_signs', 'systolic', existing_type=sa.Integer(), nullable=True)
    op.alter_column('vital_signs', 'diastolic', existing_type=sa.Integer(), nullable=True)
    
    # 2. Update patient_caregiver_links table
    op.add_column('patient_caregiver_links', sa.Column('is_primary', sa.Boolean(), nullable=False, server_default=sa.text('false')))
    op.create_index(
        'uq_patient_active_primary_caregiver',
        'patient_caregiver_links',
        ['patient_id'],
        unique=True,
        postgresql_where=sa.text('is_primary = true AND is_active = true')
    )
    
    # 3. Create bp_alert_cooldowns table
    op.create_table(
        'bp_alert_cooldowns',
        sa.Column('patient_id', pg.UUID(as_uuid=True), sa.ForeignKey('users.id', ondelete='CASCADE'), primary_key=True),
        sa.Column('risk_level', sa.String(length=50), primary_key=True),
        sa.Column('last_sent_at', sa.DateTime(), nullable=False, server_default=sa.text('now()')),
    )


def downgrade() -> None:
    op.drop_table('bp_alert_cooldowns')
    
    op.drop_index('uq_patient_active_primary_caregiver', table_name='patient_caregiver_links')
    op.drop_column('patient_caregiver_links', 'is_primary')
    
    op.drop_column('vital_signs', 'device_id')
    op.drop_column('vital_signs', 'measurement_status')
    measurement_status_enum = sa.Enum('completed', 'completed_pending_bp', 'rejected', name='measurementstatus')
    measurement_status_enum.drop(op.get_bind(), checkfirst=True)
    
    op.alter_column('vital_signs', 'systolic', existing_type=sa.Integer(), nullable=False)
    op.alter_column('vital_signs', 'diastolic', existing_type=sa.Integer(), nullable=False)
