import logging

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from app.api.routes import router as quizify_router
from app.core.config import settings

logger = logging.getLogger("quizify.api")

app = FastAPI(title="Quizify API", version="0.1.0", debug=False)

origins = [origin.strip() for origin in settings.cors_allow_origins.split(",") if origin.strip()]
if not origins:
    origins = ["*"]

app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_origin_regex=r"https?://(localhost|127\.0\.0\.1)(:\d+)?",
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.exception_handler(Exception)
async def unhandled_exception_handler(request: Request, exc: Exception):
    logger.exception("Unhandled error on %s %s", request.method, request.url.path)
    return JSONResponse(
        status_code=500,
        content={"detail": "Internal server error while processing request."},
    )


@app.get("/health")
async def health_check():
    return {"status": "ok", "service": "quizify-backend"}


app.include_router(quizify_router)
