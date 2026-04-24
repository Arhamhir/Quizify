from collections.abc import AsyncGenerator

import httpx
from fastapi import Depends, Header, HTTPException, status

from app.core.config import settings


async def get_bearer_token(authorization: str = Header(default="")) -> str:
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing bearer token",
        )
    return authorization.replace("Bearer ", "", 1).strip()


async def get_current_user_id(token: str = Depends(get_bearer_token)) -> str:
    headers = {
        "apikey": settings.supabase_anon_key,
        "Authorization": f"Bearer {token}",
    }
    async with httpx.AsyncClient(timeout=15.0) as client:
        response = await client.get(f"{settings.supabase_url}/auth/v1/user", headers=headers)

    if response.status_code != 200:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired access token",
        )

    payload = response.json()
    user_id = payload.get("id")
    if not user_id:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User id not found in token",
        )
    return user_id


async def get_user_context(user_id: str = Depends(get_current_user_id)) -> AsyncGenerator[str, None]:
    yield user_id
