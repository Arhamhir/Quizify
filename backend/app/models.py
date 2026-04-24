from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field


class DocumentIngestRequest(BaseModel):
    title: str = Field(min_length=3, max_length=140)
    source_type: Literal["pdf", "image", "camera", "text", "docx", "pptx", "mixed"] = "text"
    storage_path: str | None = None
    extracted_text: str = Field(min_length=10)


class DocumentIngestResponse(BaseModel):
    document_id: str
    message: str
    extracted_chars: int = 0
    chunk_count: int = 0


class DeleteDocumentResponse(BaseModel):
    message: str


class DeleteQuizResponse(BaseModel):
    message: str


class SessionDocument(BaseModel):
    id: str
    title: str
    source_type: str
    created_at: datetime


class SessionQuiz(BaseModel):
    id: str
    document_id: str
    title: str | None = None
    difficulty: str
    created_at: datetime
    latest_score: float | None = None
    correct_answers: int = 0
    wrong_answers: int = 0
    answered_questions: int = 0
    attempt_count: int = 0


class DocumentQuizProgressPoint(BaseModel):
    quiz_id: str
    attempted_at: datetime
    score_percent: float
    correct_answers: int
    wrong_answers: int


class DocumentQuizProgress(BaseModel):
    document_id: str
    document_title: str
    total_quizzes: int
    total_attempts: int
    total_correct: int
    total_wrong: int
    points: list[DocumentQuizProgressPoint]


class SessionReview(BaseModel):
    id: str
    document_id: str
    document_title: str | None = None
    review: str
    created_at: datetime


class RecentSessionResponse(BaseModel):
    recent_documents: list[SessionDocument]
    recent_quizzes: list[SessionQuiz]
    recent_reviews: list[SessionReview] = []
    document_quiz_progress: list[DocumentQuizProgress] = []


class ContinueSessionResponse(BaseModel):
    last_document_id: str | None
    last_quiz_id: str | None
    last_action: str
    last_action_at: datetime | None


class QuizGenerateRequest(BaseModel):
    document_id: str
    question_count: int = Field(default=10, ge=1, le=20)
    difficulty: Literal["easy", "medium", "hard", "adaptive"] = "adaptive"
    focus_topics: list[str] = []


class QuizQuestion(BaseModel):
    question_id: str
    question_type: Literal["mcq", "fill_blank", "short_answer"]
    prompt: str
    options: list[str] = []
    answer: str
    topic: str


class QuizGenerateResponse(BaseModel):
    quiz_id: str
    questions: list[QuizQuestion]


class QuizSubmitAnswer(BaseModel):
    question_id: str
    user_answer: str


class QuizSubmitRequest(BaseModel):
    quiz_id: str
    answers: list[QuizSubmitAnswer]


class QuizQuestionFeedback(BaseModel):
    question_id: str
    question_prompt: str
    user_answer: str
    correct_answer: str
    is_correct: bool
    topic: str


class WeakTopic(BaseModel):
    topic: str
    wrong_count: int
    suggestion: str


class DocumentWeakTopic(BaseModel):
    topic: str
    wrong_count: int
    correct_count: int
    remaining_wrong: int
    suggestion: str


class DocumentWeakTopicGroup(BaseModel):
    document_id: str
    document_title: str
    topics: list[DocumentWeakTopic]


class QuizSubmitResponse(BaseModel):
    score_percent: float
    weak_topics: list[WeakTopic]
    next_step: str
    question_feedback: list[QuizQuestionFeedback] = []


class QuizReasonRequest(BaseModel):
    quiz_id: str
    question_id: str
    user_answer: str


class QuizReasonResponse(BaseModel):
    question_id: str
    explanation: str


class QueryRequest(BaseModel):
    document_id: str
    question: str = Field(min_length=2, max_length=1200)


class QueryResponse(BaseModel):
    answer: str


class ReviewRequest(BaseModel):
    document_id: str


class ReviewResponse(BaseModel):
    review: str


class QuickNotesRequest(BaseModel):
    document_id: str
    topics: list[str] = Field(default_factory=list)


class QuickNotesResponse(BaseModel):
    notes: str


class ProgressResponse(BaseModel):
    total_quizzes: int
    total_attempts: int
    total_queries: int
    latest_score: float
    weakest_topics: list[WeakTopic]
    weak_topics_by_document: list[DocumentWeakTopicGroup] = []
    updated_at: datetime | None
