"""add firebase auth fields

Revision ID: 002_firebase_auth
Revises: 001_initial
Create Date: 2026-01-07 19:32:00.000000

"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision = '002_firebase_auth'
down_revision = '001_initial'
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Add firebase_uid column (nullable, unique, indexed)
    op.add_column('users', sa.Column('firebase_uid', sa.String(length=255), nullable=True))
    op.create_index('ix_users_firebase_uid', 'users', ['firebase_uid'], unique=True)
    
    # Add auth_provider enum type
    auth_provider_enum = postgresql.ENUM('email', 'google', name='authprovider', create_type=True)
    auth_provider_enum.create(op.get_bind(), checkfirst=True)
    
    # Add auth_provider column (nullable for existing users, default 'email')
    op.add_column('users', sa.Column('auth_provider', sa.Enum('email', 'google', name='authprovider'), nullable=True))
    
    # Add email_verified_at column (nullable timestamp)
    op.add_column('users', sa.Column('email_verified_at', sa.DateTime(), nullable=True))
    
    # Update existing users to have 'email' as auth_provider
    op.execute("UPDATE users SET auth_provider = 'email' WHERE auth_provider IS NULL")


def downgrade() -> None:
    # Remove columns
    op.drop_column('users', 'email_verified_at')
    op.drop_column('users', 'auth_provider')
    op.drop_index('ix_users_firebase_uid', table_name='users')
    op.drop_column('users', 'firebase_uid')
    
    # Drop enum type
    auth_provider_enum = postgresql.ENUM('email', 'google', name='authprovider')
    auth_provider_enum.drop(op.get_bind(), checkfirst=True)
