-- Quizify core schema
create extension if not exists "pgcrypto";

create table if not exists public.quizify_documents (
  id uuid primary key,
  user_id uuid not null,
  title text not null,
  source_type text not null,
  storage_path text,
  extracted_text text not null,
  file_metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.quizify_quiz_generations (
  id uuid primary key,
  user_id uuid not null,
  document_id uuid not null references public.quizify_documents(id) on delete cascade,
  question_count int not null check (question_count > 0 and question_count <= 20),
  difficulty text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.quizify_quiz_questions (
  id uuid primary key,
  quiz_id uuid not null references public.quizify_quiz_generations(id) on delete cascade,
  question_type text not null,
  prompt text not null,
  options jsonb not null default '[]'::jsonb,
  answer text not null,
  topic text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.quizify_quiz_attempts (
  id uuid primary key,
  user_id uuid not null,
  quiz_id uuid not null references public.quizify_quiz_generations(id) on delete cascade,
  score_percent numeric not null,
  created_at timestamptz not null default now()
);

create table if not exists public.quizify_quiz_answers (
  id uuid primary key,
  attempt_id uuid not null references public.quizify_quiz_attempts(id) on delete cascade,
  question_id uuid not null references public.quizify_quiz_questions(id) on delete cascade,
  user_answer text not null,
  is_correct boolean not null,
  created_at timestamptz not null default now()
);

create table if not exists public.quizify_query_logs (
  id uuid primary key,
  user_id uuid not null,
  document_id uuid not null references public.quizify_documents(id) on delete cascade,
  question text not null,
  answer text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.quizify_ai_reviews (
  id uuid primary key,
  user_id uuid not null,
  document_id uuid not null references public.quizify_documents(id) on delete cascade,
  review text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.quizify_progress_snapshots (
  id uuid primary key,
  user_id uuid not null,
  latest_score numeric not null,
  weak_topics jsonb not null default '[]'::jsonb,
  updated_at timestamptz not null default now()
);

create table if not exists public.quizify_document_chunks (
  id uuid primary key,
  user_id uuid not null,
  document_id uuid not null references public.quizify_documents(id) on delete cascade,
  chunk_order int not null,
  content text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.quizify_user_sessions (
  user_id uuid primary key,
  last_document_id uuid,
  last_quiz_id uuid,
  last_action text not null default 'dashboard',
  last_action_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Enable row level security
alter table public.quizify_documents enable row level security;
alter table public.quizify_quiz_generations enable row level security;
alter table public.quizify_quiz_questions enable row level security;
alter table public.quizify_quiz_attempts enable row level security;
alter table public.quizify_quiz_answers enable row level security;
alter table public.quizify_query_logs enable row level security;
alter table public.quizify_ai_reviews enable row level security;
alter table public.quizify_progress_snapshots enable row level security;
alter table public.quizify_document_chunks enable row level security;
alter table public.quizify_user_sessions enable row level security;

-- RLS policies based on auth.uid()
create policy if not exists "quizify_documents_own" on public.quizify_documents
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy if not exists "quizify_quiz_generations_own" on public.quizify_quiz_generations
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy if not exists "quizify_quiz_questions_via_quiz" on public.quizify_quiz_questions
  for select using (
    exists (
      select 1 from public.quizify_quiz_generations qg
      where qg.id = quiz_id and qg.user_id = auth.uid()
    )
  );

create policy if not exists "quizify_quiz_attempts_own" on public.quizify_quiz_attempts
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy if not exists "quizify_quiz_answers_via_attempt" on public.quizify_quiz_answers
  for select using (
    exists (
      select 1 from public.quizify_quiz_attempts qa
      where qa.id = attempt_id and qa.user_id = auth.uid()
    )
  );

create policy if not exists "quizify_query_logs_own" on public.quizify_query_logs
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy if not exists "quizify_ai_reviews_own" on public.quizify_ai_reviews
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy if not exists "quizify_progress_snapshots_own" on public.quizify_progress_snapshots
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy if not exists "quizify_document_chunks_own" on public.quizify_document_chunks
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy if not exists "quizify_user_sessions_own" on public.quizify_user_sessions
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
