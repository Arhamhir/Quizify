# Quizify Backend

FastAPI backend for Quizify with:
- Supabase auth + persistence
- Multi-user activity tracking
- Quiz generation and adaptive mentoring
- Query and AI review workflows
- LangGraph-based orchestration layer for parallel/branching behaviors

## Setup

1. Create env file:
   - Copy `.env.example` to `.env`
2. Activate your existing `venv` (or create one if needed):
   - PowerShell: `\.\.venv\Scripts\Activate.ps1`
3. Install dependencies:
   - `pip install -r requirements.txt`
4. Run:
   - `uvicorn app.main:app --reload --port 8000`

## OCR note

- `pytesseract` requires Tesseract OCR installed on your machine.
- On Windows, install Tesseract and ensure it is available in PATH.

## Azure OpenAI model deployments to create

Create these deployments in your Azure OpenAI resource and put their deployment names in `.env`:
- `gpt-4.1` for rich quiz/question/review generation
- `o4-mini` for faster reasoning and adaptive follow-up

## API summary

- `GET /health`
- `POST /v1/documents/upload` (multipart upload + extraction + chunk indexing)
- `POST /v1/agent/query`
- `POST /v1/agent/review`
- `POST /v1/quiz/generate`
- `POST /v1/quiz/submit`
- `GET /v1/progress`
- `GET /v1/session/recent`
- `GET /v1/session/continue`

All Supabase tables are prefixed with `quizify_`.

All `/v1/*` endpoints require `Authorization: Bearer <supabase_access_token>`.
