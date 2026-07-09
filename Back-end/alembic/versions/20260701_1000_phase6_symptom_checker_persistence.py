"""phase6_symptom_checker_persistence

Revision ID: phase6_symptom_checker
Revises: 6724fc79eba7
Create Date: 2026-07-01 10:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


revision: str = "phase6_symptom_checker"
down_revision: Union[str, None] = "6724fc79eba7"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "assessments",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column("assessment_type", sa.String(length=50), nullable=False, server_default="symptom_checker"),
        sa.Column("category_id", sa.String(length=100), nullable=True),
        sa.Column("duration_days", sa.Integer(), nullable=True),
        sa.Column("age_group", sa.String(length=50), nullable=True),
        sa.Column("known_conditions", postgresql.JSONB(astext_type=sa.Text()), nullable=False, server_default="[]"),
        sa.Column("vitals", postgresql.JSONB(astext_type=sa.Text()), nullable=True),
        sa.Column("top_predictions", postgresql.JSONB(astext_type=sa.Text()), nullable=False, server_default="[]"),
        sa.Column("urgency", sa.String(length=20), nullable=False),
        sa.Column("urgency_label", sa.String(length=100), nullable=False),
        sa.Column("recommended_action_code", sa.String(length=100), nullable=False),
        sa.Column("recommended_action_text", sa.Text(), nullable=False),
        sa.Column("patient_message", sa.Text(), nullable=False),
        sa.Column("caregiver_summary", sa.Text(), nullable=False),
        sa.Column("should_notify_caregiver", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("should_remeasure", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("disclaimer", sa.Text(), nullable=False),
        sa.Column("lang", sa.String(length=5), nullable=False, server_default="en"),
        sa.Column("created_at", sa.DateTime(), nullable=False, server_default=sa.text("now()")),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="SET NULL"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_assessments_category_id", "assessments", ["category_id"], unique=False)
    op.create_index("ix_assessments_created_at", "assessments", ["created_at"], unique=False)
    op.create_index("ix_assessments_urgency", "assessments", ["urgency"], unique=False)
    op.create_index("ix_assessments_user_id", "assessments", ["user_id"], unique=False)

    op.create_table(
        "assessment_symptoms",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("assessment_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("symptom_id", sa.String(length=100), nullable=False),
        sa.Column("severity", sa.Integer(), nullable=False),
        sa.ForeignKeyConstraint(["assessment_id"], ["assessments.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_assessment_symptoms_assessment_id", "assessment_symptoms", ["assessment_id"], unique=False)
    op.create_index("ix_assessment_symptoms_symptom_id", "assessment_symptoms", ["symptom_id"], unique=False)

    op.create_table(
        "red_flags_triggered",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("assessment_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("code", sa.String(length=100), nullable=False),
        sa.Column("severity", sa.Integer(), nullable=False),
        sa.ForeignKeyConstraint(["assessment_id"], ["assessments.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_red_flags_triggered_assessment_id", "red_flags_triggered", ["assessment_id"], unique=False)
    op.create_index("ix_red_flags_triggered_code", "red_flags_triggered", ["code"], unique=False)

    op.create_table(
        "chat_sessions",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column("assessment_id", postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column("state", sa.String(length=50), nullable=False, server_default="INITIAL"),
        sa.Column("seeded_from_assessment", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("lang", sa.String(length=5), nullable=False, server_default="en"),
        sa.Column("context", postgresql.JSONB(astext_type=sa.Text()), nullable=False, server_default="{}"),
        sa.Column("created_at", sa.DateTime(), nullable=False, server_default=sa.text("now()")),
        sa.Column("updated_at", sa.DateTime(), nullable=False, server_default=sa.text("now()")),
        sa.ForeignKeyConstraint(["assessment_id"], ["assessments.id"], ondelete="SET NULL"),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="SET NULL"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_chat_sessions_assessment_id", "chat_sessions", ["assessment_id"], unique=False)
    op.create_index("ix_chat_sessions_created_at", "chat_sessions", ["created_at"], unique=False)
    op.create_index("ix_chat_sessions_user_id", "chat_sessions", ["user_id"], unique=False)

    op.create_table(
        "chat_messages",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("session_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("role", sa.String(length=20), nullable=False),
        sa.Column("message", sa.Text(), nullable=False),
        sa.Column("payload", postgresql.JSONB(astext_type=sa.Text()), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False, server_default=sa.text("now()")),
        sa.ForeignKeyConstraint(["session_id"], ["chat_sessions.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_chat_messages_created_at", "chat_messages", ["created_at"], unique=False)
    op.create_index("ix_chat_messages_session_id", "chat_messages", ["session_id"], unique=False)


def downgrade() -> None:
    op.drop_index("ix_chat_messages_session_id", table_name="chat_messages")
    op.drop_index("ix_chat_messages_created_at", table_name="chat_messages")
    op.drop_table("chat_messages")
    op.drop_index("ix_chat_sessions_user_id", table_name="chat_sessions")
    op.drop_index("ix_chat_sessions_created_at", table_name="chat_sessions")
    op.drop_index("ix_chat_sessions_assessment_id", table_name="chat_sessions")
    op.drop_table("chat_sessions")
    op.drop_index("ix_red_flags_triggered_code", table_name="red_flags_triggered")
    op.drop_index("ix_red_flags_triggered_assessment_id", table_name="red_flags_triggered")
    op.drop_table("red_flags_triggered")
    op.drop_index("ix_assessment_symptoms_symptom_id", table_name="assessment_symptoms")
    op.drop_index("ix_assessment_symptoms_assessment_id", table_name="assessment_symptoms")
    op.drop_table("assessment_symptoms")
    op.drop_index("ix_assessments_user_id", table_name="assessments")
    op.drop_index("ix_assessments_urgency", table_name="assessments")
    op.drop_index("ix_assessments_created_at", table_name="assessments")
    op.drop_index("ix_assessments_category_id", table_name="assessments")
    op.drop_table("assessments")
