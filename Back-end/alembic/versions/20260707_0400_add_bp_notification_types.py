"""Add missing BP_DRIFT_ALERT and BP_MEASUREMENT_REMINDER notification types.

`NotificationType` in app/models/notification.py had these two members added
without a matching migration, so the Postgres `notificationtype` enum never
got them -- any insert with either type crashes with
"invalid input value for enum notificationtype".

Revision ID: bp_notif_types_20260707
Revises: d9e0f1a2b3c4
Create Date: 2026-07-07 04:00:00.000000
"""
from __future__ import annotations

from alembic import op


revision = "bp_notif_types_20260707"
down_revision = "d9e0f1a2b3c4"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute("ALTER TYPE notificationtype ADD VALUE IF NOT EXISTS 'BP_DRIFT_ALERT'")
    op.execute("ALTER TYPE notificationtype ADD VALUE IF NOT EXISTS 'BP_MEASUREMENT_REMINDER'")


def downgrade() -> None:
    # PostgreSQL cannot safely remove enum values in-place. Keeping the value is
    # harmless and avoids rewriting existing notification rows.
    pass
