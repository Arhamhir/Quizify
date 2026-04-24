from datetime import datetime, timezone
from typing import Any
from uuid import uuid4

from supabase import Client


class QuizifyRepository:
    def __init__(self, client: Client):
        self.client = client

    def ingest_document(
        self,
        user_id: str,
        title: str,
        source_type: str,
        storage_path: str | None,
        extracted_text: str,
        file_metadata: dict[str, Any] | None = None,
    ) -> str:
        document_id = str(uuid4())
        self.client.table("quizify_documents").insert(
            {
                "id": document_id,
                "user_id": user_id,
                "title": title,
                "source_type": source_type,
                "storage_path": storage_path,
                "extracted_text": extracted_text,
                "file_metadata": file_metadata or {},
            }
        ).execute()
        return document_id

    def get_document(self, user_id: str, document_id: str) -> dict[str, Any]:
        response = (
            self.client.table("quizify_documents")
            .select("*")
            .eq("id", document_id)
            .eq("user_id", user_id)
            .limit(1)
            .execute()
        )
        if not response.data:
            raise ValueError("Document not found")
        return response.data[0]

    def create_quiz(self, user_id: str, document_id: str, question_count: int, difficulty: str) -> str:
        quiz_id = str(uuid4())
        self.client.table("quizify_quiz_generations").insert(
            {
                "id": quiz_id,
                "user_id": user_id,
                "document_id": document_id,
                "question_count": question_count,
                "difficulty": difficulty,
            }
        ).execute()
        return quiz_id

    def save_quiz_questions(self, quiz_id: str, questions: list[dict[str, Any]]) -> None:
        payload = []
        for question in questions:
            payload.append(
                {
                    "id": question["question_id"],
                    "quiz_id": quiz_id,
                    "question_type": question["question_type"],
                    "prompt": question["prompt"],
                    "options": question.get("options", []),
                    "answer": question["answer"],
                    "topic": question["topic"],
                }
            )
        self.client.table("quizify_quiz_questions").insert(payload).execute()

    def get_quiz_questions(self, user_id: str, quiz_id: str) -> list[dict[str, Any]]:
        quiz = (
            self.client.table("quizify_quiz_generations")
            .select("id")
            .eq("id", quiz_id)
            .eq("user_id", user_id)
            .limit(1)
            .execute()
        )
        if not quiz.data:
            raise ValueError("Quiz not found")

        response = self.client.table("quizify_quiz_questions").select("*").eq("quiz_id", quiz_id).execute()
        # Normalize 'id' field to 'question_id' for consistency with generated questions
        return [
            {**q, "question_id": q.get("id")} for q in (response.data or [])
        ]

    def get_recent_question_prompts(self, user_id: str, document_id: str, limit: int = 80) -> list[str]:
        quizzes = (
            self.client.table("quizify_quiz_generations")
            .select("id")
            .eq("user_id", user_id)
            .eq("document_id", document_id)
            .order("created_at", desc=True)
            .limit(20)
            .execute()
        )
        quiz_ids = [item.get("id") for item in (quizzes.data or []) if item.get("id")]
        if not quiz_ids:
            return []

        questions = (
            self.client.table("quizify_quiz_questions")
            .select("prompt")
            .in_("quiz_id", quiz_ids)
            .limit(limit)
            .execute()
        )
        prompts = []
        seen: set[str] = set()
        for item in questions.data or []:
            prompt = str(item.get("prompt", "")).strip()
            key = prompt.lower()
            if not prompt or key in seen:
                continue
            seen.add(key)
            prompts.append(prompt)
        return prompts

    def save_quiz_attempt(self, user_id: str, quiz_id: str, score_percent: float) -> str:
        attempt_id = str(uuid4())
        self.client.table("quizify_quiz_attempts").insert(
            {
                "id": attempt_id,
                "user_id": user_id,
                "quiz_id": quiz_id,
                "score_percent": score_percent,
            }
        ).execute()
        return attempt_id

    def save_quiz_answers(self, attempt_id: str, answers: list[dict[str, Any]]) -> None:
        self.client.table("quizify_quiz_answers").insert(
            [
                {
                    "id": str(uuid4()),
                    "attempt_id": attempt_id,
                    "question_id": ans["question_id"],
                    "user_answer": ans["user_answer"],
                    "is_correct": ans["is_correct"],
                }
                for ans in answers
            ]
        ).execute()

    def log_query(self, user_id: str, document_id: str, question: str, answer: str) -> None:
        self.client.table("quizify_query_logs").insert(
            {
                "id": str(uuid4()),
                "user_id": user_id,
                "document_id": document_id,
                "question": question,
                "answer": answer,
            }
        ).execute()

    def save_review(self, user_id: str, document_id: str, review: str) -> None:
        self.client.table("quizify_ai_reviews").insert(
            {
                "id": str(uuid4()),
                "user_id": user_id,
                "document_id": document_id,
                "review": review,
            }
        ).execute()

    def save_progress_snapshot(self, user_id: str, weak_topics: list[dict[str, Any]], latest_score: float) -> None:
        rebuilt_topics = self._rebuild_weak_topics_from_attempts(user_id=user_id)
        self.client.table("quizify_progress_snapshots").insert(
            {
                "id": str(uuid4()),
                "user_id": user_id,
                "latest_score": latest_score,
                "weak_topics": rebuilt_topics,
                "updated_at": datetime.now(timezone.utc).isoformat(),
            }
        ).execute()

    def rebuild_progress_snapshot(self, user_id: str) -> None:
        attempts = (
            self.client.table("quizify_quiz_attempts")
            .select("score_percent", "created_at")
            .eq("user_id", user_id)
            .order("created_at", desc=True)
            .limit(1)
            .execute()
        )
        latest_score = float((attempts.data or [{"score_percent": 0.0}])[0].get("score_percent", 0.0))
        rebuilt_topics = self._rebuild_weak_topics_from_attempts(user_id=user_id)
        self.client.table("quizify_progress_snapshots").insert(
            {
                "id": str(uuid4()),
                "user_id": user_id,
                "latest_score": latest_score,
                "weak_topics": rebuilt_topics,
                "updated_at": datetime.now(timezone.utc).isoformat(),
            }
        ).execute()

    def _rebuild_weak_topics_from_attempts(self, user_id: str) -> list[dict[str, Any]]:
        attempts = (
            self.client.table("quizify_quiz_attempts")
            .select("id")
            .eq("user_id", user_id)
            .execute()
        )
        attempt_ids = [item.get("id") for item in (attempts.data or []) if item.get("id")]
        if not attempt_ids:
            return []

        wrong_answers = (
            self.client.table("quizify_quiz_answers")
            .select("question_id")
            .in_("attempt_id", attempt_ids)
            .eq("is_correct", False)
            .execute()
        )
        question_ids = [item.get("question_id") for item in (wrong_answers.data or []) if item.get("question_id")]
        if not question_ids:
            return []

        questions = (
            self.client.table("quizify_quiz_questions")
            .select("id", "topic")
            .in_("id", question_ids)
            .execute()
        )
        topic_by_question = {str(item.get("id")): str(item.get("topic", "General")).strip() for item in (questions.data or [])}

        topic_counts: dict[str, int] = {}
        for qid in question_ids:
            topic = topic_by_question.get(str(qid), "General")
            topic_counts[topic] = topic_counts.get(topic, 0) + 1

        ranked = sorted(topic_counts.items(), key=lambda item: item[1], reverse=True)[:10]
        return [
            {
                "topic": topic,
                "wrong_count": count,
                "suggestion": f"Review fundamentals and solve 3 targeted problems on {topic}.",
            }
            for topic, count in ranked
        ]

    def get_progress(self, user_id: str) -> dict[str, Any]:
        quizzes = (
            self.client.table("quizify_quiz_generations")
            .select("id", count="exact")
            .eq("user_id", user_id)
            .execute()
        )
        attempts = (
            self.client.table("quizify_quiz_attempts")
            .select("id", count="exact")
            .eq("user_id", user_id)
            .execute()
        )
        queries = (
            self.client.table("quizify_query_logs")
            .select("id", count="exact")
            .eq("user_id", user_id)
            .execute()
        )
        latest_snapshot = (
            self.client.table("quizify_progress_snapshots")
            .select("*")
            .eq("user_id", user_id)
            .order("updated_at", desc=True)
            .limit(1)
            .execute()
        )

        snapshot = latest_snapshot.data[0] if latest_snapshot.data else None

        attempts_rows = (
            self.client.table("quizify_quiz_attempts")
            .select("id", "quiz_id", "score_percent")
            .eq("user_id", user_id)
            .execute()
        )
        attempt_to_quiz = {
            str(item.get("id")): str(item.get("quiz_id"))
            for item in (attempts_rows.data or [])
            if item.get("id") and item.get("quiz_id")
        }
        attempt_ids = list(attempt_to_quiz.keys())

        weak_topics_by_document: list[dict[str, Any]] = []
        weakest_topics: list[dict[str, Any]] = []
        average_score = 0.0

        scored_rows = [
            item for item in (attempts_rows.data or []) if item.get("quiz_id") and item.get("score_percent") is not None
        ]
        if scored_rows:
            score_quiz_ids = list({str(item.get("quiz_id")) for item in scored_rows})
            score_quiz_rows = (
                self.client.table("quizify_quiz_generations")
                .select("id", "document_id")
                .eq("user_id", user_id)
                .in_("id", score_quiz_ids)
                .execute()
            ) if score_quiz_ids else None
            score_quiz_to_doc = {
                str(item.get("id")): str(item.get("document_id"))
                for item in ((score_quiz_rows.data or []) if score_quiz_rows else [])
                if item.get("id") and item.get("document_id")
            }
            doc_scores: dict[str, list[float]] = {}
            for row in scored_rows:
                quiz_id = str(row.get("quiz_id"))
                doc_id = score_quiz_to_doc.get(quiz_id)
                if not doc_id:
                    continue
                doc_scores.setdefault(doc_id, []).append(float(row.get("score_percent", 0.0)))

            if doc_scores:
                doc_averages = [sum(values) / len(values) for values in doc_scores.values() if values]
                if doc_averages:
                    average_score = sum(doc_averages) / len(doc_averages)

        if attempt_ids:
            answers_rows = (
                self.client.table("quizify_quiz_answers")
                .select("attempt_id", "question_id", "is_correct")
                .in_("attempt_id", attempt_ids)
                .execute()
            )
            question_ids = [
                item.get("question_id")
                for item in (answers_rows.data or [])
                if item.get("question_id")
            ]

            if question_ids:
                questions_rows = (
                    self.client.table("quizify_quiz_questions")
                    .select("id", "quiz_id", "topic")
                    .in_("id", question_ids)
                    .execute()
                )
                question_meta = {
                    str(item.get("id")): {
                        "quiz_id": str(item.get("quiz_id", "")),
                        "topic": str(item.get("topic", "General")),
                    }
                    for item in (questions_rows.data or [])
                    if item.get("id")
                }

                quiz_ids = list({meta["quiz_id"] for meta in question_meta.values() if meta.get("quiz_id")})
                quiz_rows = (
                    self.client.table("quizify_quiz_generations")
                    .select("id", "document_id")
                    .in_("id", quiz_ids)
                    .eq("user_id", user_id)
                    .execute()
                ) if quiz_ids else None
                quiz_to_doc = {
                    str(item.get("id")): str(item.get("document_id"))
                    for item in ((quiz_rows.data or []) if quiz_rows else [])
                    if item.get("id") and item.get("document_id")
                }

                doc_ids = list({doc_id for doc_id in quiz_to_doc.values() if doc_id})
                doc_rows = (
                    self.client.table("quizify_documents")
                    .select("id", "title")
                    .in_("id", doc_ids)
                    .eq("user_id", user_id)
                    .execute()
                ) if doc_ids else None
                doc_title = {
                    str(item.get("id")): str(item.get("title", "Untitled document"))
                    for item in ((doc_rows.data or []) if doc_rows else [])
                }

                def normalize_topic(value: str) -> str:
                    cleaned = " ".join(value.strip().split())
                    if not cleaned:
                        return "General"
                    return cleaned.title()

                stats: dict[tuple[str, str], dict[str, int]] = {}
                for answer in answers_rows.data or []:
                    attempt_id = str(answer.get("attempt_id", ""))
                    question_id = str(answer.get("question_id", ""))
                    if not attempt_id or not question_id:
                        continue
                    quiz_id = attempt_to_quiz.get(attempt_id)
                    qmeta = question_meta.get(question_id)
                    if not quiz_id or not qmeta:
                        continue
                    doc_id = quiz_to_doc.get(quiz_id)
                    if not doc_id:
                        continue

                    topic = normalize_topic(str(qmeta.get("topic", "General")))
                    key = (doc_id, topic)
                    if key not in stats:
                        stats[key] = {"wrong": 0, "correct": 0}

                    if bool(answer.get("is_correct", False)):
                        stats[key]["correct"] += 1
                    else:
                        stats[key]["wrong"] += 1

                grouped: dict[str, list[dict[str, Any]]] = {}
                global_remaining: dict[str, int] = {}
                for (doc_id, topic), counts in stats.items():
                    wrong = counts["wrong"]
                    correct = counts["correct"]
                    remaining = max(wrong - correct, 0)
                    if remaining <= 0:
                        continue
                    grouped.setdefault(doc_id, []).append(
                        {
                            "topic": topic,
                            "wrong_count": wrong,
                            "correct_count": correct,
                            "remaining_wrong": remaining,
                            "suggestion": f"Practice targeted questions on {topic} until all current mistakes are cleared.",
                        }
                    )
                    global_remaining[topic] = global_remaining.get(topic, 0) + remaining

                weak_topics_by_document = [
                    {
                        "document_id": doc_id,
                        "document_title": doc_title.get(doc_id, "Untitled document"),
                        "topics": sorted(topics, key=lambda item: item["remaining_wrong"], reverse=True),
                    }
                    for doc_id, topics in grouped.items()
                ]
                weak_topics_by_document.sort(key=lambda item: sum(topic["remaining_wrong"] for topic in item["topics"]), reverse=True)

                weakest_topics = [
                    {
                        "topic": topic,
                        "wrong_count": count,
                        "suggestion": f"Clear pending mistakes in {topic} with focused practice.",
                    }
                    for topic, count in sorted(global_remaining.items(), key=lambda item: item[1], reverse=True)[:5]
                ]

        return {
            "total_quizzes": quizzes.count or 0,
            "total_attempts": attempts.count or 0,
            "total_queries": queries.count or 0,
            "latest_score": average_score,
            "weakest_topics": weakest_topics,
            "weak_topics_by_document": weak_topics_by_document,
            "updated_at": (snapshot or {}).get("updated_at"),
        }

    def save_document_chunks(self, user_id: str, document_id: str, chunks: list[str]) -> None:
        if not chunks:
            return
        payload = [
            {
                "id": str(uuid4()),
                "user_id": user_id,
                "document_id": document_id,
                "chunk_order": index,
                "content": chunk,
            }
            for index, chunk in enumerate(chunks)
        ]
        self.client.table("quizify_document_chunks").insert(payload).execute()

    def get_document_context(self, user_id: str, document_id: str, question: str | None = None) -> str:
        response = (
            self.client.table("quizify_document_chunks")
            .select("content,chunk_order")
            .eq("user_id", user_id)
            .eq("document_id", document_id)
            .order("chunk_order", desc=False)
            .execute()
        )
        chunks = response.data or []
        if not chunks:
            return self.get_document(user_id, document_id)["extracted_text"]

        if question and question.strip():
            tokens = {token.lower() for token in question.split() if len(token) > 2}
            ranked = sorted(
                chunks,
                key=lambda item: sum(1 for token in tokens if token in item["content"].lower()),
                reverse=True,
            )
            selected = ranked[:6]
        else:
            selected = chunks[:6]
        return "\n\n".join(item["content"] for item in selected)

    def update_session_state(
        self,
        user_id: str,
        last_action: str,
        last_document_id: str | None = None,
        last_quiz_id: str | None = None,
    ) -> None:
        existing = (
            self.client.table("quizify_user_sessions")
            .select("last_document_id", "last_quiz_id")
            .eq("user_id", user_id)
            .limit(1)
            .execute()
        )
        previous = existing.data[0] if existing.data else {}

        payload = {
            "user_id": user_id,
            "last_document_id": last_document_id if last_document_id is not None else previous.get("last_document_id"),
            "last_quiz_id": last_quiz_id if last_quiz_id is not None else previous.get("last_quiz_id"),
            "last_action": last_action,
            "last_action_at": datetime.now(timezone.utc).isoformat(),
            "updated_at": datetime.now(timezone.utc).isoformat(),
        }
        self.client.table("quizify_user_sessions").upsert(payload, on_conflict="user_id").execute()

    def get_recent_documents(self, user_id: str, limit: int = 10) -> list[dict[str, Any]]:
        response = (
            self.client.table("quizify_documents")
            .select("id", "title", "source_type", "created_at")
            .eq("user_id", user_id)
            .order("created_at", desc=True)
            .limit(limit)
            .execute()
        )
        return response.data or []

    def list_documents(self, user_id: str, limit: int = 100) -> list[dict[str, Any]]:
        response = (
            self.client.table("quizify_documents")
            .select("id", "title", "source_type", "created_at")
            .eq("user_id", user_id)
            .order("created_at", desc=True)
            .limit(limit)
            .execute()
        )
        return response.data or []

    def delete_document(self, user_id: str, document_id: str) -> None:
        exists = (
            self.client.table("quizify_documents")
            .select("id")
            .eq("id", document_id)
            .eq("user_id", user_id)
            .limit(1)
            .execute()
        )
        if not exists.data:
            raise ValueError("Document not found")

        (
            self.client.table("quizify_documents")
            .delete()
            .eq("id", document_id)
            .eq("user_id", user_id)
            .execute()
        )

    def delete_quiz(self, user_id: str, quiz_id: str) -> None:
        exists = (
            self.client.table("quizify_quiz_generations")
            .select("id")
            .eq("id", quiz_id)
            .eq("user_id", user_id)
            .limit(1)
            .execute()
        )
        if not exists.data:
            raise ValueError("Quiz not found")

        (
            self.client.table("quizify_quiz_generations")
            .delete()
            .eq("id", quiz_id)
            .eq("user_id", user_id)
            .execute()
        )

    def get_recent_quizzes(self, user_id: str, limit: int = 10) -> list[dict[str, Any]]:
        response = (
            self.client.table("quizify_quiz_generations")
            .select("id", "document_id", "difficulty", "created_at")
            .eq("user_id", user_id)
            .order("created_at", desc=True)
            .limit(limit)
            .execute()
        )
        quizzes = response.data or []
        if not quizzes:
            return []

        document_ids = [item.get("document_id") for item in quizzes if item.get("document_id")]
        document_title_map: dict[str, str] = {}
        if document_ids:
            docs = (
                self.client.table("quizify_documents")
                .select("id", "title")
                .eq("user_id", user_id)
                .in_("id", document_ids)
                .execute()
            )
            document_title_map = {str(item.get("id")): str(item.get("title", "")).strip() for item in (docs.data or [])}

        for quiz in quizzes:
            doc_title = document_title_map.get(str(quiz.get("document_id")), "Untitled document")
            quiz["title"] = f"Quiz on {doc_title}"

        quiz_ids = [str(item.get("id")) for item in quizzes if item.get("id")]
        attempts = (
            self.client.table("quizify_quiz_attempts")
            .select("id", "quiz_id", "score_percent", "created_at")
            .eq("user_id", user_id)
            .in_("quiz_id", quiz_ids)
            .order("created_at", desc=True)
            .execute()
        ) if quiz_ids else None

        latest_attempt_by_quiz: dict[str, dict[str, Any]] = {}
        attempts_by_quiz: dict[str, int] = {}
        attempt_ids: list[str] = []
        for item in (attempts.data or []) if attempts else []:
            quiz_id = str(item.get("quiz_id", ""))
            attempt_id = str(item.get("id", ""))
            if not quiz_id or not attempt_id:
                continue
            attempts_by_quiz[quiz_id] = attempts_by_quiz.get(quiz_id, 0) + 1
            if quiz_id not in latest_attempt_by_quiz:
                latest_attempt_by_quiz[quiz_id] = item
                attempt_ids.append(attempt_id)

        answer_counts: dict[str, dict[str, int]] = {}
        if attempt_ids:
            answers = (
                self.client.table("quizify_quiz_answers")
                .select("attempt_id", "is_correct")
                .in_("attempt_id", attempt_ids)
                .execute()
            )
            for answer in answers.data or []:
                attempt_id = str(answer.get("attempt_id", ""))
                if not attempt_id:
                    continue
                bucket = answer_counts.setdefault(attempt_id, {"correct": 0, "wrong": 0})
                if bool(answer.get("is_correct", False)):
                    bucket["correct"] += 1
                else:
                    bucket["wrong"] += 1

        for quiz in quizzes:
            quiz_id = str(quiz.get("id", ""))
            latest_attempt = latest_attempt_by_quiz.get(quiz_id)
            if not latest_attempt:
                quiz["latest_score"] = None
                quiz["correct_answers"] = 0
                quiz["wrong_answers"] = 0
                quiz["answered_questions"] = 0
                quiz["attempt_count"] = attempts_by_quiz.get(quiz_id, 0)
                continue
            attempt_id = str(latest_attempt.get("id", ""))
            counts = answer_counts.get(attempt_id, {"correct": 0, "wrong": 0})
            quiz["latest_score"] = float(latest_attempt.get("score_percent", 0.0))
            quiz["correct_answers"] = counts["correct"]
            quiz["wrong_answers"] = counts["wrong"]
            quiz["answered_questions"] = counts["correct"] + counts["wrong"]
            quiz["attempt_count"] = attempts_by_quiz.get(quiz_id, 0)

        return quizzes

    def get_document_quiz_progress(
        self,
        user_id: str,
        max_documents: int = 6,
        max_points_per_document: int = 10,
    ) -> list[dict[str, Any]]:
        attempts = (
            self.client.table("quizify_quiz_attempts")
            .select("id", "quiz_id", "score_percent", "created_at")
            .eq("user_id", user_id)
            .order("created_at", desc=False)
            .limit(500)
            .execute()
        )
        attempt_rows = attempts.data or []
        if not attempt_rows:
            return []

        quiz_ids = list({str(item.get("quiz_id")) for item in attempt_rows if item.get("quiz_id")})
        quizzes = (
            self.client.table("quizify_quiz_generations")
            .select("id", "document_id")
            .eq("user_id", user_id)
            .in_("id", quiz_ids)
            .execute()
        ) if quiz_ids else None
        quiz_to_doc = {
            str(item.get("id")): str(item.get("document_id"))
            for item in ((quizzes.data or []) if quizzes else [])
            if item.get("id") and item.get("document_id")
        }
        if not quiz_to_doc:
            return []

        doc_ids = list({doc_id for doc_id in quiz_to_doc.values() if doc_id})
        docs = (
            self.client.table("quizify_documents")
            .select("id", "title")
            .eq("user_id", user_id)
            .in_("id", doc_ids)
            .execute()
        ) if doc_ids else None
        doc_title_map = {
            str(item.get("id")): str(item.get("title", "Untitled document"))
            for item in ((docs.data or []) if docs else [])
        }

        attempt_ids = [str(item.get("id")) for item in attempt_rows if item.get("id")]
        answers = (
            self.client.table("quizify_quiz_answers")
            .select("attempt_id", "is_correct")
            .in_("attempt_id", attempt_ids)
            .execute()
        ) if attempt_ids else None
        answer_counts: dict[str, dict[str, int]] = {}
        for answer in (answers.data or []) if answers else []:
            attempt_id = str(answer.get("attempt_id", ""))
            if not attempt_id:
                continue
            bucket = answer_counts.setdefault(attempt_id, {"correct": 0, "wrong": 0})
            if bool(answer.get("is_correct", False)):
                bucket["correct"] += 1
            else:
                bucket["wrong"] += 1

        grouped: dict[str, dict[str, Any]] = {}
        for attempt in attempt_rows:
            attempt_id = str(attempt.get("id", ""))
            quiz_id = str(attempt.get("quiz_id", ""))
            doc_id = quiz_to_doc.get(quiz_id)
            if not attempt_id or not quiz_id or not doc_id:
                continue

            counts = answer_counts.get(attempt_id, {"correct": 0, "wrong": 0})
            group = grouped.setdefault(
                doc_id,
                {
                    "document_id": doc_id,
                    "document_title": doc_title_map.get(doc_id, "Untitled document"),
                    "total_quizzes": 0,
                    "total_attempts": 0,
                    "total_correct": 0,
                    "total_wrong": 0,
                    "points": [],
                    "_quiz_ids": set(),
                },
            )
            group["total_attempts"] += 1
            group["total_correct"] += counts["correct"]
            group["total_wrong"] += counts["wrong"]
            group["_quiz_ids"].add(quiz_id)
            group["points"].append(
                {
                    "quiz_id": quiz_id,
                    "attempted_at": attempt.get("created_at"),
                    "score_percent": float(attempt.get("score_percent", 0.0)),
                    "correct_answers": counts["correct"],
                    "wrong_answers": counts["wrong"],
                }
            )

        result: list[dict[str, Any]] = []
        for value in grouped.values():
            points = sorted(value["points"], key=lambda item: str(item.get("attempted_at", "")))
            value["points"] = points[-max_points_per_document:]
            value["total_quizzes"] = len(value.pop("_quiz_ids", set()))
            result.append(value)

        result.sort(key=lambda item: item["total_attempts"], reverse=True)
        return result[:max_documents]

    def get_recent_reviews(self, user_id: str, limit: int = 10) -> list[dict[str, Any]]:
        response = (
            self.client.table("quizify_ai_reviews")
            .select("id", "document_id", "review", "created_at")
            .eq("user_id", user_id)
            .order("created_at", desc=True)
            .limit(limit)
            .execute()
        )
        reviews = response.data or []
        if not reviews:
            return []

        document_ids = [item.get("document_id") for item in reviews if item.get("document_id")]
        document_title_map: dict[str, str] = {}
        if document_ids:
            docs = (
                self.client.table("quizify_documents")
                .select("id", "title")
                .eq("user_id", user_id)
                .in_("id", document_ids)
                .execute()
            )
            document_title_map = {str(item.get("id")): str(item.get("title", "")).strip() for item in (docs.data or [])}

        for item in reviews:
            item["document_title"] = document_title_map.get(str(item.get("document_id")), "Untitled document")
        return reviews

    def get_continue_state(self, user_id: str) -> dict[str, Any]:
        response = (
            self.client.table("quizify_user_sessions")
            .select("last_document_id", "last_quiz_id", "last_action", "last_action_at")
            .eq("user_id", user_id)
            .limit(1)
            .execute()
        )
        if not response.data:
            return {
                "last_document_id": None,
                "last_quiz_id": None,
                "last_action": "dashboard",
                "last_action_at": None,
            }
        return response.data[0]
