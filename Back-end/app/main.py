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
from app.api.v1 import auth, vitals, medications, users, iot, upload, notifications, ai, contacts, hardware, bp_reminders, calls
from app.services.redis_cache import redis_cache
from app.core.scheduler import start_scheduler, shutdown_scheduler


from app.services.ai_service import symptom_checker


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
    
    # Load AI model
    print("🔄 Loading AI model...")
    if not symptom_checker.loaded:
        success = symptom_checker.load_model()
        if success:
            print("✅ AI model loaded successfully")
        else:
            print("⚠️  Failed to load AI model")
    
    # Connect to Redis
    await redis_cache.connect()
    
    # Start Scheduler
    from app.services.scheduler_service import register_system_jobs
    start_scheduler()
    register_system_jobs()
    
    yield
    
    # Shutdown
    print("👋 Shutting down Health Mate API...")
    shutdown_scheduler()
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

import socketio
from app.core.security import decode_token

# Create Socket.io server
sio = socketio.AsyncServer(async_mode='asgi', cors_allowed_origins='*')
socket_app = socketio.ASGIApp(sio)

# Socket.io Events
def _socket_bearer_token(environ, auth):
    if isinstance(auth, dict):
        token = auth.get("token") or auth.get("access_token")
        if token:
            return token.replace("Bearer ", "")

    header = environ.get("HTTP_AUTHORIZATION") or environ.get("Authorization")
    if header and header.lower().startswith("bearer "):
        return header.split(" ", 1)[1]
    return None


async def _emit_to_user(event, data, target):
    if not target:
        return
    target = str(target)
    await sio.emit(event, data, room=f"user:{target}")
    await sio.emit(event, data, room=target)


@sio.event
async def connect(sid, environ, auth=None):
    token = _socket_bearer_token(environ, auth)
    payload = decode_token(token) if token else None
    user_id = payload.get("sub") if payload else None
    if not user_id:
        print(f"Socket rejected unauthenticated connection: {sid}")
        return False

    await sio.save_session(sid, {"user_id": str(user_id)})
    await sio.enter_room(sid, f"user:{user_id}")
    print(f"Socket connected: {sid} user={user_id}")

@sio.event
async def disconnect(sid):
    print(f"🔌 Socket disconnected: {sid}")

@sio.on('join_room')
async def join_room(sid, room):
    await sio.enter_room(sid, room)
    print(f"🏠 Player {sid} joined room: {room}")

@sio.on('make_offer')
async def make_offer(sid, data):
    # data: { target: userId, sdp, type, sessionId/callId, callerName, callerId, isVideo }
    session = await sio.get_session(sid)
    data = dict(data or {})
    data.setdefault("callerId", session.get("user_id"))
    target = data.get('target')
    if target:
        await _emit_to_user('call_offer', data, target)

@sio.on('make_answer')
async def make_answer(sid, data):
    # data: { target: userId, answer: sdp }
    target = data.get('target')
    if target:
        await _emit_to_user('call_answer', data, target)

@sio.on('send_ice_candidate')
async def send_ice_candidate(sid, data):
    target = data.get('target')
    if target:
        await _emit_to_user('ice_candidate', data, target)


@sio.on('call_declined')
async def call_declined(sid, data):
    target = data.get('target')
    if target:
        await _emit_to_user('call_declined', data, target)


@sio.on('call_ended')
async def call_ended(sid, data):
    target = data.get('target')
    if target:
        await _emit_to_user('call_ended', data, target)

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
app.include_router(hardware.router, prefix="/api/v1")
app.include_router(bp_reminders.router, prefix="/api/v1")
app.include_router(calls.router, prefix="/api/v1")

# Mount socket app
app.mount("/ws", socket_app)
app.mount("/socket.io", socket_app) # Some clients expect this path

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
