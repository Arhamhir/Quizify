# Quizify

Quizify is an AI-powered learning platform that turns user study material into adaptive quizzes, mentor-style Q&A, AI review summaries, and progress insights.
### Watch live at https://quizify-ai-one.vercel.app/
This repository contains:

- FastAPI backend (API + AI orchestration + persistence)
- Flutter mobile app
- React web app

## What It Does

- Upload study material (PDF, DOCX, PPTX, images, notes)
- Extract and chunk content for retrieval and quiz generation
- Generate adaptive quizzes and evaluate attempts
- Explain wrong answers with AI reasoning
- Answer document-grounded questions (mentor mode)
- Generate AI reviews and quick notes
- Track weak topics, scores, recent activity, and continue-session state

## Repository Structure

- `backend/`: FastAPI services, auth checks, AI flows, Supabase data layer
- `frontend-mob/`: Flutter mobile client
- `frontend-web/`: React + Vite web client
- `test/`: additional test assets/resources

## Tech Stack

- Backend: FastAPI, Pydantic, Supabase Python SDK, LangGraph/LangChain, Azure OpenAI
- Mobile: Flutter, Supabase Auth, Dio
- Web: React, Vite, Supabase JS
- Extraction/OCR: pypdf, python-docx, python-pptx, pillow, pytesseract

## High-Level Workflow

1. User signs in with Supabase (email/password or Google).
2. Client sends Supabase bearer token to backend `/v1/*` APIs.
3. Backend validates user context from token.
4. Uploaded documents are extracted, chunked, and stored.
5. AI services generate quiz/query/review/quick-notes outputs.
6. Attempts and activity update progress and continue-session state.
7. Clients refresh dashboards and mode-specific screens.

## Key API Endpoints

- `GET /health`
- `POST /v1/documents/upload`
- `GET /v1/documents`
- `DELETE /v1/documents/{document_id}`
- `DELETE /v1/quizzes/{quiz_id}`
- `POST /v1/quiz/generate`
- `POST /v1/quiz/submit`
- `POST /v1/quiz/reason`
- `POST /v1/agent/query`
- `POST /v1/agent/review`
- `POST /v1/agent/quick-notes`
- `GET /v1/progress`
- `GET /v1/session/recent`
- `GET /v1/session/continue`

All `/v1/*` routes require `Authorization: Bearer <supabase_access_token>`.

## Local Setup

### 1) Backend

```bash
cd backend
pip install -r requirements.txt
uvicorn app.main:app --reload --port 8000
```

### 2) Mobile App (Flutter)

```bash
cd frontend-mob
flutter pub get
flutter run
```

Required `frontend-mob/.env` values:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `BACKEND_BASE_URL`
- `GOOGLE_WEB_CLIENT_ID`
- `GOOGLE_IOS_CLIENT_ID`
- `AUTH_REDIRECT_SCHEME`

### 3) Web App (React)

```bash
cd frontend-web
npm install
npm run dev
```

Recommended `frontend-web/.env` values:

- `VITE_SUPABASE_URL`
- `VITE_SUPABASE_ANON_KEY`
- `VITE_BACKEND_BASE_URL`

## Security Notes

- Never commit real secrets or credentials.
- Keep environment files local (`.env`, `.env.*`).
- Rotate any key immediately if accidentally exposed.

## Development Notes

- Backend is the source of truth for auth context and data updates.
- Mobile and web should consume the same `/v1/*` contract.
- Keep feature parity by implementing new learning modes in both clients where required.
