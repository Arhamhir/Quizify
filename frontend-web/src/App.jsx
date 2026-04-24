import { useEffect, useMemo, useRef, useState } from "react";
import { createClient } from "@supabase/supabase-js";
import "./App.css";

const SUPABASE_URL = import.meta.env.VITE_SUPABASE_URL;
const SUPABASE_ANON_KEY = import.meta.env.VITE_SUPABASE_ANON_KEY;
const BACKEND_BASE_URL = (
  import.meta.env.VITE_BACKEND_BASE_URL || "http://localhost:8000"
).replace(/\/$/, "");

const supabase =
  SUPABASE_URL && SUPABASE_ANON_KEY
    ? createClient(SUPABASE_URL, SUPABASE_ANON_KEY)
    : null;

const PAGES = {
  HOME: "home",
  UPLOAD: "upload",
  QUIZ: "quiz",
  QUERY: "query",
  REVIEW: "review",
  PROGRESS: "progress",
};

const SOURCE_TYPES = [
  { value: "auto", label: "Auto Detect" },
  { value: "pdf", label: "PDF" },
  { value: "image", label: "Image" },
  { value: "camera", label: "Camera" },
  { value: "text", label: "Text" },
  { value: "docx", label: "DOCX" },
  { value: "pptx", label: "PPTX" },
];

const DIFFICULTIES = ["easy", "medium", "hard", "adaptive"];

function formatDate(value) {
  if (!value) {
    return "-";
  }
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    return "-";
  }
  return date.toLocaleString();
}

function detectSourceTypeFromName(fileName = "") {
  const ext = fileName.split(".").pop()?.toLowerCase() || "";
  if (ext === "pdf") {
    return "pdf";
  }
  if (["png", "jpg", "jpeg", "webp", "bmp", "tiff"].includes(ext)) {
    return "image";
  }
  if (["txt", "md", "csv"].includes(ext)) {
    return "text";
  }
  if (ext === "docx") {
    return "docx";
  }
  if (ext === "pptx") {
    return "pptx";
  }
  return "text";
}

function cleanMarkdownFormatting(text = "") {
  return text
    .replace(/```[\s\S]*?```/g, "")
    .replace(/\*\*/g, "")
    .trim();
}

