"""add call sessions table

Revision ID: d9e0f1a2b3c4
Revises: c8d9e0f1a2b3
Create Date: 2026-07-05 12:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy import inspect
from sqlalchemy.dialects import postgresql


revision: str = "d9e0f1a2b3c4"
down_revision: Union[str, None] = "c8d9e0f1a2b3"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    call_type = postgresql.ENUM("AUDIO", "VIDEO", name="calltype", create_type=False)
    call_status = postgresql.ENUM(
        "IDLE",
        "RINGING",
        "IN_CALL",
        "ENDED",
        "REJECTED",
        "BUSY",
        "MISSED",
        "FAILED",
        name="callstatus",
        create_type=False,
    )
    call_type.create(op.get_bind(), checkfirst=True)
    call_status.create(op.get_bind(), checkfirst=True)

    with op.get_context().autocommit_block():
        op.execute("ALTER TYPE callstatus ADD VALUE IF NOT EXISTS 'BUSY'")
        op.execute("ALTER TYPE callstatus ADD VALUE IF NOT EXISTS 'MISSED'")
        op.execute("ALTER TYPE callstatus ADD VALUE IF NOT EXISTS 'FAILED'")

    if inspect(op.get_bind()).has_table("call_sessions"):
        return

    op.create_table(
        "call_sessions",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("caller_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("callee_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("call_type", call_type, nullable=False),
        sa.Column("status", call_status, nullable=False),
        sa.Column("offer_sdp", sa.String(length=5000), nullable=True),
        sa.Column("answer_sdp", sa.String(length=5000), nullable=True),
        sa.Column("duration_seconds", sa.Integer(), nullable=True),
        sa.Column("started_at", sa.DateTime(), nullable=True),
        sa.Column("answered_at", sa.DateTime(), nullable=True),
        sa.Column("ended_at", sa.DateTime(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False),
    )
    op.create_index("ix_call_sessions_caller_id", "call_sessions", ["caller_id"])
    op.create_index("ix_call_sessions_callee_id", "call_sessions", ["callee_id"])
    op.create_index("ix_call_sessions_status", "call_sessions", ["status"])


def downgrade() -> None:
    op.drop_index("ix_call_sessions_status", table_name="call_sessions")
    op.drop_index("ix_call_sessions_callee_id", table_name="call_sessions")
    op.drop_index("ix_call_sessions_caller_id", table_name="call_sessions")
    op.drop_table("call_sessions")
    postgresql.ENUM(name="callstatus").drop(op.get_bind(), checkfirst=True)
    postgresql.ENUM(name="calltype").drop(op.get_bind(), checkfirst=True)
