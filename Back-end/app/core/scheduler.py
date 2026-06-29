from apscheduler.schedulers.asyncio import AsyncIOScheduler
from apscheduler.jobstores.sqlalchemy import SQLAlchemyJobStore
from app.core.config import settings

# Initialize APScheduler with SQLAlchemy job store to persist jobs
# Note: SQLAlchemyJobStore expects a sync driver (psycopg2) not asyncpg
sync_db_url = settings.database_url.replace("postgresql+asyncpg", "postgresql")

job_stores = {
    'default': SQLAlchemyJobStore(url=sync_db_url)
}

scheduler = AsyncIOScheduler(jobstores=job_stores, timezone="Africa/Cairo")

def start_scheduler():
    if not scheduler.running:
        scheduler.start()
        print("⏰ Async Scheduler started")

def shutdown_scheduler():
    if scheduler.running:
        scheduler.shutdown()
        print("⏰ Async Scheduler shut down")