function splitSections(raw = "") {
  const text = cleanMarkdownFormatting(raw);
  const lines = text.split("\n");
  const sections = [];
  let currentTitle = "Response";
  let buffer = [];

  const flush = () => {
    const body = buffer.join("\n").trim();
    if (body) {
      sections.push({ title: currentTitle, body });
    }
    buffer = [];
  };

  lines.forEach((line) => {
    const trimmed = line.trim();
    if (!trimmed) {
      buffer.push("");
      return;
    }

    const isHeader =
      /^#{1,4}\s+/.test(trimmed) ||
      /^[A-Za-z0-9][A-Za-z0-9\s/&-]{2,40}:$/.test(trimmed);
    if (isHeader) {
      flush();
      currentTitle = trimmed.replace(/^#{1,4}\s+/, "").replace(/:$/, "");
      return;
    }

    buffer.push(trimmed);
  });

  flush();
  return sections.length
    ? sections
    : [{ title: "Response", body: text || "No content." }];
}

async function callBackend(path, token, options = {}) {
  const headers = {
    Authorization: `Bearer ${token}`,
    ...(options.headers || {}),
  };

  if (!(options.body instanceof FormData) && !headers["Content-Type"]) {
    headers["Content-Type"] = "application/json";
  }

  const response = await fetch(`${BACKEND_BASE_URL}${path}`, {
    ...options,
    headers,
  });

  if (!response.ok) {
    let detail = "Request failed";
    try {
      const body = await response.json();
      detail = body.detail || detail;
    } catch {
      detail = response.statusText || detail;
    }
    throw new Error(detail);
  }

  const contentType = response.headers.get("content-type") || "";
  if (contentType.includes("application/json")) {
    return response.json();
  }
  return response.text();
}

function App() {
  const [session, setSession] = useState(null);
  const [activePage, setActivePage] = useState(PAGES.HOME);

  const [authMode, setAuthMode] = useState("signin");
  const [authLoading, setAuthLoading] = useState(false);
  const [authError, setAuthError] = useState("");
  const [authMessage, setAuthMessage] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");

  const [documents, setDocuments] = useState([]);
  const [progress, setProgress] = useState(null);
  const [recent, setRecent] = useState(null);
  const [continueState, setContinueState] = useState(null);
  const [globalLoading, setGlobalLoading] = useState(false);
  const [globalError, setGlobalError] = useState("");

  const [selectedDocumentForQuiz, setSelectedDocumentForQuiz] = useState("");
  const [selectedDocumentForQuery, setSelectedDocumentForQuery] = useState("");
  const [selectedDocumentForReview, setSelectedDocumentForReview] =
    useState("");

  const [uploadTitle, setUploadTitle] = useState("");
  const [uploadSourceType, setUploadSourceType] = useState("auto");
  const [uploadFallbackText, setUploadFallbackText] = useState("");
  const [uploadFile, setUploadFile] = useState(null);
  const [uploading, setUploading] = useState(false);
  const [uploadMessage, setUploadMessage] = useState("");
  const [deleteDocId, setDeleteDocId] = useState("");

  const [questionCount, setQuestionCount] = useState("10");
  const [difficulty, setDifficulty] = useState("adaptive");
  const [quizData, setQuizData] = useState(null);
  const [quizLoading, setQuizLoading] = useState(false);
  const [quizSubmitLoading, setQuizSubmitLoading] = useState(false);
  const [quizResult, setQuizResult] = useState(null);
  const [quizAnswers, setQuizAnswers] = useState({});
  const [questionReasons, setQuestionReasons] = useState({});
  const [reasonLoadingQuestionId, setReasonLoadingQuestionId] = useState("");
  const [quickNotes, setQuickNotes] = useState("");
  const [quickNotesLoading, setQuickNotesLoading] = useState(false);

  const [queryText, setQueryText] = useState("");
  const [queryAnswer, setQueryAnswer] = useState("");
  const [querySections, setQuerySections] = useState([]);
  const [queryLoading, setQueryLoading] = useState(false);

  const [reviewText, setReviewText] = useState("");
  const [reviewSections, setReviewSections] = useState([]);
  const [reviewLoading, setReviewLoading] = useState(false);

  const [showAllDocuments, setShowAllDocuments] = useState(false);
  const [showAllQuizzes, setShowAllQuizzes] = useState(false);
  const [showAllReviews, setShowAllReviews] = useState(false);
  const [deletingQuizId, setDeletingQuizId] = useState("");

  const fileInputRef = useRef(null);
  const cameraInputRef = useRef(null);

  const canUseApp = Boolean(supabase);
  const token = session?.access_token;

  useEffect(() => {
    if (!supabase) {
      return;
    }

    supabase.auth.getSession().then(({ data }) => {
      setSession(data.session || null);
    });

    const {
      data: { subscription },
    } = supabase.auth.onAuthStateChange((_event, nextSession) => {
      setSession(nextSession || null);
    });

    return () => subscription.unsubscribe();
  }, []);

  useEffect(() => {
    if (!token) {
      return;
    }
    loadCoreData(token, true);
  }, [token]);

  useEffect(() => {
    if (!documents.length) {
      return;
    }
    const first = documents[0].id;
    const continued = continueState?.last_document_id || "";
    const defaultDoc = continued || first;

    setSelectedDocumentForQuiz((prev) => prev || defaultDoc);
    setSelectedDocumentForQuery((prev) => prev || defaultDoc);
    setSelectedDocumentForReview((prev) => prev || defaultDoc);
  }, [documents, continueState]);

  const userName = useMemo(() => {
    const user = session?.user;
    if (!user) {
      return "Learner";
    }
    const metadataName =
      user.user_metadata?.full_name || user.user_metadata?.name;
    return metadataName || user.email || "Learner";
  }, [session]);

  const weakTopicsForQuizDoc = useMemo(() => {
    if (!progress?.weak_topics_by_document || !selectedDocumentForQuiz) {
      return null;
    }
    return (
      progress.weak_topics_by_document.find(
        (item) => item.document_id === selectedDocumentForQuiz,
      ) || null
    );
  }, [progress, selectedDocumentForQuiz]);

  async function loadCoreData(accessToken, force = false) {
    setGlobalLoading(true);
    if (force) {
      setGlobalError("");
    }
    try {
      const [docs, prog, rec, cont] = await Promise.all([
        callBackend("/v1/documents", accessToken),
        callBackend("/v1/progress", accessToken),
        callBackend("/v1/session/recent", accessToken),
        callBackend("/v1/session/continue", accessToken),
      ]);

      setDocuments(Array.isArray(docs) ? docs : []);
      setProgress(prog || null);
      setRecent(rec || null);
      setContinueState(cont || null);
    } catch (error) {
      setGlobalError(error.message || "Unable to load app data.");
    } finally {
      setGlobalLoading(false);
    }
  }

  function resetInteractiveStates() {
    setQuizData(null);
    setQuizResult(null);
    setQuizAnswers({});
    setQuestionReasons({});
    setReasonLoadingQuestionId("");
    setQuickNotes("");
    setQueryText("");
    setQueryAnswer("");
    setQuerySections([]);
    setReviewText("");
    setReviewSections([]);
  }

  async function handleEmailAuth(event) {
    event.preventDefault();
    setAuthError("");
    setAuthMessage("");

    if (!email || !password) {
      setAuthError("Email and password are required.");
      return;
    }

    if (authMode === "signup") {
      if (!confirmPassword) {
        setAuthError("Please confirm your password.");
        return;
      }
      if (password !== confirmPassword) {
        setAuthError("Passwords do not match.");
        return;
      }
      if (password.length < 6) {
        setAuthError("Password must be at least 6 characters.");
        return;
      }
    }

    setAuthLoading(true);
    try {
      if (authMode === "signup") {
        const { error } = await supabase.auth.signUp({ email, password });
        if (error) {
          throw error;
        }
        setAuthMessage(
          "Account created. Check your inbox for confirmation, then sign in.",
        );
      } else {
        const { error } = await supabase.auth.signInWithPassword({
          email,
          password,
        });
        if (error) {
          throw error;
        }
      }
    } catch (error) {
      setAuthError(error.message || "Authentication failed.");
    } finally {
      setAuthLoading(false);
    }
  }

  async function handleGoogleSignIn() {
    if (!supabase) {
      return;
    }
    setAuthError("");
    setAuthMessage("");
    setAuthLoading(true);
    try {
      const { error } = await supabase.auth.signInWithOAuth({
        provider: "google",
        options: { redirectTo: window.location.origin },
      });
      if (error) {
        throw error;
      }
    } catch (error) {
      setAuthError(error.message || "Google sign in failed.");
      setAuthLoading(false);
    }
  }

  async function handleSignOut() {
    if (!supabase) {
      return;
    }
    await supabase.auth.signOut();
    resetInteractiveStates();
    setDocuments([]);
    setProgress(null);
    setRecent(null);
    setContinueState(null);
    setActivePage(PAGES.HOME);
  }

  function handlePickedFile(file, fromCamera = false) {
    if (!file) {
      return;
    }
    setUploadFile(file);
    if (!uploadTitle.trim()) {
      setUploadTitle(fromCamera ? "Camera Capture" : file.name);
    }
    setUploadSourceType(
      fromCamera ? "camera" : detectSourceTypeFromName(file.name),
    );
    setUploadMessage("");
  }

  async function handleUploadDocument(event) {
    event.preventDefault();
    if (!token) {
      return;
    }
    if (!uploadFile) {
      setUploadMessage("Please select a file or capture an image first.");
      return;
    }

    setUploading(true);
    setUploadMessage("");

    try {
      const formData = new FormData();
      formData.append("title", uploadTitle.trim() || "Untitled Notes");
      formData.append("source_type", uploadSourceType);
      formData.append("extracted_text", uploadFallbackText.trim());
      formData.append("file", uploadFile, uploadFile.name || "upload.bin");

      const response = await callBackend("/v1/documents/upload", token, {
        method: "POST",
        body: formData,
      });

      setUploadMessage(
        `Saved successfully. Extracted chars: ${response.extracted_chars ?? 0}, chunks: ${response.chunk_count ?? 0}`,
      );
      await loadCoreData(token);
    } catch (error) {
      setUploadMessage(`Upload failed: ${error.message || "Unknown error."}`);
    } finally {
      setUploading(false);
    }
  }

  async function handleDeleteDocument(documentId) {
    if (!token || !documentId) {
      return;
    }
    setDeleteDocId(documentId);
    setUploadMessage("");
    try {
      await callBackend(`/v1/documents/${documentId}`, token, {
        method: "DELETE",
      });
      setUploadMessage("Document deleted.");
      await loadCoreData(token);
    } catch (error) {
      setUploadMessage(`Delete failed: ${error.message || "Unknown error."}`);
    } finally {
      setDeleteDocId("");
    }
  }

  function clearQuizState() {
    setQuizResult(null);
    setQuizAnswers({});
    setQuestionReasons({});
    setReasonLoadingQuestionId("");
  }

  async function handleGenerateQuiz(focusTopics = []) {
    if (!token || !selectedDocumentForQuiz) {
      return;
    }

    const parsedCount = Number.parseInt(questionCount, 10);
    if (!Number.isFinite(parsedCount) || parsedCount < 1 || parsedCount > 20) {
      setGlobalError("Question count must be between 1 and 20.");
      return;
    }

    setQuizLoading(true);
    setGlobalError("");
    clearQuizState();

    try {
      const quiz = await callBackend("/v1/quiz/generate", token, {
        method: "POST",
        body: JSON.stringify({
          document_id: selectedDocumentForQuiz,
          question_count: parsedCount,
          difficulty,
          focus_topics: focusTopics,
        }),
      });
      setQuizData(quiz);
    } catch (error) {
      setGlobalError(
        `Quiz generation failed: ${error.message || "Unknown error."}`,
      );
      setQuizData(null);
    } finally {
      setQuizLoading(false);
    }
  }

  async function handleSubmitQuiz() {
    if (!token || !quizData) {
      return;
    }

    setQuizSubmitLoading(true);
    setGlobalError("");

    try {
      const answers = (quizData.questions || []).map((question) => ({
        question_id: question.question_id,
        user_answer: (quizAnswers[question.question_id] || "").trim(),
      }));

      const result = await callBackend("/v1/quiz/submit", token, {
        method: "POST",
        body: JSON.stringify({ quiz_id: quizData.quiz_id, answers }),
      });

      setQuizResult(result);
      await loadCoreData(token);
    } catch (error) {
      setGlobalError(
        `Quiz submit failed: ${error.message || "Unknown error."}`,
      );
    } finally {
      setQuizSubmitLoading(false);
    }
  }

  async function handleExplainQuestion(questionId) {
    if (!token || !quizData || !questionId) {
      return;
    }

    const feedback = (quizResult?.question_feedback || []).find(
      (item) => item.question_id === questionId,
    );
    if (!feedback || feedback.is_correct) {
      return;
    }

    setReasonLoadingQuestionId(questionId);

    try {
      const response = await callBackend("/v1/quiz/reason", token, {
        method: "POST",
        body: JSON.stringify({
          quiz_id: quizData.quiz_id,
          question_id: questionId,
          user_answer: feedback.user_answer || "",
        }),
      });

      setQuestionReasons((prev) => ({
        ...prev,
        [questionId]: response.explanation || "",
      }));
    } catch (error) {
      setGlobalError(`AI reason failed: ${error.message || "Unknown error."}`);
    } finally {
      setReasonLoadingQuestionId("");
    }
  }

  async function handleGenerateQuickNotes(topics) {
    if (!token || !selectedDocumentForQuiz) {
      return;
    }
    setQuickNotesLoading(true);
    setGlobalError("");

    try {
      const response = await callBackend("/v1/agent/quick-notes", token, {
        method: "POST",
        body: JSON.stringify({
          document_id: selectedDocumentForQuiz,
          topics,
        }),
      });
      setQuickNotes(response.notes || "No notes generated.");
    } catch (error) {
      setGlobalError(
        `Quick notes failed: ${error.message || "Unknown error."}`,
      );
    } finally {
      setQuickNotesLoading(false);
    }
  }

  async function handleAskQuery(event) {
    event.preventDefault();
    if (!token || !selectedDocumentForQuery || !queryText.trim()) {
      return;
    }

    setQueryLoading(true);
    setQueryAnswer("");
    setQuerySections([]);
    setGlobalError("");

    try {
      const result = await callBackend("/v1/agent/query", token, {
        method: "POST",
        body: JSON.stringify({
          document_id: selectedDocumentForQuery,
          question: queryText.trim(),
        }),
      });
      const answer = result.answer || "";
      setQueryAnswer(cleanMarkdownFormatting(answer));
      setQuerySections(splitSections(answer));
      await loadCoreData(token);
    } catch (error) {
      setGlobalError(`Query failed: ${error.message || "Unknown error."}`);
    } finally {
      setQueryLoading(false);
    }
  }

  async function handleGenerateReview() {
    if (!token || !selectedDocumentForReview) {
      return;
    }

    setReviewLoading(true);
    setReviewText("");
    setReviewSections([]);
    setGlobalError("");

    try {
      const result = await callBackend("/v1/agent/review", token, {
        method: "POST",
        body: JSON.stringify({ document_id: selectedDocumentForReview }),
      });
      const review = result.review || "";
      setReviewText(cleanMarkdownFormatting(review));
      setReviewSections(splitSections(review));
      await loadCoreData(token);
    } catch (error) {
      setGlobalError(`Review failed: ${error.message || "Unknown error."}`);
    } finally {
      setReviewLoading(false);
    }
  }

  async function handleDeleteQuiz(quizId) {
    if (!token || !quizId) {
      return;
    }

    setDeletingQuizId(quizId);
    setGlobalError("");

    try {
      await callBackend(`/v1/quizzes/${quizId}`, token, { method: "DELETE" });
      await loadCoreData(token, true);
    } catch (error) {
      setGlobalError(
        `Delete quiz failed: ${error.message || "Unknown error."}`,
      );
    } finally {
      setDeletingQuizId("");
    }
  }

  function renderAuthPage() {
    return (
      <main className="app-shell auth-shell">
        <div className="bg-grid" aria-hidden="true" />
        <section className="auth-hero">
          <p className="eyebrow">Neural Learning Interface</p>
          <h1>Quizify</h1>
          <p>
            Upload study content, generate adaptive quizzes, ask a mentor-style
            AI, and iterate with targeted weak-topic practice.
          </p>
        </section>

        <section className="auth-card card smooth-card">
          <h2>{authMode === "signup" ? "Create Account" : "Sign In"}</h2>
          <p>Use email/password or continue with Google.</p>

          {authError && <div className="alert alert-error">{authError}</div>}
          {authMessage && (
            <div className="alert alert-success">{authMessage}</div>
          )}

          <form onSubmit={handleEmailAuth}>
            <div className="input-group">
              <label htmlFor="email">Email</label>
              <input
                id="email"
                type="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                autoComplete="email"
              />
            </div>

            <div className="input-group">
              <label htmlFor="password">Password</label>
              <input
                id="password"
                type="password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                autoComplete={
                  authMode === "signup" ? "new-password" : "current-password"
                }
              />
            </div>

            {authMode === "signup" && (
              <div className="input-group">
                <label htmlFor="confirm-password">Confirm Password</label>
                <input
                  id="confirm-password"
                  type="password"
                  value={confirmPassword}
                  onChange={(e) => setConfirmPassword(e.target.value)}
                  autoComplete="new-password"
                />
              </div>
            )}

            <button
              type="submit"
              className="btn btn-primary wide"
              disabled={authLoading}
            >
              {authLoading ? (
                <span className="loading" />
              ) : authMode === "signup" ? (
                "Create Account"
              ) : (
                "Sign In"
              )}
            </button>
          </form>

          <button
            type="button"
            className="btn btn-secondary wide"
            onClick={handleGoogleSignIn}
            disabled={authLoading}
          >
            Continue With Google
          </button>

          <p className="auth-switch">
            {authMode === "signup"
              ? "Already have an account?"
              : "New to Quizify?"}
            <button
              type="button"
              className="text-link"
              onClick={() => {
                setAuthMode((prev) =>
                  prev === "signup" ? "signin" : "signup",
                );
                setAuthError("");
                setAuthMessage("");
              }}
            >
              {authMode === "signup" ? "Sign In" : "Sign Up"}
            </button>
          </p>
        </section>
      </main>
    );
  }

  function renderTopShell() {
    const navItems = [
      { key: PAGES.HOME, label: "Home" },
      { key: PAGES.UPLOAD, label: "Upload" },
      { key: PAGES.QUIZ, label: "Quiz" },
      { key: PAGES.QUERY, label: "Query" },
      { key: PAGES.REVIEW, label: "Review" },
      { key: PAGES.PROGRESS, label: "Progress" },
    ];

    return (
      <>
        <header className="topbar card smooth-card">
          <div>
            <p className="eyebrow">Realtime Learning Intelligence</p>
            <h1>Quizify Control Room</h1>
            <p>Welcome back, {userName}</p>
          </div>
          <button className="btn btn-secondary" onClick={handleSignOut}>
            Sign Out
          </button>
        </header>

        <nav className="page-nav card smooth-card" aria-label="Primary">
          {navItems.map((item) => (
            <button
              key={item.key}
              type="button"
              className={`nav-pill ${activePage === item.key ? "active" : ""}`}
              onClick={() => setActivePage(item.key)}
            >
              {item.label}
            </button>
          ))}
        </nav>
      </>
    );
  }

  function renderHomePage() {
    const continueText = continueState?.last_action
      ? `Last action: ${continueState.last_action}${continueState.last_action_at ? ` • ${formatDate(continueState.last_action_at)}` : ""}`
      : "No recent session found yet.";

    return (
      <section className="page-body page-home">
        <article className="card smooth-card hero-card">
          <h2>Ready to Master Your Topics?</h2>
          <p>
            Use dedicated study modes below. Each mode is isolated so you can
            focus on one learning task at a time.
          </p>
          <div className="mini-stats">
            <div>
              <span>Documents</span>
              <strong>{documents.length}</strong>
            </div>
            <div>
              <span>Total Quizzes</span>
              <strong>{progress?.total_quizzes ?? 0}</strong>
            </div>
            <div>
              <span>Latest Score</span>
              <strong>{Number(progress?.latest_score ?? 0).toFixed(1)}%</strong>
            </div>
          </div>
        </article>

        <article className="card smooth-card">
          <h3>Continue Session</h3>
          <p>{continueText}</p>
          <div className="button-row">
            <button
              className="btn btn-soft"
              onClick={() => setActivePage(PAGES.QUIZ)}
              type="button"
            >
              Continue Quiz
            </button>
            <button
              className="btn btn-soft"
              onClick={() => setActivePage(PAGES.UPLOAD)}
              type="button"
            >
              Upload More Docs
            </button>
            <button
              className="btn btn-soft"
              onClick={() => setActivePage(PAGES.PROGRESS)}
              type="button"
            >
              Open Progress
            </button>
          </div>
        </article>
      </section>
    );
  }

  function renderUploadPage() {
    return (
      <section className="page-body page-upload">
        <article className="card smooth-card">
          <h2>Upload Documents</h2>
          <p>
            Upload PDF, DOCX, PPTX, images, or camera captures. Optionally
            include fallback text.
          </p>

          <form onSubmit={handleUploadDocument}>
            <div className="grid grid-2">
              <div className="input-group">
                <label htmlFor="upload-title">Document title</label>
                <input
                  id="upload-title"
                  value={uploadTitle}
                  onChange={(e) => setUploadTitle(e.target.value)}
                />
              </div>
              <div className="input-group">
                <label htmlFor="source-type">Source type</label>
                <select
                  id="source-type"
                  value={uploadSourceType}
                  onChange={(e) => setUploadSourceType(e.target.value)}
                >
                  {SOURCE_TYPES.map((item) => (
                    <option key={item.value} value={item.value}>
                      {item.label}
                    </option>
                  ))}
                </select>
              </div>
            </div>

            <div className="input-group">
              <label htmlFor="fallback-text">
                Fallback extracted text (optional)
              </label>
              <textarea
                id="fallback-text"
                rows={5}
                value={uploadFallbackText}
                onChange={(e) => setUploadFallbackText(e.target.value)}
              />
            </div>

            <div className="button-row">
              <button
                type="button"
                className="btn btn-secondary"
                onClick={() => fileInputRef.current?.click()}
                disabled={uploading}
              >
                Pick File
              </button>
              <button
                type="button"
                className="btn btn-secondary"
                onClick={() => cameraInputRef.current?.click()}
                disabled={uploading}
              >
                Capture
              </button>
              <button
                type="submit"
                className="btn btn-primary"
                disabled={uploading}
              >
                {uploading ? <span className="loading" /> : "Save Document"}
              </button>
            </div>

            <input
              ref={fileInputRef}
              className="hidden-input"
              type="file"
              onChange={(e) =>
                handlePickedFile(e.target.files?.[0] || null, false)
              }
            />
            <input
              ref={cameraInputRef}
              className="hidden-input"
              type="file"
              accept="image/*"
              capture="environment"
              onChange={(e) =>
                handlePickedFile(e.target.files?.[0] || null, true)
              }
            />

            {uploadFile && (
              <p className="note">Selected file: {uploadFile.name}</p>
            )}
            {uploadMessage && (
              <div className="alert alert-info">{uploadMessage}</div>
            )}
          </form>
        </article>

        <article className="card smooth-card">
          <div className="section-head">
            <h3>Uploaded Documents</h3>
            <button
              type="button"
              className="btn btn-soft"
              onClick={() => loadCoreData(token)}
              disabled={globalLoading}
            >
              Refresh
            </button>
          </div>

          {documents.length === 0 ? (
            <p>No uploaded documents yet.</p>
          ) : (
            <ul className="entity-list">
              {documents.map((doc) => (
                <li key={doc.id} className="entity-item">
                  <div>
                    <strong>{doc.title}</strong>
                    <p>{String(doc.source_type || "").toUpperCase()}</p>
                  </div>
                  <button
                    type="button"
                    className="btn btn-danger"
                    onClick={() => handleDeleteDocument(doc.id)}
                    disabled={deleteDocId === doc.id}
                  >
                    {deleteDocId === doc.id ? "Deleting..." : "Delete"}
                  </button>
                </li>
              ))}
            </ul>
          )}
        </article>
      </section>
    );
  }

  function renderQuizQuestion(question) {
    const feedback = (quizResult?.question_feedback || []).find(
      (item) => item.question_id === question.question_id,
    );
    const reason = questionReasons[question.question_id];
    const isWrong = feedback && !feedback.is_correct;

    return (
      <article
        key={question.question_id}
        className="card smooth-card question-card"
      >
        <h4>{question.prompt}</h4>
        <p className="note">Type: {question.question_type}</p>

        {question.question_type === "mcq" ? (
          <div className="input-group">
            <label>Select answer</label>
            <select
              value={quizAnswers[question.question_id] || ""}
              onChange={(e) =>
                setQuizAnswers((prev) => ({
                  ...prev,
                  [question.question_id]: e.target.value,
                }))
              }
            >
              <option value="">Choose...</option>
              {(question.options || []).map((opt) => (
                <option key={opt} value={opt}>
                  {opt}
                </option>
              ))}
            </select>
          </div>
        ) : (
          <div className="input-group">
            <label>
              {question.question_type === "fill_blank"
                ? "Fill in your answer"
                : "Answer"}
            </label>
            {question.question_type === "fill_blank" &&
              (question.options || []).length > 0 && (
                <div className="chip-wrap">
                  {(question.options || []).map((opt) => (
                    <button
                      key={opt}
                      type="button"
                      className="chip"
                      onClick={() =>
                        setQuizAnswers((prev) => ({
                          ...prev,
                          [question.question_id]: opt,
                        }))
                      }
                    >
                      {opt}
                    </button>
                  ))}
                </div>
              )}
            <textarea
              rows={2}
              value={quizAnswers[question.question_id] || ""}
              onChange={(e) =>
                setQuizAnswers((prev) => ({
                  ...prev,
                  [question.question_id]: e.target.value,
                }))
              }
            />
          </div>
        )}

        {feedback && (
          <div className={`feedback-box ${feedback.is_correct ? "ok" : "bad"}`}>
            <p>
              <strong>{feedback.is_correct ? "Correct" : "Incorrect"}</strong>
            </p>
            <p>Your answer: {feedback.user_answer || "No answer provided"}</p>
            <p>Correct answer: {feedback.correct_answer}</p>

            {isWrong && (
              <>
                <button
                  type="button"
                  className="btn btn-soft"
                  onClick={() => handleExplainQuestion(question.question_id)}
                  disabled={
                    reasonLoadingQuestionId === question.question_id ||
                    Boolean(reason)
                  }
                >
                  {reasonLoadingQuestionId === question.question_id
                    ? "Generating..."
                    : "AI Reason"}
                </button>
                {reason && <div className="reason-box">{reason}</div>}
              </>
            )}
          </div>
        )}
      </article>
    );
  }

  function renderQuizPage() {
    return (
      <section className="page-body page-quiz">
        <article className="card smooth-card">
          <h2>Generate Quiz</h2>
          <p>
            Adaptive MCQ, fill-blank, and short-answer questions with instant
            feedback.
          </p>

          <div className="grid grid-3">
            <div className="input-group">
              <label>Document</label>
              <select
                value={selectedDocumentForQuiz}
                onChange={(e) => setSelectedDocumentForQuiz(e.target.value)}
              >
                <option value="">Select document</option>
                {documents.map((doc) => (
                  <option key={doc.id} value={doc.id}>
                    {doc.title} ({doc.source_type})
                  </option>
                ))}
              </select>
            </div>

            <div className="input-group">
              <label>Question count (1-20)</label>
              <input
                value={questionCount}
                onChange={(e) =>
                  setQuestionCount(
                    e.target.value.replace(/[^0-9]/g, "").slice(0, 2),
                  )
                }
              />
            </div>

            <div className="input-group">
              <label>Difficulty</label>
              <select
                value={difficulty}
                onChange={(e) => setDifficulty(e.target.value)}
              >
                {DIFFICULTIES.map((item) => (
                  <option key={item} value={item}>
                    {item}
                  </option>
                ))}
              </select>
            </div>
          </div>

          <div className="button-row">
            <button
              type="button"
              className="btn btn-primary"
              onClick={() => handleGenerateQuiz()}
              disabled={quizLoading || !selectedDocumentForQuiz}
            >
              {quizLoading ? <span className="loading" /> : "Generate Quiz"}
            </button>
            {weakTopicsForQuizDoc?.topics?.length > 0 && (
              <>
                <button
                  type="button"
                  className="btn btn-soft"
                  onClick={() =>
                    handleGenerateQuiz(
                      weakTopicsForQuizDoc.topics.map((t) => t.topic),
                    )
                  }
                  disabled={quizLoading}
                >
                  Generate Practice Quiz
                </button>
                <button
                  type="button"
                  className="btn btn-soft"
                  onClick={() =>
                    handleGenerateQuickNotes(
                      weakTopicsForQuizDoc.topics.map((t) => t.topic),
                    )
                  }
                  disabled={quickNotesLoading}
                >
                  {quickNotesLoading ? "Generating..." : "AI Quick Notes"}
                </button>
              </>
            )}
          </div>

          {weakTopicsForQuizDoc?.topics?.length > 0 && (
            <div className="weak-doc-box">
              <h4>Weak Topics in This Document</h4>
              <ul className="list-clean">
                {weakTopicsForQuizDoc.topics.map((topic) => (
                  <li key={topic.topic}>
                    {topic.topic} • pending {topic.remaining_wrong} •{" "}
                    {topic.suggestion}
                  </li>
                ))}
              </ul>
            </div>
          )}

          {quickNotes && (
            <div className="quick-notes-box">
              <div className="section-head">
                <h4>Quick Notes</h4>
                <button
                  className="btn btn-soft"
                  onClick={() => navigator.clipboard.writeText(quickNotes)}
                  type="button"
                >
                  Copy
                </button>
              </div>
              <pre>{quickNotes}</pre>
            </div>
          )}
        </article>

        {quizData?.questions?.length > 0 && (
          <section className="questions-stack">
            {quizData.questions.map((question) => renderQuizQuestion(question))}
          </section>
        )}

        {quizData?.questions?.length > 0 && (
          <article className="card smooth-card">
            <button
              type="button"
              className="btn btn-primary"
              onClick={handleSubmitQuiz}
              disabled={quizSubmitLoading || Boolean(quizResult)}
            >
              {quizSubmitLoading ? (
                <span className="loading" />
              ) : (
                "Submit Attempt"
              )}
            </button>

            {quizResult && (
              <div className="quiz-summary">
                <h4>
                  Score: {Number(quizResult.score_percent || 0).toFixed(1)}%
                </h4>
                <p>{quizResult.next_step}</p>
                <h5>Weak Topics</h5>
                <ul className="list-clean">
                  {(quizResult.weak_topics || []).map((topic) => (
                    <li key={topic.topic}>
                      {topic.topic} • Wrong {topic.wrong_count} •{" "}
                      {topic.suggestion}
                    </li>
                  ))}
                </ul>
              </div>
            )}
          </article>
        )}
      </section>
    );
  }

  function renderQueryPage() {
    return (
      <section className="page-body page-query">
        <article className="card smooth-card">
          <h2>Ask Questions</h2>
          <p>Mentor-style answers from selected document context.</p>

          <form onSubmit={handleAskQuery}>
            <div className="input-group">
              <label>Document</label>
              <select
                value={selectedDocumentForQuery}
                onChange={(e) => setSelectedDocumentForQuery(e.target.value)}
              >
                <option value="">Select document</option>
                {documents.map((doc) => (
                  <option key={doc.id} value={doc.id}>
                    {doc.title} ({doc.source_type})
                  </option>
                ))}
              </select>
            </div>

            <div className="input-group">
              <label>Your question</label>
              <textarea
                rows={4}
                value={queryText}
                onChange={(e) => setQueryText(e.target.value)}
                placeholder="Ask a focused question from this document"
              />
            </div>

            <button
              type="submit"
              className="btn btn-primary"
              disabled={queryLoading || !selectedDocumentForQuery}
            >
              {queryLoading ? <span className="loading" /> : "Ask Mentor"}
            </button>
          </form>
        </article>

        {queryAnswer && (
          <article className="card smooth-card">
            <div className="section-head">
              <h3>Mentor Response</h3>
              <button
                className="btn btn-soft"
                type="button"
                onClick={() => navigator.clipboard.writeText(queryAnswer)}
              >
                Copy Full
              </button>
            </div>

            <div className="sections-wrap">
              {querySections.map((section) => (
                <section
                  key={`${section.title}-${section.body.slice(0, 16)}`}
                  className="response-section"
                >
                  <div className="section-head">
                    <h4>{section.title}</h4>
                    <button
                      className="btn btn-ghost"
                      type="button"
                      onClick={() =>
                        navigator.clipboard.writeText(
                          `${section.title}\n${section.body}`,
                        )
                      }
                    >
                      Copy
                    </button>
                  </div>
                  <p>{section.body}</p>
                </section>
              ))}
            </div>
          </article>
        )}
      </section>
    );
  }

  function renderReviewPage() {
    return (
      <section className="page-body page-review">
        <article className="card smooth-card">
          <h2>Review & Analyze</h2>
          <p>Generate structured AI insights for one selected document.</p>

          <div className="grid grid-2">
            <div className="input-group">
              <label>Document</label>
              <select
                value={selectedDocumentForReview}
                onChange={(e) => setSelectedDocumentForReview(e.target.value)}
              >
                <option value="">Select document</option>
                {documents.map((doc) => (
                  <option key={doc.id} value={doc.id}>
                    {doc.title} ({doc.source_type})
                  </option>
                ))}
              </select>
            </div>
            <div className="align-end">
              <button
                type="button"
                className="btn btn-accent"
                onClick={handleGenerateReview}
                disabled={reviewLoading || !selectedDocumentForReview}
              >
                {reviewLoading ? <span className="loading" /> : "Analyze"}
              </button>
            </div>
          </div>
        </article>

        {reviewText && (
          <article className="card smooth-card">
            <div className="section-head">
              <h3>Analysis Results</h3>
              <button
                className="btn btn-soft"
                onClick={() => navigator.clipboard.writeText(reviewText)}
                type="button"
              >
                Copy Full
              </button>
            </div>
            <div className="sections-wrap">
              {reviewSections.map((section) => (
                <section
                  key={`${section.title}-${section.body.slice(0, 16)}`}
                  className="response-section review-tone"
                >
                  <div className="section-head">
                    <h4>{section.title}</h4>
                    <button
                      className="btn btn-ghost"
                      type="button"
                      onClick={() =>
                        navigator.clipboard.writeText(
                          `${section.title}\n${section.body}`,
                        )
                      }
                    >
                      Copy
                    </button>
                  </div>
                  <p>{section.body}</p>
                </section>
              ))}
            </div>
          </article>
        )}
      </section>
    );
  }

  function renderProgressPage() {
    const docs = recent?.recent_documents || [];
    const quizzes = recent?.recent_quizzes || [];
    const reviews = recent?.recent_reviews || [];
    const docProgress = recent?.document_quiz_progress || [];

    const visibleDocs = showAllDocuments ? docs : docs.slice(0, 3);
    const visibleQuizzes = showAllQuizzes ? quizzes : quizzes.slice(0, 3);
    const visibleReviews = showAllReviews ? reviews : reviews.slice(0, 3);

    return (
      <section className="page-body page-progress">
        <article className="card smooth-card">
          <div className="section-head">
            <h2>Your Progress</h2>
            <button
              className="btn btn-soft"
              onClick={() => loadCoreData(token, true)}
              type="button"
              disabled={globalLoading}
            >
              Refresh
            </button>
          </div>

          <div className="grid grid-4 stats-grid">
            <div className="stat-tile">
              <span>Quizzes</span>
              <strong>{progress?.total_quizzes ?? 0}</strong>
            </div>
            <div className="stat-tile">
              <span>Attempts</span>
              <strong>{progress?.total_attempts ?? 0}</strong>
            </div>
            <div className="stat-tile">
              <span>Queries</span>
              <strong>{progress?.total_queries ?? 0}</strong>
            </div>
            <div className="stat-tile">
              <span>Latest Score</span>
              <strong>{Number(progress?.latest_score ?? 0).toFixed(1)}%</strong>
            </div>
          </div>

          {progress?.updated_at && (
            <p className="note">
              Last update: {formatDate(progress.updated_at)}
            </p>
          )}
        </article>

        <article className="card smooth-card">
          <div className="section-head">
            <h3>Recent Documents</h3>
            {docs.length > 3 && (
              <button
                type="button"
                className="btn btn-ghost"
                onClick={() => setShowAllDocuments((v) => !v)}
              >
                {showAllDocuments ? "View Less" : "View More"}
              </button>
            )}
          </div>
          {visibleDocs.length === 0 ? (
            <p>No recent documents.</p>
          ) : (
            <ul className="entity-list">
              {visibleDocs.map((doc) => {
                const analytics = docProgress.find(
                  (item) => item.document_id === doc.id,
                );
                return (
                  <li key={doc.id} className="entity-item stacked">
                    <div>
                      <strong>{doc.title}</strong>
                      <p>
                        {String(doc.source_type || "").toUpperCase()} •{" "}
                        {formatDate(doc.created_at)}
                      </p>
                      {analytics && (
                        <p className="note">
                          Quizzes {analytics.total_quizzes} • Right{" "}
                          {analytics.total_correct} • Wrong{" "}
                          {analytics.total_wrong}
                        </p>
                      )}
                    </div>
                    {analytics?.points?.length > 0 && (
                      <div className="mini-bars" aria-label="Score trend">
                        {analytics.points.slice(-10).map((point) => (
                          <div
                            key={point.quiz_id}
                            className="bar-wrap"
                            title={`${point.score_percent.toFixed(1)}%`}
                          >
                            <div
                              className="bar"
                              style={{
                                height: `${Math.max(12, Math.min(100, point.score_percent))}%`,
                              }}
                            />
                          </div>
                        ))}
                      </div>
                    )}
                  </li>
                );
              })}
            </ul>
          )}
        </article>

        <article className="card smooth-card">
          <div className="section-head">
            <h3>Recent Quizzes</h3>
            {quizzes.length > 3 && (
              <button
                type="button"
                className="btn btn-ghost"
                onClick={() => setShowAllQuizzes((v) => !v)}
              >
                {showAllQuizzes ? "View Less" : "View More"}
              </button>
            )}
          </div>
          {visibleQuizzes.length === 0 ? (
            <p>No recent quizzes yet.</p>
          ) : (
            <ul className="entity-list">
              {visibleQuizzes.map((quiz) => (
                <li key={quiz.id} className="entity-item stacked">
                  <div>
                    <strong>{quiz.title?.trim() ? quiz.title : "Quiz"}</strong>
                    <p>
                      {quiz.difficulty} • {formatDate(quiz.created_at)}
                    </p>
                    <p className="note">
                      Right {quiz.correct_answers} • Wrong {quiz.wrong_answers}{" "}
                      • Score{" "}
                      {quiz.latest_score == null
                        ? "No attempt"
                        : `${Number(quiz.latest_score).toFixed(1)}%`}
                    </p>
                  </div>
                  <button
                    type="button"
                    className="btn btn-danger"
                    onClick={() => handleDeleteQuiz(quiz.id)}
                    disabled={deletingQuizId === quiz.id}
                  >
                    {deletingQuizId === quiz.id ? "Deleting..." : "Delete Quiz"}
                  </button>
                </li>
              ))}
            </ul>
          )}
        </article>

        <article className="card smooth-card">
          <div className="section-head">
            <h3>Saved Reviews</h3>
            {reviews.length > 3 && (
              <button
                type="button"
                className="btn btn-ghost"
                onClick={() => setShowAllReviews((v) => !v)}
              >
                {showAllReviews ? "View Less" : "View More"}
              </button>
            )}
          </div>

          {visibleReviews.length === 0 ? (
            <p>No saved reviews yet.</p>
          ) : (
            <ul className="entity-list">
              {visibleReviews.map((review) => (
                <li key={review.id} className="entity-item stacked">
                  <div>
                    <strong>
                      {review.document_title?.trim()
                        ? review.document_title
                        : "Review"}
                    </strong>
                    <p>{formatDate(review.created_at)}</p>
                  </div>
                  <div className="button-row">
                    <button
                      className="btn btn-ghost"
                      type="button"
                      onClick={() =>
                        navigator.clipboard.writeText(review.review)
                      }
                    >
                      Copy
                    </button>
                    <button
                      className="btn btn-soft"
                      type="button"
                      onClick={() => {
                        setReviewText(cleanMarkdownFormatting(review.review));
                        setReviewSections(splitSections(review.review));
                        setActivePage(PAGES.REVIEW);
                      }}
                    >
                      View
                    </button>
                  </div>
                </li>
              ))}
            </ul>
          )}
        </article>
      </section>
    );
  }

  function renderPage() {
    switch (activePage) {
      case PAGES.UPLOAD:
        return renderUploadPage();
      case PAGES.QUIZ:
        return renderQuizPage();
      case PAGES.QUERY:
        return renderQueryPage();
      case PAGES.REVIEW:
        return renderReviewPage();
      case PAGES.PROGRESS:
        return renderProgressPage();
      case PAGES.HOME:
      default:
        return renderHomePage();
    }
  }

  if (!canUseApp) {
    return (
      <main className="app-shell">
        <section className="setup-warning card smooth-card">
          <h2>Configuration Required</h2>
          <p>
            Add <strong>VITE_SUPABASE_URL</strong>,{" "}
            <strong>VITE_SUPABASE_ANON_KEY</strong>, and optionally{" "}
            <strong>VITE_BACKEND_BASE_URL</strong>.
          </p>
        </section>
      </main>
    );
  }

  if (!session) {
    return renderAuthPage();
  }

  return (
    <main className="app-shell dashboard-shell">
      <div className="bg-grid" aria-hidden="true" />
      {renderTopShell()}
      {globalError && <div className="alert alert-error">{globalError}</div>}
      {globalLoading && <div className="top-loader" />}
      {renderPage()}
    </main>
  );
}

export default App;
