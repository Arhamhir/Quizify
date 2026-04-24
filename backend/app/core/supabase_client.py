from supabase import Client, create_client

from app.core.config import settings


def create_supabase_admin_client() -> Client:
    return create_client(settings.supabase_url, settings.supabase_service_role_key)


def create_supabase_anon_client() -> Client:
    return create_client(settings.supabase_url, settings.supabase_anon_key)
