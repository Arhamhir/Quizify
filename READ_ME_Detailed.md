# Quizify Detailed Workflow Guide

This document explains the full backend + mobile workflow of Quizify in simple terms.

Scope in this guide:
- backend (FastAPI + AI orchestration + Supabase persistence)
- frontend-mob (Flutter mobile app)

Out of scope in this guide:
- frontend-web

## 1) Project Purpose
Quizify helps learners turn their own study material into:
- adaptive quizzes
- mentor-like Q&A
- AI-generated review and quick notes
- progress insights and weak-topic tracking

The app is user-specific: each authenticated user sees only their own documents, quizzes, and analytics.

## 2) Tech Used

### Mobile (frontend-mob)
- Flutter (Dart)
- Supabase Auth (email/password + Google login)
- Dio (HTTP client)
- flutter_dotenv (environment config)
- intl (date and formatting)
- file_picker + image_picker (document/camera input)
- google_fonts + animations/shimmer (UI system)

### Backend (backend)
- FastAPI + Uvicorn
- Pydantic + pydantic-settings
- Supabase Python SDK (data layer)
- LangGraph + LangChain Core + LangChain OpenAI
- Azure OpenAI model deployments
- python-multipart for uploads
- pypdf, python-docx, python-pptx, pillow, pytesseract for extraction/OCR

### Data and Identity
- Supabase Auth for user identity and access tokens
- Supabase tables (prefixed with quizify_) for documents, quizzes, attempts, reviews, progress snapshots, and session state

## 3) High-Level Architecture
1. User signs in from Flutter app.
2. Supabase returns an access token.
3. Flutter API client sends requests with Authorization: Bearer <token>.
4. FastAPI verifies user context from token.
5. Backend reads/writes user data in Supabase.
6. AI services generate quiz/query/review outputs.
7. Backend stores outcomes and updates progress/session state.
8. Flutter refreshes UI cards and analytics.

## 4) Core Modules and Their Role

### backend/app/main.py
- starts FastAPI app
- enables CORS
- mounts v1 API router
- exposes /health

### backend/app/api/routes.py
- all core endpoints for upload, quiz, query, review, progress, and session
- injects authenticated user context for every protected route

### backend/app/services/extraction_service.py
- parses uploaded file content
- runs OCR when needed
- chunks extracted content for downstream learning workflows

### backend/app/services/agent_graph.py
- routes AI tasks by mode:
  - quiz
  - query
  - review

### backend/app/services/mentor_service.py
- quiz scoring and evaluation
- wrong-answer explanation
- quick-note generation

### backend/app/services/repository.py
- all Supabase persistence operations
- tracks recent activity and progress snapshots

### frontend-mob/lib/core/api_client.dart
- single place for backend API calls
- attaches auth token to every v1 request
- includes lightweight cache for progress/recent/doc lists

### frontend-mob/lib/screens/*
- Upload screen: ingest content
- Quiz screen: generate, answer, submit, reason
- Query screen: ask mentor question
- Review screen: generate educational review
- Progress screen: analytics, recent activity, weak topics
- Home shell: continue-session and workflow entry points

## 5) End-to-End Workflow (Simple Step-by-Step)

### Step A: Authentication
1. User signs in (email/password or Google).
2. Supabase session is created on mobile.
3. ApiClient reads session token and prepares bearer headers.

### Step B: Document Upload and Ingestion
1. User uploads file from Upload screen.
2. Mobile sends multipart request to POST /v1/documents/upload.
3. Backend extracts text (and OCR if needed).
4. Backend stores document + chunks in Supabase.
5. Backend updates session state: last_action = document_uploaded.
6. Mobile refreshes document list and session cards.

### Step C: Quiz Generation and Submission
1. User selects a document and quiz settings.
2. Mobile calls POST /v1/quiz/generate.
3. Backend builds context and asks AI graph to generate questions.
4. Questions are saved and returned to mobile.
5. User answers and submits via POST /v1/quiz/submit.
6. Backend evaluates answers, computes score, weak topics, and next-step guidance.
7. Backend stores attempt and updates progress/session.
8. Mobile shows structured feedback and updated analytics.

### Step D: Wrong-Answer Explanation
1. User taps AI reason for a wrong answer.
2. Mobile calls POST /v1/quiz/reason.
3. Backend generates explanation using question, correct answer, user answer, and topic.
4. Explanation is shown in-context in the quiz UI.

### Step E: Mentor Query
1. User asks a question linked to a document.
2. Mobile calls POST /v1/agent/query.
3. Backend runs query mode in AI graph with document context.
4. Response is saved in query history.
5. Mobile displays sectioned, readable answer blocks.

### Step F: Educational Review
1. User opens Review screen and selects a document.
2. Mobile calls POST /v1/agent/review.
3. Backend generates a structured review summary.
4. Review is stored and returned.
5. Mobile renders formatted sections for easier reading.

### Step G: Progress and Continue Session
1. Mobile fetches GET /v1/progress for analytics.
2. Mobile fetches GET /v1/session/recent and GET /v1/session/continue.
3. Home and Progress screens show:
   - weak topics
   - recent docs/quizzes/reviews
   - latest score trend
   - last action to continue from

## 6) API Map (Backend)
- GET /health
- POST /v1/documents/upload
- GET /v1/documents
- DELETE /v1/documents/{document_id}
- DELETE /v1/quizzes/{quiz_id}
- POST /v1/quiz/generate
- POST /v1/quiz/submit
- POST /v1/quiz/reason
- POST /v1/agent/query
- POST /v1/agent/review
- POST /v1/agent/quick-notes
- GET /v1/progress
- GET /v1/session/recent
- GET /v1/session/continue

Authentication rule:
- all /v1/* routes require Authorization bearer token

## 7) Environment Variables (What Goes Where)

### backend/.env (conceptual)
- Supabase URL/key values for backend service role access
- Azure OpenAI deployment/config values
- CORS settings

### frontend-mob/.env
- SUPABASE_URL
- SUPABASE_ANON_KEY
- BACKEND_BASE_URL
- GOOGLE_WEB_CLIENT_ID
- GOOGLE_IOS_CLIENT_ID
- AUTH_REDIRECT_SCHEME
- optional PASSWORD_RESET_REDIRECT_URL

Tip:
- never commit real secrets to public repositories

## 8) Running the Project Locally

### Run backend
1. cd backend
2. create/activate virtual environment
3. pip install -r requirements.txt
4. uvicorn app.main:app --reload --port 8000

### Run mobile app
1. cd frontend-mob
2. flutter pub get
3. ensure .env is present
4. flutter run

## 9) How to Read the Product as a New Developer
Start from this order:
1. backend/app/api/routes.py (what features exist)
2. backend/app/services/repository.py (how data is persisted)
3. backend/app/services/agent_graph.py + mentor_service.py (AI behavior)
4. frontend-mob/lib/core/api_client.dart (how mobile calls backend)
5. frontend-mob/lib/screens/home_shell.dart then each feature screen

This order gives you a clean mental model quickly: API contract -> data behavior -> AI logic -> client integration -> user experience.

## 10) Practical Workflow Summary
In one sentence:
- User-authenticated document context powers every AI feature, and every action feeds back into progress/session tracking so the learner can continue seamlessly.

In three bullets:
- Upload once, reuse context across quiz/query/review.
- Every quiz attempt updates weak topics and performance trend.
- Home + Progress screens convert raw activity into clear next steps.
