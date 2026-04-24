import logging

from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile

from app.core.auth import get_user_context
from app.core.supabase_client import create_supabase_admin_client
from app.models import (
    ContinueSessionResponse,
    DeleteDocumentResponse,
    DeleteQuizResponse,
    DocumentIngestResponse,
    ProgressResponse,
    QuickNotesRequest,
    QuickNotesResponse,
    QueryRequest,
    QueryResponse,
    RecentSessionResponse,
    QuizGenerateRequest,
    QuizGenerateResponse,
    QuizQuestion,
    QuizQuestionFeedback,
    QuizReasonRequest,
    QuizReasonResponse,
    QuizSubmitRequest,
    QuizSubmitResponse,
    ReviewRequest,
    ReviewResponse,
)
from app.services.agent_graph import AgentGraphService
from app.services.extraction_service import ExtractionService
from app.services.mentor_service import MentorService
from app.services.repository import QuizifyRepository

router = APIRouter(prefix="/v1", tags=["quizify"])
logger = logging.getLogger("quizify.api.routes")

mentor_service = MentorService()
agent_graph = AgentGraphService(mentor_service)
extraction_service = ExtractionService()


@router.post("/documents/upload", response_model=DocumentIngestResponse)
async def upload_document(
    title: str = Form(...),
    source_type: str = Form("auto"),
    extracted_text: str = Form(""),
    file: UploadFile = File(...),
    user_id: str = Depends(get_user_context),
):
    try:
        payload = await file.read()
        if not payload:
            raise HTTPException(status_code=400, detail="Uploaded file is empty")

        extraction = extraction_service.extract(
            file_name=file.filename or "uploaded_file",
            source_type=source_type,
            payload=payload,
            fallback_text=extracted_text,
        )

        repo = QuizifyRepository(create_supabase_admin_client())
        detected_source = str(extraction.metadata.get("source_type", source_type))
        document_id = repo.ingest_document(
            user_id=user_id,
            title=title,
            source_type=detected_source,
            storage_path=file.filename,
            extracted_text=extraction.extracted_text,
            file_metadata=extraction.metadata,
        )
        repo.save_document_chunks(user_id=user_id, document_id=document_id, chunks=extraction.chunks)
        repo.update_session_state(user_id=user_id, last_action="document_uploaded", last_document_id=document_id)

        return DocumentIngestResponse(
            document_id=document_id,
            message="Document saved and ready for quiz/query/review",
            extracted_chars=len(extraction.extracted_text),
            chunk_count=len(extraction.chunks),
        )
    except HTTPException:
        raise
    except Exception as exc:
        logger.exception("Upload failed for user_id=%s file=%s", user_id, file.filename)
        raise HTTPException(status_code=500, detail=f"Upload failed: {exc}") from exc


@router.get("/documents")
async def list_documents(user_id: str = Depends(get_user_context), limit: int = 100):
    repo = QuizifyRepository(create_supabase_admin_client())
    return repo.list_documents(user_id=user_id, limit=max(1, min(limit, 200)))


@router.delete("/documents/{document_id}", response_model=DeleteDocumentResponse)
async def delete_document(document_id: str, user_id: str = Depends(get_user_context)):
    repo = QuizifyRepository(create_supabase_admin_client())
    try:
        repo.delete_document(user_id=user_id, document_id=document_id)
        return DeleteDocumentResponse(message="Document deleted")
    except ValueError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc


@router.delete("/quizzes/{quiz_id}", response_model=DeleteQuizResponse)
async def delete_quiz(quiz_id: str, user_id: str = Depends(get_user_context)):
    repo = QuizifyRepository(create_supabase_admin_client())
    try:
        repo.delete_quiz(user_id=user_id, quiz_id=quiz_id)
        repo.rebuild_progress_snapshot(user_id=user_id)
        repo.update_session_state(user_id=user_id, last_action="quiz_deleted")
        return DeleteQuizResponse(message="Quiz deleted")
    except ValueError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc


@router.post("/quiz/generate", response_model=QuizGenerateResponse)
async def generate_quiz(payload: QuizGenerateRequest, user_id: str = Depends(get_user_context)):
    repo = QuizifyRepository(create_supabase_admin_client())
    document = repo.get_document(user_id=user_id, document_id=payload.document_id)
    previous_prompts = repo.get_recent_question_prompts(user_id=user_id, document_id=payload.document_id)

    questions = agent_graph.run(
        mode="quiz",
        text=repo.get_document_context(user_id=user_id, document_id=payload.document_id),
        question_count=payload.question_count,
        difficulty=payload.difficulty,
        focus_topics=payload.focus_topics,
        avoid_prompts=previous_prompts,
    )

    quiz_id = repo.create_quiz(
        user_id=user_id,
        document_id=payload.document_id,
        question_count=payload.question_count,
        difficulty=payload.difficulty,
    )
    repo.save_quiz_questions(quiz_id, questions)
    repo.update_session_state(
        user_id=user_id,
        last_action="quiz_generated",
        last_document_id=payload.document_id,
        last_quiz_id=quiz_id,
    )
    return QuizGenerateResponse(quiz_id=quiz_id, questions=[QuizQuestion(**q) for q in questions])


