import asyncio
import bcrypt
import uuid
from sqlalchemy import select
from app.core.database import AsyncSessionLocal
from app.models.user import User
from app.models.registered_device import RegisteredDevice

DEVICE_ID = "esp8266-bp-sensor-001"
DEVICE_TOKEN = "test-token"

async def register():
    # Hash token
    hashed_token = bcrypt.hashpw(DEVICE_TOKEN.encode('utf-8'), bcrypt.gensalt()).decode('utf-8')
    
    async with AsyncSessionLocal() as session:
        # Find first patient user
        res_user = await session.execute(select(User).order_by(User.id))
        users = res_user.scalars().all()
        if not users:
            print("No users found in database to link the device to!")
            return
            
        target_patient = None
        for u in users:
            if u.role and (u.role.value == "patient" or u.email == "patient@example.com"):
                target_patient = u
                break
        if not target_patient:
            target_patient = users[0] # fallback to first user
            
        print(f"Linking device {DEVICE_ID} to patient: {target_patient.full_name} ({target_patient.email}) - UUID: {target_patient.id}")
        
        # Check if already exists
        res = await session.execute(select(RegisteredDevice).where(RegisteredDevice.device_id == DEVICE_ID))
        existing = res.scalar_one_or_none()
        
        if existing:
            print("Device already registered. Updating patient_id and token...")
            existing.token_hash = hashed_token
            existing.patient_id = target_patient.id
            existing.is_active = True
        else:
            print("Registering new device...")
            new_device = RegisteredDevice(
                id=uuid.uuid4(),
                device_id=DEVICE_ID,
                token_hash=hashed_token,
                patient_id=target_patient.id,
                is_active=True
            )
            session.add(new_device)
            
        await session.commit()
        print("Device registration successfully executed inside Docker container!")

if __name__ == "__main__":
    asyncio.run(register())
