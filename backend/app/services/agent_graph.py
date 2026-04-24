from __future__ import annotations

from typing import Any, TypedDict

from langgraph.graph import END, START, StateGraph

from app.services.mentor_service import MentorService


class AgentState(TypedDict):
    mode: str
    text: str
    question_count: int
    difficulty: str
    focus_topics: list[str]
    avoid_prompts: list[str]
    question: str
    result: Any


class AgentGraphService:
    def __init__(self, mentor_service: MentorService):
        self.mentor_service = mentor_service
        self._graph = self._build_graph()

    def _build_graph(self):
        workflow = StateGraph(AgentState)

        def generate_quiz_node(state: AgentState):
            questions = self.mentor_service.generate_quiz_questions(
                state["text"],
                state["question_count"],
                state["difficulty"],
                focus_topics=state["focus_topics"],
                avoid_prompts=state["avoid_prompts"],
            )
            return {"result": questions}

        def query_node(state: AgentState):
            answer = self.mentor_service.answer_query(state["text"], state["question"])
            return {"result": answer}

        def review_node(state: AgentState):
            review = self.mentor_service.create_ai_review(state["text"])
            return {"result": review}

        workflow.add_node("generate_quiz", generate_quiz_node)
        workflow.add_node("query", query_node)
        workflow.add_node("review", review_node)

        def route_mode(state: AgentState):
            mode = state["mode"]
            if mode == "quiz":
                return "generate_quiz"
            if mode == "query":
                return "query"
            return "review"

        workflow.add_conditional_edges(START, route_mode)
        workflow.add_edge("generate_quiz", END)
        workflow.add_edge("query", END)
        workflow.add_edge("review", END)
        return workflow.compile()

    def run(
        self,
        mode: str,
        text: str,
        question_count: int = 10,
        difficulty: str = "adaptive",
        question: str = "",
        focus_topics: list[str] | None = None,
        avoid_prompts: list[str] | None = None,
    ):
        initial_state: AgentState = {
            "mode": mode,
            "text": text,
            "question_count": question_count,
            "difficulty": difficulty,
            "focus_topics": focus_topics or [],
            "avoid_prompts": avoid_prompts or [],
            "question": question,
            "result": None,
        }
        result = self._graph.invoke(initial_state)
        return result.get("result")
