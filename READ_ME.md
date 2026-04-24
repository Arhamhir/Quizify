# Quizify

Quizify is an AI-powered learning app that turns user-uploaded study material into quizzes, mentor-style Q&A, review summaries, and progress insights.

Scope for this repository overview:
- backend (FastAPI)
- frontend-mob (Flutter)

Excluded in this summary:
- frontend-web

## What It Does
- Upload learning material (PDF, DOCX, PPTX, images, notes)
- Generate adaptive quizzes
- Ask contextual questions from uploaded content
- Get AI educational review
- Track weak topics and progress history
- Continue from last session activity

## Tech Stack
- Mobile: Flutter, Supabase Auth, Dio
- Backend: FastAPI, Supabase, LangGraph/LangChain, Azure OpenAI
- Extraction/OCR: pypdf, python-docx, python-pptx, pillow, pytesseract

## Core Flow
1. User signs in via Supabase.
2. Mobile app calls FastAPI endpoints with bearer token.
3. Backend ingests document text and stores chunks.
4. AI workflows generate quiz/query/review outputs.
5. Progress and session state are updated after each action.

## Key API Endpoints
- POST /v1/documents/upload
- POST /v1/quiz/generate
- POST /v1/quiz/submit
- POST /v1/quiz/reason
- POST /v1/agent/query
- POST /v1/agent/review
- GET /v1/progress
- GET /v1/session/recent
- GET /v1/session/continue

## Quick Start

### Backend
1. cd backend
2. pip install -r requirements.txt
3. uvicorn app.main:app --reload --port 8000

### Mobile
1. cd frontend-mob
2. flutter pub get
3. add frontend-mob/.env
4. flutter run

## Environment Notes
frontend-mob/.env should include:
- SUPABASE_URL
- SUPABASE_ANON_KEY
- BACKEND_BASE_URL
- GOOGLE_WEB_CLIENT_ID
- GOOGLE_IOS_CLIENT_ID
- AUTH_REDIRECT_SCHEME

## Repository Structure
- backend: API, AI orchestration, persistence layer
- frontend-mob: Flutter UI and API integration
- test: additional test resources

## Security and Publishing
- Do not commit real credentials.
- Keep secrets in local env files or secret managers.
- This README only contains information suitable for public GitHub display.