@router.post("/agent/quick-notes", response_model=QuickNotesResponse)
async def generate_quick_notes(payload: QuickNotesRequest, user_id: str = Depends(get_user_context)):
    repo = QuizifyRepository(create_supabase_admin_client())
    text = repo.get_document_context(user_id=user_id, document_id=payload.document_id)
    notes = mentor_service.create_quick_notes(extracted_text=text, topics=payload.topics)
    repo.update_session_state(user_id=user_id, last_action="quick_notes_generated", last_document_id=payload.document_id)
    return QuickNotesResponse(notes=notes)


@router.post("/quiz/submit", response_model=QuizSubmitResponse)
async def submit_quiz(payload: QuizSubmitRequest, user_id: str = Depends(get_user_context)):
    repo = QuizifyRepository(create_supabase_admin_client())
    questions = repo.get_quiz_questions(user_id=user_id, quiz_id=payload.quiz_id)
    if not questions:
        raise HTTPException(status_code=404, detail="Quiz questions not found")

    score_percent, weak_topics, evaluations = mentor_service.evaluate_attempt(
        questions,
        [{"question_id": a.question_id, "user_answer": a.user_answer} for a in payload.answers],
    )

    attempt_id = repo.save_quiz_attempt(user_id=user_id, quiz_id=payload.quiz_id, score_percent=score_percent)
    repo.save_quiz_answers(attempt_id=attempt_id, answers=evaluations)
    repo.save_progress_snapshot(user_id=user_id, weak_topics=weak_topics, latest_score=score_percent)
    repo.update_session_state(user_id=user_id, last_action="quiz_submitted", last_quiz_id=payload.quiz_id)

    next_step = (
        "Great progress. Generate another adaptive quiz focused on weak topics."
        if score_percent >= 70
        else "Revise weak topics first with mentor query mode, then retry with a new quiz."
    )
    feedback = [
        QuizQuestionFeedback(
            question_id=item["question_id"],
            question_prompt=item.get("question_prompt", ""),
            user_answer=item.get("user_answer", ""),
            correct_answer=item.get("correct_answer", ""),
            is_correct=bool(item.get("is_correct", False)),
            topic=item.get("topic", "General"),
        )
        for item in evaluations
    ]
    return QuizSubmitResponse(
        score_percent=score_percent,
        weak_topics=weak_topics,
        next_step=next_step,
        question_feedback=feedback,
    )


@router.post("/quiz/reason", response_model=QuizReasonResponse)
async def explain_quiz_reason(payload: QuizReasonRequest, user_id: str = Depends(get_user_context)):
    repo = QuizifyRepository(create_supabase_admin_client())
    try:
        questions = repo.get_quiz_questions(user_id=user_id, quiz_id=payload.quiz_id)
    except ValueError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    if not questions:
        raise HTTPException(status_code=404, detail="Quiz questions not found")

    selected = next((q for q in questions if str(q.get("question_id")) == payload.question_id), None)
    if not selected:
        raise HTTPException(status_code=404, detail="Question not found")

    explanation = mentor_service.explain_wrong_answer(
        question_prompt=str(selected.get("prompt", "")),
        correct_answer=str(selected.get("answer", "")),
        user_answer=payload.user_answer,
        topic=str(selected.get("topic", "General")),
    )
    return QuizReasonResponse(question_id=payload.question_id, explanation=explanation)


@router.post("/agent/query", response_model=QueryResponse)
async def ask_query(payload: QueryRequest, user_id: str = Depends(get_user_context)):
    repo = QuizifyRepository(create_supabase_admin_client())
    answer = agent_graph.run(
        mode="query",
        text=repo.get_document_context(user_id=user_id, document_id=payload.document_id, question=payload.question),
        question=payload.question,
    )
    repo.log_query(user_id=user_id, document_id=payload.document_id, question=payload.question, answer=answer)
    repo.update_session_state(user_id=user_id, last_action="query_asked", last_document_id=payload.document_id)
    return QueryResponse(answer=answer)


@router.post("/agent/review", response_model=ReviewResponse)
async def generate_review(payload: ReviewRequest, user_id: str = Depends(get_user_context)):
    repo = QuizifyRepository(create_supabase_admin_client())
    review = agent_graph.run(
        mode="review",
        text=repo.get_document_context(user_id=user_id, document_id=payload.document_id),
    )
    repo.save_review(user_id=user_id, document_id=payload.document_id, review=review)
    repo.update_session_state(user_id=user_id, last_action="review_generated", last_document_id=payload.document_id)
    return ReviewResponse(review=review)


@router.get("/progress", response_model=ProgressResponse)
async def get_progress(user_id: str = Depends(get_user_context)):
    repo = QuizifyRepository(create_supabase_admin_client())
    data = repo.get_progress(user_id)
    return ProgressResponse(**data)


@router.get("/session/recent", response_model=RecentSessionResponse)
async def get_recent_session(user_id: str = Depends(get_user_context)):
    repo = QuizifyRepository(create_supabase_admin_client())
    docs = repo.get_recent_documents(user_id=user_id)
    quizzes = repo.get_recent_quizzes(user_id=user_id)
    reviews = repo.get_recent_reviews(user_id=user_id)
    progress = repo.get_document_quiz_progress(user_id=user_id)
    return RecentSessionResponse(
        recent_documents=docs,
        recent_quizzes=quizzes,
        recent_reviews=reviews,
        document_quiz_progress=progress,
    )


@router.get("/session/continue", response_model=ContinueSessionResponse)
async def get_continue_session(user_id: str = Depends(get_user_context)):
    repo = QuizifyRepository(create_supabase_admin_client())
    state = repo.get_continue_state(user_id=user_id)
    return ContinueSessionResponse(**state)
