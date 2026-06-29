import asyncio
from app.core.database import AsyncSessionLocal
from sqlalchemy import text

async def clear():
    async with AsyncSessionLocal() as s:
        await s.execute(text('DELETE FROM medications'))
        await s.commit()
    print('DB cleared')

if __name__ == "__main__":
    asyncio.run(clear())
