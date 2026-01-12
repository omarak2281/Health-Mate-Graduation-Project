"""
Main FastAPI application
NO HARDCODED VALUES - all config from settings
"""

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager

from app.core.config import settings
from app.core.database import engine
from app.models import Base
from app.api.v1 import auth, vitals, medications, users, iot, upload, notifications, ai, contacts
from app.services.redis_cache import redis_cache


# Lifespan events
@asynccontextmanager
async def lifespan(app: FastAPI):
    """
    Startup and shutdown events
    """
    # Startup
    print("🚀 Starting Health Mate API...")
    
    # Create database tables (in production, use Alembic)
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    
    print("✅ Database tables created")
    print(f"✅ Environment: {settings.environment}")
    print(f"✅ IoT Mode: {settings.iot_mode}")
    
    # Connect to Redis
    await redis_cache.connect()
    
    yield
    
    # Shutdown
    print("👋 Shutting down Health Mate API...")
    await redis_cache.disconnect()
    await engine.dispose()


# Create FastAPI app
app = FastAPI(
    title=settings.app_name,
    version=settings.version,
    debug=settings.debug,
    lifespan=lifespan
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins_list,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"]
)

# Include routers
app.include_router(auth.router, prefix="/api/v1")
app.include_router(vitals.router, prefix="/api/v1")
app.include_router(medications.router, prefix="/api/v1")
app.include_router(users.router, prefix="/api/v1")
app.include_router(iot.router, prefix="/api/v1")
app.include_router(upload.router, prefix="/api/v1")
app.include_router(notifications.router, prefix="/api/v1")
app.include_router(ai.router, prefix="/api/v1")
app.include_router(contacts.router, prefix="/api/v1")

# Health check endpoint
@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "app": settings.app_name,
        "version": settings.version,
        "environment": settings.environment
    }


# Root endpoint
@app.get("/")
async def root():
    """Root endpoint"""
    return {
        "message": "Health Mate API",
        "version": settings.version,
        "docs": "/docs"
    }
