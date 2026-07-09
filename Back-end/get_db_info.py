import asyncio
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from sqlalchemy.orm import sessionmaker
from sqlalchemy import select

DATABASE_URL = "postgresql+asyncpg://healthmate:healthmate123@db:5432/healthmate_db"

async def main():
    engine = create_async_engine(DATABASE_URL, echo=False)
    async_session = sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)
    
    from app.models.registered_device import RegisteredDevice
    
    async with async_session() as session:
        res_devices = await session.execute(select(RegisteredDevice))
        devices = res_devices.scalars().all()
        print("\n=== REGISTERED DEVICES ===")
        for d in devices:
            print(f"DeviceID: {d.device_id} | Active: {d.is_active} | Last seen: {d.last_seen_at} | Leads Connected: {d.last_leads_connected} | Finger Detected: {d.last_finger_detected}")

if __name__ == "__main__":
    asyncio.run(main())
