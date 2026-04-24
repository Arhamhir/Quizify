from __future__ import annotations

import json
import random
import re
from collections import Counter
from typing import Any
from uuid import uuid4

from langchain_core.messages import HumanMessage, SystemMessage
from langchain_openai import AzureChatOpenAI

from app.core.config import settings


class MentorService:
    def __init__(self) -> None:
        self._chat_model = None
        if settings.azure_openai_api_key and settings.azure_openai_endpoint:
            self._chat_model = AzureChatOpenAI(
                azure_endpoint=settings.azure_openai_endpoint,
                api_key=settings.azure_openai_api_key,
                api_version=settings.azure_openai_api_version,
                azure_deployment=settings.azure_openai_deployment_chat,
                temperature=0.3,
            )

    def _invoke_llm(self, system_prompt: str, user_prompt: str) -> str:
        if not self._chat_model:
            return ""
        response = self._chat_model.invoke(
            [
                SystemMessage(content=system_prompt),
                HumanMessage(content=user_prompt),
            ]
        )
        return str(response.content)

    def generate_quiz_questions(
        self,
        extracted_text: str,
        question_count: int,
        difficulty: str,
        focus_topics: list[str] | None = None,
        avoid_prompts: list[str] | None = None,
    ) -> list[dict[str, Any]]:
        focus_topics = [topic.strip() for topic in (focus_topics or []) if topic.strip()]
        avoid_prompts = [prompt.strip().lower() for prompt in (avoid_prompts or []) if prompt.strip()]
        system_prompt = (
            "You are an expert assessment designer. Generate high-quality questions from source text. "
            "Return strictly valid JSON only (no markdown/code fences). "
            "Output must be a JSON array of objects with keys: question_type, prompt, options, answer, topic. "
            "Rules: "
            "1) question_type must be one of mcq, fill_blank, short_answer. "
            "2) For mcq, provide 4 concise options with exactly one correct option equal to answer. "
            "3) For fill_blank and short_answer, options should be [] and answer must be specific. "
            "4) Keep prompts clear, non-ambiguous, and grounded in source. "
            "5) Distribute difficulty according to requested difficulty and avoid duplicates. "
            "6) Do not repeat or closely paraphrase prompts listed in AvoidPrompts. "
            "7) Shuffle concept coverage and question order each generation."
        )
        focus_text = ", ".join(focus_topics) if focus_topics else "(none)"
        avoid_text = "\n".join(f"- {item}" for item in avoid_prompts[:40]) if avoid_prompts else "(none)"
        user_prompt = (
            f"Difficulty: {difficulty}. Count: {question_count}.\n"
            f"FocusTopics: {focus_text}\n"
            f"AvoidPrompts:\n{avoid_text}\n\n"
            f"Generate diverse questions across major concepts in this source:\n{extracted_text[:7000]}"
        )

        raw = self._invoke_llm(system_prompt, user_prompt)
        if raw:
            try:
                parsed = json.loads(raw)
                if isinstance(parsed, list) and parsed:
                    generated = [
                        {
                            "question_id": str(uuid4()),
                            "question_type": q.get("question_type", "mcq"),
                            "prompt": q.get("prompt", ""),
                            "options": q.get("options", []),
                            "answer": q.get("answer", ""),
                            "topic": q.get("topic", "General"),
                        }
                        for q in parsed[:question_count]
                    ]
                    random.shuffle(generated)
                    return generated
            except json.JSONDecodeError:
                pass

        # Fallback deterministic generator if LLM is unavailable.
        lines = [line.strip() for line in extracted_text.splitlines() if line.strip()]
        if focus_topics:
            focus_tokens = {token.lower() for topic in focus_topics for token in topic.split() if len(token) > 2}
            focused_lines = [
                line for line in lines if any(token in line.lower() for token in focus_tokens)
            ]
            if focused_lines:
                lines = focused_lines

        if avoid_prompts:
            lines = [
                line for line in lines if not any(existing in line.lower() for existing in avoid_prompts)
            ]

        random.shuffle(lines)
        base = lines[:question_count] if lines else ["Key concept"] * question_count
        generated = []
        for index, line in enumerate(base, start=1):
            generated.append(
                {
                    "question_id": str(uuid4()),
                    "question_type": "mcq" if index % 2 == 0 else "short_answer",
                    "prompt": f"Explain the significance of: {line[:140]}",
                    "options": [
                        "Core definition",
                        "Application",
                        "Limitation",
                        "Historical context",
                    ]
                    if index % 2 == 0
                    else [],
                    "answer": "Depends on source context",
                    "topic": line.split(" ")[0].strip(":,.-") or "General",
                }
            )
        random.shuffle(generated)
        return generated

    def answer_query(self, extracted_text: str, question: str) -> str:
        system_prompt = (
            "You are Quizify mentor assistant. Answer clearly, accurately, and only from the given source. "
            "Use plain text with exactly these headers on separate lines: Answer:, Why This Matters:, "
            "Quick Check:, Next Question:. Keep concise and practical. "
            "If source is insufficient, state the gap under Answer: and suggest what to upload or ask next."
        )
        user_prompt = f"Source:\n{extracted_text[:9000]}\n\nStudent question: {question}"
        raw = self._invoke_llm(system_prompt, user_prompt)
        if raw:
            return raw
        return "Based on the uploaded material, focus on the main definitions, process flow, and examples first."

    def create_ai_review(self, extracted_text: str) -> str:
        system_prompt = (
            "You are an unbiased educational reviewer. Write concise, high-quality sections with plain text only. "
            "Use exactly these section headers and keep each on its own line ending with a colon: "
            "Overview:, Key Strengths:, Knowledge Gaps:, Misconceptions To Avoid:, 5-Step Study Plan:, "
            "Practice Checklist:. Under each section, provide 2-5 bullet-style lines prefixed with '- '. "
            "Do not use markdown symbols, code blocks, or tables."
        )
        raw = self._invoke_llm(system_prompt, extracted_text[:9000])
        if raw:
            return raw
        return (
            "Overview:\n"
            "- The material covers core ideas but can benefit from deeper applied understanding.\n"
            "\n"
            "Key Strengths:\n"
            "- Main definitions and foundational terms are present.\n"
            "- Topic flow is mostly coherent for first-pass learning.\n"
            "\n"
            "Knowledge Gaps:\n"
            "- Add more worked examples for each major concept.\n"
            "- Include boundary cases and common failure scenarios.\n"
            "\n"
            "Misconceptions To Avoid:\n"
            "- Do not treat similar terms as interchangeable without context.\n"
            "- Avoid memorizing labels without understanding cause-effect links.\n"
            "\n"
            "5-Step Study Plan:\n"
            "- Step 1: Rebuild definitions in your own words.\n"
            "- Step 2: Solve two easy and two medium examples per topic.\n"
            "- Step 3: Explain one concept aloud as if teaching a classmate.\n"
            "- Step 4: Attempt a timed quiz and mark weak topics.\n"
            "- Step 5: Revisit weak topics with targeted practice.\n"
            "\n"
            "Practice Checklist:\n"
            "- I can define each core term without notes.\n"
            "- I can solve one new problem per topic.\n"
            "- I can justify why wrong options are incorrect."
        )

    def create_quick_notes(self, extracted_text: str, topics: list[str]) -> str:
        topics = [topic.strip() for topic in topics if topic.strip()]
        if not topics:
            topics = ["core concepts"]
        
        system_prompt = (
            "You are an expert quick revision coach. Generate concise, high-impact revision notes for exam prep. "
            "Use exactly these section headers on separate lines followed by a colon: "
            "Topic Snapshot:, Key Points:, Memory Hooks:, 5-Minute Drill:. "
            "Under each header, provide 2-5 bullet points prefixed with '- '. "
            "Keep content exam-focused: definitions, formulas, relationships, not philosophy. "
            "Each section should be completable in 1-2 minutes of review. "
            "Use plain text only - no markdown, no bold, no special formatting."
        )
        
        topics_str = ", ".join(topics)
        user_prompt = (
            f"Generate focused revision notes for these weak topics: {topics_str}\n\n"
            f"Source material:\n{extracted_text[:9000]}\n\n"
            f"Format EXACTLY as:\n"
            f"Topic Snapshot:\n"
            f"- [point 1]\n"
            f"- [point 2]\n\n"
            f"Key Points:\n"
            f"- [point 1]\n"
            f"- [point 2]\n\n"
            f"Memory Hooks:\n"
            f"- [point 1]\n"
            f"- [point 2]\n\n"
            f"5-Minute Drill:\n"
            f"- [point 1]\n"
            f"- [point 2]"
        )
        
        raw = self._invoke_llm(system_prompt, user_prompt)
        if raw:
            return raw
        
        # Fallback if LLM unavailable
        return (
            "Topic Snapshot:\n"
            f"- Focus areas: {', '.join(topics)}\n"
            "- These topics need targeted practice and review.\n\n"
            "Key Points:\n"
            "- Start by writing out definitions from memory without notes.\n"
            "- Identify one misconception you had on these topics.\n\n"
            "Memory Hooks:\n"
            "- Associate each topic with a real-world example or analogy.\n"
            "- Create a mental image or acronym for quick recall.\n\n"
            "5-Minute Drill:\n"
            "- Quiz yourself on each topic with one recall question.\n"
            "- Attempt one application problem combining multiple topics."
        )

    def explain_wrong_answer(
        self,
        question_prompt: str,
        correct_answer: str,
        user_answer: str,
        topic: str,
    ) -> str:
        system_prompt = (
            "You are a patient tutor. Explain why the student's answer is incorrect and fix misconceptions. "
            "Return plain text with exactly these section headers: Why It Is Incorrect:, Correct Thinking:, "
            "How To Avoid This Mistake:. Keep total length under 170 words. "
            "Be specific to the given question and avoid generic advice."
        )
        user_prompt = (
            f"Topic: {topic}\n"
            f"Question: {question_prompt}\n"
            f"Student answer: {user_answer or 'No answer provided'}\n"
            f"Correct answer: {correct_answer}"
        )
        raw = self._invoke_llm(system_prompt, user_prompt)
        if raw:
            return raw
        return (
            "Why It Is Incorrect:\n"
            "- Your response does not match the key idea required by the question.\n"
            "Correct Thinking:\n"
            f"- Focus on the core concept: {correct_answer}.\n"
            "How To Avoid This Mistake:\n"
            "- Compare your answer with the expected concept, then practice one similar question immediately."
        )

    def evaluate_attempt(
        self,
        questions: list[dict[str, Any]],
        user_answers: list[dict[str, Any]],
    ) -> tuple[float, list[dict[str, Any]], list[dict[str, Any]]]:
        answer_map = {item["question_id"]: item["user_answer"] for item in user_answers}
        evaluations = []
        weak_topic_counter: Counter[str] = Counter()
        weak_reason_counter: dict[str, Counter[str]] = {}
        correct = 0

        for question in questions:
            expected = (question.get("answer") or "").strip().lower()
            given = (answer_map.get(question["question_id"]) or "").strip().lower()
            is_correct = expected != "" and (expected in given or given in expected)
            inferred_topic = self._infer_topic(question)
            reason = self._infer_failure_reason(expected=expected, given=given)
            if is_correct:
                correct += 1
            else:
                weak_topic_counter[inferred_topic] += 1
                if inferred_topic not in weak_reason_counter:
                    weak_reason_counter[inferred_topic] = Counter()
                weak_reason_counter[inferred_topic][reason] += 1

            evaluations.append(
                {
                    "question_id": question["question_id"],
                    "question_prompt": question.get("prompt", ""),
                    "user_answer": answer_map.get(question["question_id"], ""),
                    "correct_answer": question.get("answer", ""),
                    "is_correct": is_correct,
                    "topic": inferred_topic,
                    "reason": reason,
                }
            )

        total = max(len(questions), 1)
        score_percent = round(correct / total * 100, 2)
        weak_topics = []
        for topic, count in weak_topic_counter.most_common(5):
            dominant_reason = weak_reason_counter.get(topic, Counter()).most_common(1)
            reason = dominant_reason[0][0] if dominant_reason else "Concept mismatch"
            weak_topics.append(
                {
                    "topic": topic,
                    "wrong_count": count,
                    "suggestion": self._build_topic_suggestion(topic=topic, reason=reason),
                }
            )
        return score_percent, weak_topics, evaluations

    def _infer_topic(self, question: dict[str, Any]) -> str:
        topic = (question.get("topic") or "").strip()
        if topic and topic.lower() != "general":
            return topic

        prompt = (question.get("prompt") or "").strip()
        words = re.findall(r"[a-zA-Z][a-zA-Z0-9_-]{2,}", prompt.lower())
        stopwords = {
            "what",
            "which",
            "when",
            "where",
            "why",
            "how",
            "explain",
            "describe",
            "following",
            "statement",
            "correct",
            "answer",
            "based",
            "from",
            "about",
            "with",
            "this",
            "that",
            "these",
            "those",
            "quiz",
            "question",
        }
        keywords = [w for w in words if w not in stopwords]
        if not keywords:
            return "General comprehension"
        return " ".join(keywords[:2]).title()

    def _infer_failure_reason(self, expected: str, given: str) -> str:
        if not given:
            return "No answer provided"
        if len(given.split()) <= 2 and len(expected.split()) > 3:
            return "Insufficient detail"

        expected_tokens = {token for token in re.findall(r"[a-zA-Z0-9]+", expected) if len(token) > 2}
        given_tokens = {token for token in re.findall(r"[a-zA-Z0-9]+", given) if len(token) > 2}
        if expected_tokens and given_tokens:
            overlap = len(expected_tokens & given_tokens)
            coverage = overlap / max(len(expected_tokens), 1)
            if coverage == 0:
                return "Off-topic understanding"
            if coverage < 0.35:
                return "Partial concept confusion"
        return "Concept mismatch"

    def _build_topic_suggestion(self, topic: str, reason: str) -> str:
        reason_map = {
            "No answer provided": "Start with short recall notes and answer 3 basic prompts before retrying.",
            "Insufficient detail": "Expand answers with definitions, one example, and one exception case.",
            "Off-topic understanding": "Re-read this topic and map key terms to their exact meanings.",
            "Partial concept confusion": "Compare similar concepts side by side and solve targeted practice.",
            "Concept mismatch": "Review fundamentals and solve 3 focused questions on this topic.",
        }
        return f"{reason_map.get(reason, reason_map['Concept mismatch'])} Focus area: {topic}."
