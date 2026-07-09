import asyncio
from sqlalchemy import select
from app.core.database import AsyncSessionLocal
from app.models.user import User

async def main():
    async with AsyncSessionLocal() as session:
        res = await session.execute(select(User))
        users = res.scalars().all()
        print("\n=== DOCKER DB USERS ===")
        for u in users:
            print(f"UserID: {u.id} | Email: {u.email} | Name: {u.full_name} | Role: {u.role.value if u.role else None}")

if __name__ == "__main__":
    asyncio.run(main())
