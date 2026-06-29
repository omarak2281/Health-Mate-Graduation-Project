"""
Redis cache service for performance optimization
"""

import redis.asyncio as redis
from typing import Optional, Any
import json
from app.core.config import settings


class RedisCache:
    """
    Redis caching service
    
    Provides:
    - BP reading cache (reduce DB queries)
    - User session cache
    - API response cache
    - Real-time data cache
    """
    
    def __init__(self):
        """Initialize Redis connection"""
        self.redis_client: Optional[redis.Redis] = None
    
    async def connect(self):
        """Connect to Redis"""
        try:
            self.redis_client = await redis.from_url(
                settings.redis_url,
                encoding="utf-8",
                decode_responses=True
            )
            # Test connection
            await self.redis_client.ping()
            print("✅ Redis connected successfully")
        except Exception as e:
            print(f"⚠️  Redis connection failed: {e}")
            self.redis_client = None
    
    async def disconnect(self):
        """Disconnect from Redis"""
        if self.redis_client:
            await self.redis_client.close()
    
    async def get(self, key: str) -> Optional[str]:
        """
        Get value from cache
        
        Args:
            key: Cache key
        
        Returns:
            Cached value or None
        """
        if not self.redis_client:
            return None
        
        try:
            return await self.redis_client.get(key)
        except Exception as e:
            print(f"Redis GET error: {e}")
            return None
    
    async def set(
        self,
        key: str,
        value: Any,
        expire_seconds: int = 300
    ) -> bool:
        """
        Set value in cache with expiration
        
        Args:
            key: Cache key
            value: Value to cache (will be JSON serialized)
            expire_seconds: Expiration time in seconds (default 5 minutes)
        
        Returns:
            True if successful
        """
        if not self.redis_client:
            return False
        
        try:
            # Serialize value if not string
            if not isinstance(value, str):
                value = json.dumps(value)
            
            await self.redis_client.setex(key, expire_seconds, value)
            return True
        except Exception as e:
            print(f"Redis SET error: {e}")
            return False
    
    async def delete(self, key: str) -> bool:
        """
        Delete key from cache
        
        Args:
            key: Cache key
        
        Returns:
            True if deleted
        """
        if not self.redis_client:
            return False
        
        try:
            await self.redis_client.delete(key)
            return True
        except Exception as e:
            print(f"Redis DELETE error: {e}")
            return False
    
    async def get_json(self, key: str) -> Optional[dict]:
        """
        Get JSON value from cache
        
        Args:
            key: Cache key
        
        Returns:
            Deserialized JSON or None
        """
        value = await self.get(key)
        if value:
            try:
                return json.loads(value)
            except json.JSONDecodeError:
                return None
        return None
    
    async def cache_bp_reading(self, user_id: str, bp_data: dict):
        """
        Cache latest BP reading for user
        
        Args:
            user_id: User ID
            bp_data: BP reading data
        """
        key = f"bp:latest:{user_id}"
        await self.set(key, bp_data, expire_seconds=600)  # 10 minutes
    
    async def get_cached_bp_reading(self, user_id: str) -> Optional[dict]:
        """
        Get cached BP reading for user
        
        Args:
            user_id: User ID
        
        Returns:
            Cached BP data or None
        """
        key = f"bp:latest:{user_id}"
        return await self.get_json(key)
    
    async def invalidate_user_cache(self, user_id: str):
        """
        Invalidate all caches for user
        
        Args:
            user_id: User ID
        """
        if not self.redis_client:
            return
        
        # Delete all user-related keys
        patterns = [
            f"bp:latest:{user_id}",
            f"bp:stats:{user_id}",
            f"meds:{user_id}",
            f"user:{user_id}"
        ]
        
        for pattern in patterns:
            await self.delete(pattern)


# Singleton instance
redis_cache = RedisCache()


async def get_redis_cache() -> RedisCache:
    """Get Redis cache instance"""
    if not redis_cache.redis_client:
        await redis_cache.connect()
    return redis_cache
