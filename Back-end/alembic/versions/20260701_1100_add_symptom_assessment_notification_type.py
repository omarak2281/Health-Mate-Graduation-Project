"""Add symptom assessment notification type.

Revision ID: phase7_notify_bp_link
Revises: phase6_symptom_checker
Create Date: 2026-07-01 11:00:00.000000
"""
from __future__ import annotations

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


revision = "phase7_notify_bp_link"
down_revision = "phase6_symptom_checker"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute(
        "ALTER TYPE notificationtype ADD VALUE IF NOT EXISTS 'SYMPTOM_ASSESSMENT_ALERT'"
    )
    op.add_column(
        "assessments",
        sa.Column("source_vital_id", postgresql.UUID(as_uuid=True), nullable=True),
    )
    op.create_foreign_key(
        "fk_assessments_source_vital_id_vital_signs",
        "assessments",
        "vital_signs",
        ["source_vital_id"],
        ["id"],
        ondelete="SET NULL",
    )
    op.create_index(
        "ix_assessments_source_vital_id",
        "assessments",
        ["source_vital_id"],
        unique=False,
    )


def downgrade() -> None:
    # PostgreSQL cannot safely remove enum values in-place. Keeping the value is
    # harmless and avoids rewriting existing notification rows.
    op.drop_index("ix_assessments_source_vital_id", table_name="assessments")
    op.drop_constraint(
        "fk_assessments_source_vital_id_vital_signs",
        "assessments",
        type_="foreignkey",
    )
    op.drop_column("assessments", "source_vital_id")
