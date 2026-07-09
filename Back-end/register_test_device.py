import asyncio
import bcrypt
import uuid
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from sqlalchemy.orm import sessionmaker

# Configs
DATABASE_URL = "postgresql+asyncpg://healthmate:healthmate123@localhost:5432/healthmate_db"
PATIENT_ID = "74ca4c22-ae3d-45b0-b591-e3d30f7b39e5"
DEVICE_ID = "esp8266-bp-sensor-001"
DEVICE_TOKEN = "test-token"

async def register():
    # Hash token
    hashed_token = bcrypt.hashpw(DEVICE_TOKEN.encode('utf-8'), bcrypt.gensalt()).decode('utf-8')
    print(f"Hashed token: {hashed_token}")
    
    engine = create_async_engine(DATABASE_URL, echo=True)
    async_session = sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)
    
    from app.models.registered_device import RegisteredDevice
    
    async with async_session() as session:
        # Check if already exists
        from sqlalchemy import select
        res = await session.execute(select(RegisteredDevice).where(RegisteredDevice.device_id == DEVICE_ID))
        existing = res.scalar_one_or_none()
        
        if existing:
            print("Device already registered. Updating token...")
            existing.token_hash = hashed_token
            existing.patient_id = uuid.UUID(PATIENT_ID)
            existing.is_active = True
        else:
            print("Registering new device...")
            new_device = RegisteredDevice(
                id=uuid.uuid4(),
                device_id=DEVICE_ID,
                token_hash=hashed_token,
                patient_id=uuid.UUID(PATIENT_ID),
                is_active=True
            )
            session.add(new_device)
            
        await session.commit()
        print("Successfully registered/updated test IoT device!")

if __name__ == "__main__":
    asyncio.run(register())
