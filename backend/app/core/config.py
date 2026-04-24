from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    app_name: str = "Quizify"
    app_env: str = "development"
    app_port: int = 8000

    supabase_url: str
    supabase_anon_key: str
    supabase_service_role_key: str

    azure_openai_endpoint: str | None = None
    azure_openai_api_key: str | None = None
    azure_openai_api_version: str = "2024-10-21"
    azure_openai_deployment_chat: str = "gpt-4.1"
    azure_openai_deployment_reasoning: str = "o4-mini"

    tesseract_cmd: str | None = None
    cors_allow_origins: str = "*"


settings = Settings()
