-- teacherflavius.com Supabase schema baseline
-- Generated from production schema. Schema only: no application rows or secrets.
-- Prerequisites: a fresh Supabase Postgres project with auth/storage schemas.

set check_function_bodies = false;
set search_path = public, auth, extensions, pg_catalog;

create extension if not exists pg_net with schema extensions;
create extension if not exists supabase_vault with schema vault;

-- Tables
create table public.profiles (
  id uuid not null,
  name text,
  email text,
  created_at timestamp with time zone default now(),
  cpf text,
  whatsapp text,
  enrollment_code text,
  enrolled boolean default false not null,
  pix_key text,
  availability jsonb default '{}'::jsonb not null,
  availability_seg_09 boolean default false not null,
  availability_seg_10 boolean default false not null,
  availability_seg_12 boolean default false not null,
  availability_seg_13 boolean default false not null,
  availability_seg_15 boolean default false not null,
  availability_seg_17 boolean default false not null,
  availability_seg_18 boolean default false not null,
  availability_seg_20 boolean default false not null,
  availability_seg_21 boolean default false not null,
  availability_ter_09 boolean default false not null,
  availability_ter_10 boolean default false not null,
  availability_ter_12 boolean default false not null,
  availability_ter_13 boolean default false not null,
  availability_ter_15 boolean default false not null,
  availability_ter_17 boolean default false not null,
  availability_ter_18 boolean default false not null,
  availability_ter_20 boolean default false not null,
  availability_ter_21 boolean default false not null,
  availability_qua_09 boolean default false not null,
  availability_qua_10 boolean default false not null,
  availability_qua_12 boolean default false not null,
  availability_qua_13 boolean default false not null,
  availability_qua_15 boolean default false not null,
  availability_qua_17 boolean default false not null,
  availability_qua_18 boolean default false not null,
  availability_qua_20 boolean default false not null,
  availability_qua_21 boolean default false not null,
  availability_qui_09 boolean default false not null,
  availability_qui_10 boolean default false not null,
  availability_qui_12 boolean default false not null,
  availability_qui_13 boolean default false not null,
  availability_qui_15 boolean default false not null,
  availability_qui_17 boolean default false not null,
  availability_qui_18 boolean default false not null,
  availability_qui_20 boolean default false not null,
  availability_qui_21 boolean default false not null,
  availability_sex_09 boolean default false not null,
  availability_sex_10 boolean default false not null,
  availability_sex_12 boolean default false not null,
  availability_sex_13 boolean default false not null,
  availability_sex_15 boolean default false not null,
  availability_sex_17 boolean default false not null,
  availability_sex_18 boolean default false not null,
  availability_sex_20 boolean default false not null,
  availability_sex_21 boolean default false not null,
  exercise_schedule_start_date date,
  archived boolean default false not null,
  archived_at timestamp with time zone,
  class_type text,
  profile_completed boolean default false not null,
  first_portal_access_at timestamp with time zone,
  last_portal_access_at timestamp with time zone,
  date_of_birth date
);

create table public.activity_results (
  id uuid default gen_random_uuid() not null,
  user_id uuid not null,
  activity_type text not null,
  activity_title text not null,
  score integer not null,
  total integer not null,
  percentage integer not null,
  completed_at timestamp with time zone default now()
);

create table public.student_frequency (
  id uuid default gen_random_uuid() not null,
  user_id uuid,
  class_date date not null,
  attendance_status text not null,
  class_notes text,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null,
  invite_id uuid
);

create table public.teacher_admins (
  id uuid default gen_random_uuid() not null,
  user_id uuid,
  email text not null,
  created_at timestamp with time zone default now() not null
);

create table public.student_enrollments (
  id uuid default gen_random_uuid() not null,
  user_id uuid,
  name text,
  cpf text,
  email text,
  whatsapp text,
  pix_key text,
  availability jsonb default '{}'::jsonb,
  enrollment_code text,
  enrolled boolean default true,
  created_at timestamp with time zone default now() not null
);

create table public.daily_exercise_completion (
  id uuid default gen_random_uuid() not null,
  user_id uuid not null,
  exercise_id text not null,
  exercise_title text not null,
  exercise_url text,
  completed boolean default false not null,
  completed_at timestamp with time zone,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null,
  completion_source text default 'unknown'::text not null,
  completed_by uuid,
  completed_by_email text
);

create table public.class_students (
  id uuid default gen_random_uuid() not null,
  class_number integer not null,
  user_id uuid,
  created_at timestamp with time zone default now() not null,
  invite_id uuid
);

create table public.study_roadmap_completion (
  id uuid default gen_random_uuid() not null,
  user_id uuid not null,
  lesson_id text not null,
  lesson_number integer not null,
  lesson_title text not null,
  completed boolean default false not null,
  completed_at timestamp with time zone,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null
);

create table public.class_resources (
  id uuid default gen_random_uuid() not null,
  class_number integer not null,
  video_lesson_url text,
  lesson_material_url text,
  whatsapp_group_url text,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null,
  recorded_lessons_url text
);

create table public.teacher_exercises (
  id uuid default gen_random_uuid() not null,
  exercise_id text not null,
  exercise_title text not null,
  exercise_url text not null,
  created_by uuid,
  is_active boolean default true not null,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null,
  scheduled_publish_at timestamp with time zone
);

create table public.teacher_classes (
  id uuid default gen_random_uuid() not null,
  class_number integer not null,
  class_name text not null,
  is_active boolean default true not null,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null,
  display_order integer,
  class_type text,
  class_weekday smallint,
  class_start_time time without time zone,
  makeup_slots_enabled boolean default true not null
);

create table public.class_lesson_records (
  id uuid default gen_random_uuid() not null,
  class_number integer not null,
  user_id uuid,
  class_date date not null,
  lesson_code text not null,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null,
  invite_id uuid
);

create table public.student_private_data (
  user_id uuid not null,
  cpf text,
  whatsapp text,
  pix_key text,
  consent_lgpd boolean default false not null,
  consent_lgpd_at timestamp with time zone,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null
);

create table public.backup_profiles_20260501 (
  id uuid,
  name text,
  email text,
  created_at timestamp with time zone,
  cpf text,
  whatsapp text,
  enrollment_code text,
  enrolled boolean,
  pix_key text,
  availability jsonb,
  availability_seg_09 boolean,
  availability_seg_10 boolean,
  availability_seg_12 boolean,
  availability_seg_13 boolean,
  availability_seg_15 boolean,
  availability_seg_17 boolean,
  availability_seg_18 boolean,
  availability_seg_20 boolean,
  availability_seg_21 boolean,
  availability_ter_09 boolean,
  availability_ter_10 boolean,
  availability_ter_12 boolean,
  availability_ter_13 boolean,
  availability_ter_15 boolean,
  availability_ter_17 boolean,
  availability_ter_18 boolean,
  availability_ter_20 boolean,
  availability_ter_21 boolean,
  availability_qua_09 boolean,
  availability_qua_10 boolean,
  availability_qua_12 boolean,
  availability_qua_13 boolean,
  availability_qua_15 boolean,
  availability_qua_17 boolean,
  availability_qua_18 boolean,
  availability_qua_20 boolean,
  availability_qua_21 boolean,
  availability_qui_09 boolean,
  availability_qui_10 boolean,
  availability_qui_12 boolean,
  availability_qui_13 boolean,
  availability_qui_15 boolean,
  availability_qui_17 boolean,
  availability_qui_18 boolean,
  availability_qui_20 boolean,
  availability_qui_21 boolean,
  availability_sex_09 boolean,
  availability_sex_10 boolean,
  availability_sex_12 boolean,
  availability_sex_13 boolean,
  availability_sex_15 boolean,
  availability_sex_17 boolean,
  availability_sex_18 boolean,
  availability_sex_20 boolean,
  availability_sex_21 boolean
);

create table public.backup_student_private_data_20260501 (
  user_id uuid,
  cpf text,
  whatsapp text,
  pix_key text,
  consent_lgpd boolean,
  consent_lgpd_at timestamp with time zone,
  created_at timestamp with time zone,
  updated_at timestamp with time zone
);

create table public.backup_auth_users_metadata_20260501 (
  id uuid,
  email character varying(255),
  raw_user_meta_data jsonb,
  created_at timestamp with time zone,
  updated_at timestamp with time zone
);

create table public.grammar_lessons (
  id uuid default gen_random_uuid() not null,
  title text not null,
  video_url text not null,
  exercise_url text not null,
  created_by uuid,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null
);

create table public.grammar_lesson_completion (
  id uuid default gen_random_uuid() not null,
  user_id uuid not null,
  lesson_id uuid not null,
  completed boolean default false not null,
  completed_at timestamp with time zone,
  updated_at timestamp with time zone default now() not null
);

create table public.student_enrollment_invites (
  id uuid default gen_random_uuid() not null,
  invite_code text not null,
  student_name text not null,
  notes text,
  status text default 'pending'::text not null,
  user_id uuid,
  email text,
  cpf text,
  whatsapp text,
  pix_key text,
  availability jsonb default '{}'::jsonb not null,
  created_by uuid,
  created_at timestamp with time zone default now() not null,
  completed_at timestamp with time zone,
  expires_at timestamp with time zone
);

create table public.student_tags (
  id uuid default gen_random_uuid() not null,
  user_id uuid,
  invite_id uuid,
  tag_name text not null,
  created_by uuid,
  created_at timestamp with time zone default now() not null
);

create table public.student_billing_settings (
  student_id uuid not null,
  monthly_fee numeric(10,2) not null,
  due_day smallint not null,
  billing_start_month date not null,
  active boolean default true not null,
  notes text,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null,
  updated_by uuid
);

create table public.monthly_tuition (
  id uuid default gen_random_uuid() not null,
  student_id uuid not null,
  reference_month date not null,
  due_date date not null,
  amount_due numeric(10,2) not null,
  payment_date date,
  amount_paid numeric(10,2),
  payment_method text,
  payment_notes text,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null,
  created_by uuid,
  updated_by uuid,
  payment_provider text,
  provider_payment_id text
);

create table public.monthly_tuition_events (
  id uuid default gen_random_uuid() not null,
  tuition_id uuid not null,
  action text not null,
  actor_id uuid,
  details jsonb default '{}'::jsonb not null,
  created_at timestamp with time zone default now() not null
);

create table public.enrollment_email_notifications (
  id uuid default gen_random_uuid() not null,
  student_id uuid not null,
  status text default 'pending'::text not null,
  attempts integer default 0 not null,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null,
  last_attempt_at timestamp with time zone,
  sent_at timestamp with time zone,
  last_error text
);

create table public.makeup_class_slots (
  id uuid default gen_random_uuid() not null,
  starts_at timestamp with time zone not null,
  ends_at timestamp with time zone not null,
  capacity integer default 1 not null,
  notes text,
  is_active boolean default true not null,
  created_by uuid,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null,
  class_number integer,
  class_name text,
  meeting_url text,
  is_auto_generated boolean default false not null
);

create table public.makeup_class_bookings (
  id uuid default gen_random_uuid() not null,
  slot_id uuid not null,
  student_id uuid not null,
  class_number integer not null,
  class_name text not null,
  student_name text not null,
  student_email text not null,
  meeting_url text not null,
  status text default 'confirmed'::text not null,
  booked_at timestamp with time zone default now() not null,
  cancelled_at timestamp with time zone
);

create table public.makeup_class_email_notifications (
  id uuid default gen_random_uuid() not null,
  booking_id uuid not null,
  status text default 'pending'::text not null,
  attempts integer default 0 not null,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null,
  last_attempt_at timestamp with time zone,
  sent_at timestamp with time zone,
  last_error text,
  notification_type text default 'booking_confirmation'::text not null
);

create table public.student_access_logs (
  id uuid default gen_random_uuid() not null,
  user_id uuid not null,
  accessed_at timestamp with time zone default now() not null,
  page_path text not null,
  page_title text,
  timezone text
);

create table public.flashcard_decks (
  id uuid default gen_random_uuid() not null,
  owner_id uuid not null,
  title text not null,
  description text,
  is_shared boolean default false not null,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null
);

create table public.flashcards (
  id uuid default gen_random_uuid() not null,
  deck_id uuid not null,
  english_word text not null,
  translation text not null,
  "position" integer default 0 not null,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null
);

create table public.flashcard_practice_days (
  user_id uuid not null,
  practice_date date not null,
  created_at timestamp with time zone default now() not null
);

create table public.exercise_sync_runs (
  id uuid default gen_random_uuid() not null,
  report_date date default ((now() AT TIME ZONE 'America/Sao_Paulo'::text))::date not null,
  started_at timestamp with time zone default now() not null,
  finished_at timestamp with time zone,
  status text default 'success'::text not null,
  spreadsheets_processed integer default 0 not null,
  activities_processed integer default 0 not null,
  unique_students_synced integer default 0 not null,
  exact_matches integer default 0 not null,
  similarity_matches integer default 0 not null,
  unmatched_emails integer default 0 not null,
  inserted_records integer default 0 not null,
  updated_records integer default 0 not null,
  per_activity jsonb default '[]'::jsonb not null,
  similarity_match_details jsonb default '[]'::jsonb not null,
  unmatched_email_details jsonb default '[]'::jsonb not null,
  errors jsonb default '[]'::jsonb not null,
  summary_text text,
  created_at timestamp with time zone default now() not null
);

create table public.weekly_plan_snapshots (
  id uuid default gen_random_uuid() not null,
  user_id uuid not null,
  week_number integer not null,
  week_start date not null,
  week_end date not null,
  roadmap_target_lesson integer,
  created_at timestamp with time zone default now() not null
);

create table public.weekly_student_tasks (
  id uuid default gen_random_uuid() not null,
  user_id uuid not null,
  week_start date not null,
  week_end date not null,
  title text not null,
  description text,
  target_url text,
  completed boolean default false not null,
  completed_at timestamp with time zone,
  created_by uuid default auth.uid(),
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null
);

create table public.exercise_form_sources (
  id uuid default gen_random_uuid() not null,
  exercise_id text not null,
  spreadsheet_id text not null,
  spreadsheet_url text not null,
  import_existing boolean default true not null,
  status text default 'pending'::text not null,
  created_by uuid,
  trigger_created_at timestamp with time zone,
  historical_sync_at timestamp with time zone,
  historical_processed integer default 0 not null,
  historical_unmatched integer default 0 not null,
  last_error text,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null
);

create table public.tuition_payment_attempts (
  id uuid default gen_random_uuid() not null,
  tuition_id uuid not null,
  student_id uuid not null,
  provider text default 'mercado_pago'::text not null,
  provider_payment_id text,
  idempotency_key uuid not null,
  amount numeric(10,2) not null,
  payment_method text,
  status text default 'created'::text not null,
  status_detail text,
  live_mode boolean,
  provider_created_at timestamp with time zone,
  provider_updated_at timestamp with time zone,
  applied_at timestamp with time zone,
  reversed_at timestamp with time zone,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null
);

create table public.pronunciation_assignments (
  id uuid default gen_random_uuid() not null,
  title text not null,
  reference_text text not null,
  locale text default 'en-US'::text not null,
  is_active boolean default true not null,
  max_recording_seconds integer default 300 not null,
  created_by uuid,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null
);

create table public.pronunciation_attempts (
  id uuid default gen_random_uuid() not null,
  user_id uuid not null,
  assignment_id uuid,
  reference_text text not null,
  locale text default 'en-US'::text not null,
  audio_path text,
  duration_seconds numeric(8,2),
  accuracy_score numeric(5,2),
  fluency_score numeric(5,2),
  completeness_score numeric(5,2),
  pronunciation_score numeric(5,2),
  prosody_score numeric(5,2),
  words jsonb default '[]'::jsonb not null,
  azure_result jsonb,
  teacher_feedback text,
  status text default 'processed'::text not null,
  error_message text,
  created_at timestamp with time zone default now() not null,
  reviewed_at timestamp with time zone
);

create table public.exercise_sync_events (
  id uuid default gen_random_uuid() not null,
  received_at timestamp with time zone default now() not null,
  status text not null,
  exercise_id text,
  exercise_title text,
  source_email text,
  normalized_email text,
  user_id uuid,
  student_name text,
  submitted_completed_at timestamp with time zone,
  stored_completed_at timestamp with time zone,
  record_action text,
  error_message text,
  metadata jsonb default '{}'::jsonb not null
);

create table public.student_google_email_aliases (
  google_email text not null,
  enrollment_email text not null,
  active boolean default true not null,
  note text,
  created_at timestamp with time zone default now() not null
);

create table public.student_google_account_links (
  google_user_id uuid not null,
  legacy_user_id uuid not null,
  enrollment_email text not null,
  google_email text not null,
  link_mode text not null,
  confirmed_at timestamp with time zone default now() not null,
  legacy_auth_deleted boolean default false not null,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null
);

create table public.api_rate_limit_buckets (
  bucket_key text not null,
  window_start timestamp with time zone not null,
  request_count integer default 0 not null,
  updated_at timestamp with time zone default now() not null
);

create table public.flashcard_srs (
  user_id uuid not null,
  card_id uuid not null,
  ease_factor numeric(4,2) default 2.50 not null,
  interval_days integer default 0 not null,
  repetitions integer default 0 not null,
  lapses integer default 0 not null,
  due_date date default ((now() AT TIME ZONE 'America/Sao_Paulo'::text))::date not null,
  last_grade text,
  last_reviewed_at timestamp with time zone,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null
);

create table public.flashcard_review_history (
  id uuid default gen_random_uuid() not null,
  user_id uuid not null,
  card_id uuid not null,
  grade text not null,
  reviewed_at timestamp with time zone default now() not null,
  interval_days_after integer not null,
  due_date_after date not null,
  ease_factor_after numeric(4,2) not null,
  repetitions_after integer not null
);

create table public.csp_violation_reports (
  id uuid default gen_random_uuid() not null,
  document_uri text,
  violated_directive text,
  effective_directive text,
  blocked_uri text,
  source_file text,
  line_number integer,
  column_number integer,
  status_code integer,
  disposition text,
  referrer text,
  created_at timestamp with time zone default now() not null
);

create table public.app_error_events (
  id uuid default gen_random_uuid() not null,
  event_type text not null,
  severity text default 'error'::text not null,
  message text not null,
  source text,
  path text,
  stack text,
  error_code text,
  http_status integer,
  http_method text,
  fingerprint text,
  metadata jsonb default '{}'::jsonb not null,
  occurred_at timestamp with time zone default now() not null,
  created_at timestamp with time zone default now() not null,
  resolved_at timestamp with time zone
);

-- Constraints
alter table only public.profiles add constraint profiles_pkey PRIMARY KEY (id);
alter table only public.profiles add constraint profiles_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;
alter table only public.activity_results add constraint activity_results_pkey PRIMARY KEY (id);
alter table only public.activity_results add constraint activity_results_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
alter table only public.student_frequency add constraint student_frequency_attendance_status_check CHECK (attendance_status = ANY (ARRAY['Compareceu'::text, 'Faltou'::text]));
alter table only public.student_frequency add constraint student_frequency_pkey PRIMARY KEY (id);
alter table only public.student_frequency add constraint student_frequency_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
alter table only public.teacher_admins add constraint teacher_admins_pkey PRIMARY KEY (id);
alter table only public.teacher_admins add constraint teacher_admins_email_key UNIQUE (email);
alter table only public.teacher_admins add constraint teacher_admins_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
alter table only public.student_enrollments add constraint student_enrollments_pkey PRIMARY KEY (id);
alter table only public.student_enrollments add constraint student_enrollments_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
alter table only public.daily_exercise_completion add constraint daily_exercise_completion_pkey PRIMARY KEY (id);
alter table only public.daily_exercise_completion add constraint daily_exercise_completion_user_id_exercise_id_key UNIQUE (user_id, exercise_id);
alter table only public.daily_exercise_completion add constraint daily_exercise_completion_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
alter table only public.class_students add constraint class_students_pkey PRIMARY KEY (id);
alter table only public.class_students add constraint class_students_class_number_user_id_key UNIQUE (class_number, user_id);
alter table only public.class_students add constraint class_students_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
alter table only public.study_roadmap_completion add constraint study_roadmap_completion_lesson_number_check CHECK (lesson_number >= 1 AND lesson_number <= 24);
alter table only public.study_roadmap_completion add constraint study_roadmap_completion_pkey PRIMARY KEY (id);
alter table only public.study_roadmap_completion add constraint study_roadmap_completion_user_id_lesson_id_key UNIQUE (user_id, lesson_id);
alter table only public.study_roadmap_completion add constraint study_roadmap_completion_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
alter table only public.class_resources add constraint class_resources_pkey PRIMARY KEY (id);
alter table only public.class_resources add constraint class_resources_class_number_key UNIQUE (class_number);
alter table only public.teacher_exercises add constraint teacher_exercises_pkey PRIMARY KEY (id);
alter table only public.teacher_exercises add constraint teacher_exercises_exercise_id_key UNIQUE (exercise_id);
alter table only public.teacher_exercises add constraint teacher_exercises_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id) ON DELETE SET NULL;
alter table only public.teacher_classes add constraint teacher_classes_pkey PRIMARY KEY (id);
alter table only public.teacher_classes add constraint teacher_classes_class_number_key UNIQUE (class_number);
alter table only public.class_lesson_records add constraint class_lesson_records_pkey PRIMARY KEY (id);
alter table only public.class_lesson_records add constraint class_lesson_records_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
alter table only public.student_private_data add constraint student_private_data_pkey PRIMARY KEY (user_id);
alter table only public.student_private_data add constraint student_private_data_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
alter table only public.grammar_lessons add constraint grammar_lessons_pkey PRIMARY KEY (id);
alter table only public.grammar_lessons add constraint grammar_lessons_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id) ON DELETE SET NULL;
alter table only public.grammar_lesson_completion add constraint grammar_lesson_completion_pkey PRIMARY KEY (id);
alter table only public.grammar_lesson_completion add constraint grammar_lesson_completion_user_id_lesson_id_key UNIQUE (user_id, lesson_id);
alter table only public.grammar_lesson_completion add constraint grammar_lesson_completion_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
alter table only public.grammar_lesson_completion add constraint grammar_lesson_completion_lesson_id_fkey FOREIGN KEY (lesson_id) REFERENCES grammar_lessons(id) ON DELETE CASCADE;
alter table only public.student_enrollment_invites add constraint student_enrollment_invites_status_check CHECK (status = ANY (ARRAY['pending'::text, 'completed'::text, 'cancelled'::text, 'expired'::text]));
alter table only public.student_enrollment_invites add constraint student_enrollment_invites_pkey PRIMARY KEY (id);
alter table only public.student_enrollment_invites add constraint student_enrollment_invites_invite_code_key UNIQUE (invite_code);
alter table only public.student_enrollment_invites add constraint student_enrollment_invites_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE SET NULL;
alter table only public.student_enrollment_invites add constraint student_enrollment_invites_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id) ON DELETE SET NULL;
alter table only public.class_students add constraint class_students_invite_id_fkey FOREIGN KEY (invite_id) REFERENCES student_enrollment_invites(id) ON DELETE CASCADE;
alter table only public.student_frequency add constraint student_frequency_invite_id_fkey FOREIGN KEY (invite_id) REFERENCES student_enrollment_invites(id) ON DELETE CASCADE;
alter table only public.student_tags add constraint student_tags_check CHECK (user_id IS NOT NULL OR invite_id IS NOT NULL);
alter table only public.student_tags add constraint student_tags_pkey PRIMARY KEY (id);
alter table only public.student_tags add constraint student_tags_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
alter table only public.student_tags add constraint student_tags_invite_id_fkey FOREIGN KEY (invite_id) REFERENCES student_enrollment_invites(id) ON DELETE CASCADE;
alter table only public.student_tags add constraint student_tags_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id) ON DELETE SET NULL;
alter table only public.class_lesson_records add constraint class_lesson_records_invite_id_fkey FOREIGN KEY (invite_id) REFERENCES student_enrollment_invites(id) ON DELETE CASCADE;
alter table only public.class_lesson_records add constraint class_lesson_records_lesson_code_check CHECK (lesson_code ~ '^L([1-9]|[1-6][0-9]|7[0-4])$'::text OR (lesson_code = ANY (ARRAY['Feriado'::text, 'Teacher Cancelou'::text, 'Não compareceu'::text, 'Conversation'::text, 'Outras atividades'::text, 'Problemas técnicos'::text])));
alter table only public.class_lesson_records add constraint class_lesson_records_student_ref_check CHECK (user_id IS NOT NULL AND invite_id IS NULL OR user_id IS NULL AND invite_id IS NOT NULL);
alter table only public.student_billing_settings add constraint student_billing_settings_monthly_fee_check CHECK (monthly_fee > 0::numeric);
alter table only public.student_billing_settings add constraint student_billing_settings_due_day_check CHECK (due_day >= 1 AND due_day <= 31);
alter table only public.student_billing_settings add constraint student_billing_start_month_first_day CHECK (billing_start_month = date_trunc('month'::text, billing_start_month::timestamp with time zone)::date);
alter table only public.student_billing_settings add constraint student_billing_settings_pkey PRIMARY KEY (student_id);
alter table only public.student_billing_settings add constraint student_billing_settings_student_id_fkey FOREIGN KEY (student_id) REFERENCES profiles(id) ON DELETE CASCADE;
alter table only public.student_billing_settings add constraint student_billing_settings_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES auth.users(id) ON DELETE SET NULL;
alter table only public.monthly_tuition add constraint monthly_tuition_amount_due_check CHECK (amount_due > 0::numeric);
alter table only public.monthly_tuition add constraint monthly_tuition_amount_paid_check CHECK (amount_paid IS NULL OR amount_paid > 0::numeric);
alter table only public.monthly_tuition add constraint monthly_tuition_payment_method_check CHECK (payment_method IS NULL OR (payment_method = ANY (ARRAY['pix'::text, 'cash'::text, 'bank_transfer'::text, 'card'::text, 'other'::text])));
alter table only public.monthly_tuition add constraint monthly_tuition_reference_first_day CHECK (reference_month = date_trunc('month'::text, reference_month::timestamp with time zone)::date);
alter table only public.monthly_tuition add constraint monthly_tuition_payment_consistency CHECK (payment_date IS NULL AND amount_paid IS NULL AND payment_method IS NULL OR payment_date IS NOT NULL AND amount_paid IS NOT NULL AND payment_method IS NOT NULL);
alter table only public.monthly_tuition add constraint monthly_tuition_pkey PRIMARY KEY (id);
alter table only public.monthly_tuition add constraint monthly_tuition_student_id_reference_month_key UNIQUE (student_id, reference_month);
alter table only public.monthly_tuition add constraint monthly_tuition_student_id_fkey FOREIGN KEY (student_id) REFERENCES profiles(id) ON DELETE CASCADE;
alter table only public.monthly_tuition add constraint monthly_tuition_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id) ON DELETE SET NULL;
alter table only public.monthly_tuition add constraint monthly_tuition_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES auth.users(id) ON DELETE SET NULL;
alter table only public.monthly_tuition_events add constraint monthly_tuition_events_action_check CHECK (action = ANY (ARRAY['payment_recorded'::text, 'payment_reversed'::text]));
alter table only public.monthly_tuition_events add constraint monthly_tuition_events_pkey PRIMARY KEY (id);
alter table only public.monthly_tuition_events add constraint monthly_tuition_events_tuition_id_fkey FOREIGN KEY (tuition_id) REFERENCES monthly_tuition(id) ON DELETE CASCADE;
alter table only public.monthly_tuition_events add constraint monthly_tuition_events_actor_id_fkey FOREIGN KEY (actor_id) REFERENCES auth.users(id) ON DELETE SET NULL;
alter table only public.enrollment_email_notifications add constraint enrollment_email_notifications_status_check CHECK (status = ANY (ARRAY['pending'::text, 'sent'::text, 'failed'::text]));
alter table only public.enrollment_email_notifications add constraint enrollment_email_notifications_attempts_check CHECK (attempts >= 0);
alter table only public.enrollment_email_notifications add constraint enrollment_email_notifications_pkey PRIMARY KEY (id);
alter table only public.enrollment_email_notifications add constraint enrollment_email_notifications_student_unique UNIQUE (student_id);
alter table only public.enrollment_email_notifications add constraint enrollment_email_notifications_student_id_fkey FOREIGN KEY (student_id) REFERENCES profiles(id) ON DELETE CASCADE;
alter table only public.makeup_class_slots add constraint makeup_class_slots_capacity_check CHECK (capacity >= 1 AND capacity <= 50);
alter table only public.makeup_class_slots add constraint makeup_class_slots_time_check CHECK (ends_at > starts_at);
alter table only public.makeup_class_slots add constraint makeup_class_slots_pkey PRIMARY KEY (id);
alter table only public.makeup_class_slots add constraint makeup_class_slots_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id) ON DELETE SET NULL;
alter table only public.makeup_class_bookings add constraint makeup_class_bookings_status_check CHECK (status = ANY (ARRAY['confirmed'::text, 'cancelled'::text]));
alter table only public.makeup_class_bookings add constraint makeup_class_bookings_pkey PRIMARY KEY (id);
alter table only public.makeup_class_bookings add constraint makeup_class_bookings_slot_id_fkey FOREIGN KEY (slot_id) REFERENCES makeup_class_slots(id) ON DELETE RESTRICT;
alter table only public.makeup_class_bookings add constraint makeup_class_bookings_student_id_fkey FOREIGN KEY (student_id) REFERENCES auth.users(id) ON DELETE CASCADE;
alter table only public.makeup_class_email_notifications add constraint makeup_class_email_notifications_status_check CHECK (status = ANY (ARRAY['pending'::text, 'sent'::text, 'failed'::text]));
alter table only public.makeup_class_email_notifications add constraint makeup_class_email_notifications_attempts_check CHECK (attempts >= 0);
alter table only public.makeup_class_email_notifications add constraint makeup_class_email_notifications_pkey PRIMARY KEY (id);
alter table only public.makeup_class_email_notifications add constraint makeup_class_email_notifications_booking_id_fkey FOREIGN KEY (booking_id) REFERENCES makeup_class_bookings(id) ON DELETE CASCADE;
alter table only public.makeup_class_email_notifications add constraint makeup_class_email_notifications_notification_type_check CHECK (notification_type = ANY (ARRAY['booking_confirmation'::text, 'cancellation'::text]));
alter table only public.student_access_logs add constraint student_access_logs_pkey PRIMARY KEY (id);
alter table only public.student_access_logs add constraint student_access_logs_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
alter table only public.flashcard_decks add constraint flashcard_decks_title_check CHECK (char_length(btrim(title)) >= 1 AND char_length(btrim(title)) <= 120);
alter table only public.flashcard_decks add constraint flashcard_decks_description_check CHECK (description IS NULL OR char_length(description) <= 500);
alter table only public.flashcard_decks add constraint flashcard_decks_pkey PRIMARY KEY (id);
alter table only public.flashcard_decks add constraint flashcard_decks_owner_id_fkey FOREIGN KEY (owner_id) REFERENCES auth.users(id) ON DELETE CASCADE;
alter table only public.flashcards add constraint flashcards_english_word_check CHECK (char_length(btrim(english_word)) >= 1 AND char_length(btrim(english_word)) <= 180);
alter table only public.flashcards add constraint flashcards_translation_check CHECK (char_length(btrim(translation)) >= 1 AND char_length(btrim(translation)) <= 300);
alter table only public.flashcards add constraint flashcards_position_check CHECK ("position" >= 0);
alter table only public.flashcards add constraint flashcards_pkey PRIMARY KEY (id);
alter table only public.flashcards add constraint flashcards_deck_id_position_key UNIQUE (deck_id, "position");
alter table only public.flashcards add constraint flashcards_deck_id_fkey FOREIGN KEY (deck_id) REFERENCES flashcard_decks(id) ON DELETE CASCADE;
alter table only public.flashcard_practice_days add constraint flashcard_practice_days_pkey PRIMARY KEY (user_id, practice_date);
alter table only public.flashcard_practice_days add constraint flashcard_practice_days_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
alter table only public.daily_exercise_completion add constraint daily_exercise_completion_completed_by_fkey FOREIGN KEY (completed_by) REFERENCES auth.users(id) ON DELETE SET NULL;
alter table only public.exercise_sync_runs add constraint exercise_sync_runs_status_check CHECK (status = ANY (ARRAY['success'::text, 'partial'::text, 'error'::text]));
alter table only public.exercise_sync_runs add constraint exercise_sync_runs_spreadsheets_processed_check CHECK (spreadsheets_processed >= 0);
alter table only public.exercise_sync_runs add constraint exercise_sync_runs_activities_processed_check CHECK (activities_processed >= 0);
alter table only public.exercise_sync_runs add constraint exercise_sync_runs_unique_students_synced_check CHECK (unique_students_synced >= 0);
alter table only public.exercise_sync_runs add constraint exercise_sync_runs_exact_matches_check CHECK (exact_matches >= 0);
alter table only public.exercise_sync_runs add constraint exercise_sync_runs_similarity_matches_check CHECK (similarity_matches >= 0);
alter table only public.exercise_sync_runs add constraint exercise_sync_runs_unmatched_emails_check CHECK (unmatched_emails >= 0);
alter table only public.exercise_sync_runs add constraint exercise_sync_runs_inserted_records_check CHECK (inserted_records >= 0);
alter table only public.exercise_sync_runs add constraint exercise_sync_runs_updated_records_check CHECK (updated_records >= 0);
alter table only public.exercise_sync_runs add constraint exercise_sync_runs_pkey PRIMARY KEY (id);
alter table only public.weekly_plan_snapshots add constraint weekly_plan_snapshots_week_number_check CHECK (week_number > 0);
alter table only public.weekly_plan_snapshots add constraint weekly_plan_snapshots_roadmap_target_lesson_check CHECK (roadmap_target_lesson >= 1 AND roadmap_target_lesson <= 24);
alter table only public.weekly_plan_snapshots add constraint weekly_plan_snapshots_dates_check CHECK (week_end >= week_start);
alter table only public.weekly_plan_snapshots add constraint weekly_plan_snapshots_pkey PRIMARY KEY (id);
alter table only public.weekly_plan_snapshots add constraint weekly_plan_snapshots_user_week_key UNIQUE (user_id, week_start);
alter table only public.weekly_plan_snapshots add constraint weekly_plan_snapshots_user_id_fkey FOREIGN KEY (user_id) REFERENCES profiles(id) ON DELETE CASCADE;
alter table only public.weekly_student_tasks add constraint weekly_student_tasks_title_check CHECK (char_length(btrim(title)) >= 1 AND char_length(btrim(title)) <= 180);
alter table only public.weekly_student_tasks add constraint weekly_student_tasks_dates_check CHECK (week_end >= week_start);
alter table only public.weekly_student_tasks add constraint weekly_student_tasks_pkey PRIMARY KEY (id);
alter table only public.weekly_student_tasks add constraint weekly_student_tasks_user_id_fkey FOREIGN KEY (user_id) REFERENCES profiles(id) ON DELETE CASCADE;
alter table only public.teacher_classes add constraint teacher_classes_class_weekday_check CHECK (class_weekday IS NULL OR class_weekday >= 1 AND class_weekday <= 7);
alter table only public.profiles add constraint profiles_class_type_check CHECK (class_type IS NULL OR (class_type = ANY (ARRAY['INDIVIDUAL'::text, 'QUARTETO'::text, '8 ALUNOS'::text])));
alter table only public.teacher_classes add constraint teacher_classes_class_type_check CHECK (class_type IS NULL OR (class_type = ANY (ARRAY['quartet'::text, 'individual'::text, 'eight_students'::text])));
alter table only public.exercise_form_sources add constraint exercise_form_sources_status_check CHECK (status = ANY (ARRAY['pending'::text, 'active'::text, 'error'::text, 'disconnect_requested'::text, 'disconnected'::text]));
alter table only public.exercise_form_sources add constraint exercise_form_sources_pkey PRIMARY KEY (id);
alter table only public.exercise_form_sources add constraint exercise_form_sources_exercise_unique UNIQUE (exercise_id);
alter table only public.exercise_form_sources add constraint exercise_form_sources_spreadsheet_unique UNIQUE (spreadsheet_id);
alter table only public.exercise_form_sources add constraint exercise_form_sources_exercise_id_fkey FOREIGN KEY (exercise_id) REFERENCES teacher_exercises(exercise_id) ON DELETE CASCADE;
alter table only public.exercise_form_sources add constraint exercise_form_sources_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id) ON DELETE SET NULL;
alter table only public.monthly_tuition add constraint monthly_tuition_payment_provider_check CHECK (payment_provider IS NULL AND provider_payment_id IS NULL OR payment_provider = 'mercado_pago'::text AND provider_payment_id IS NOT NULL);
alter table only public.tuition_payment_attempts add constraint tuition_payment_attempts_provider_check CHECK (provider = 'mercado_pago'::text);
alter table only public.tuition_payment_attempts add constraint tuition_payment_attempts_amount_check CHECK (amount > 0::numeric);
alter table only public.tuition_payment_attempts add constraint tuition_payment_attempts_payment_method_check CHECK (payment_method IS NULL OR (payment_method = ANY (ARRAY['pix'::text, 'card'::text])));
alter table only public.tuition_payment_attempts add constraint tuition_payment_attempts_status_check CHECK (status = ANY (ARRAY['created'::text, 'pending'::text, 'approved'::text, 'authorized'::text, 'in_process'::text, 'in_mediation'::text, 'rejected'::text, 'cancelled'::text, 'refunded'::text, 'charged_back'::text]));
alter table only public.tuition_payment_attempts add constraint tuition_payment_attempts_pkey PRIMARY KEY (id);
alter table only public.tuition_payment_attempts add constraint tuition_payment_attempts_idempotency_key_key UNIQUE (idempotency_key);
alter table only public.tuition_payment_attempts add constraint tuition_payment_attempts_provider_provider_payment_id_key UNIQUE (provider, provider_payment_id);
alter table only public.tuition_payment_attempts add constraint tuition_payment_attempts_tuition_id_fkey FOREIGN KEY (tuition_id) REFERENCES monthly_tuition(id) ON DELETE CASCADE;
alter table only public.tuition_payment_attempts add constraint tuition_payment_attempts_student_id_fkey FOREIGN KEY (student_id) REFERENCES profiles(id) ON DELETE CASCADE;
alter table only public.pronunciation_assignments add constraint pronunciation_assignments_max_recording_seconds_check CHECK (max_recording_seconds >= 10 AND max_recording_seconds <= 300);
alter table only public.pronunciation_assignments add constraint pronunciation_assignments_pkey PRIMARY KEY (id);
alter table only public.pronunciation_assignments add constraint pronunciation_assignments_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id) ON DELETE SET NULL;
alter table only public.pronunciation_attempts add constraint pronunciation_attempts_status_check CHECK (status = ANY (ARRAY['processing'::text, 'processed'::text, 'error'::text, 'reviewed'::text]));
alter table only public.pronunciation_attempts add constraint pronunciation_attempts_pkey PRIMARY KEY (id);
alter table only public.pronunciation_attempts add constraint pronunciation_attempts_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
alter table only public.pronunciation_attempts add constraint pronunciation_attempts_assignment_id_fkey FOREIGN KEY (assignment_id) REFERENCES pronunciation_assignments(id) ON DELETE SET NULL;
alter table only public.daily_exercise_completion add constraint daily_exercise_completion_source_check CHECK (completion_source = ANY (ARRAY['monitor'::text, 'legacy'::text, 'teacher'::text, 'unknown'::text]));
alter table only public.exercise_sync_events add constraint exercise_sync_events_status_check CHECK (status = ANY (ARRAY['processed'::text, 'unmatched_student'::text, 'ambiguous_email'::text, 'not_enrolled'::text, 'exercise_not_found'::text, 'invalid_payload'::text, 'error'::text]));
alter table only public.exercise_sync_events add constraint exercise_sync_events_record_action_check CHECK (record_action IS NULL OR (record_action = ANY (ARRAY['inserted'::text, 'confirmed_existing'::text, 'updated_earlier_completion'::text])));
alter table only public.exercise_sync_events add constraint exercise_sync_events_pkey PRIMARY KEY (id);
alter table only public.exercise_sync_events add constraint exercise_sync_events_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE SET NULL;
alter table only public.student_google_email_aliases add constraint student_google_email_aliases_google_email_normalized CHECK (google_email = lower(btrim(google_email)));
alter table only public.student_google_email_aliases add constraint student_google_email_aliases_enrollment_email_normalized CHECK (enrollment_email = lower(btrim(enrollment_email)));
alter table only public.student_google_email_aliases add constraint student_google_email_aliases_pkey PRIMARY KEY (google_email);
alter table only public.student_google_account_links add constraint student_google_account_links_link_mode_check CHECK (link_mode = ANY (ARRAY['automatic'::text, 'alias'::text]));
alter table only public.student_google_account_links add constraint student_google_account_links_pkey PRIMARY KEY (google_user_id);
alter table only public.student_google_account_links add constraint student_google_account_links_legacy_user_id_key UNIQUE (legacy_user_id);
alter table only public.profiles add constraint profiles_date_of_birth_minimum_check CHECK (date_of_birth IS NULL OR date_of_birth >= '1900-01-01'::date);
alter table only public.api_rate_limit_buckets add constraint api_rate_limit_buckets_request_count_check CHECK (request_count >= 0);
alter table only public.api_rate_limit_buckets add constraint api_rate_limit_buckets_pkey PRIMARY KEY (bucket_key, window_start);
alter table only public.flashcard_srs add constraint flashcard_srs_ease_factor_check CHECK (ease_factor >= 1.30 AND ease_factor <= 3.50);
alter table only public.flashcard_srs add constraint flashcard_srs_interval_days_check CHECK (interval_days >= 0);
alter table only public.flashcard_srs add constraint flashcard_srs_repetitions_check CHECK (repetitions >= 0);
alter table only public.flashcard_srs add constraint flashcard_srs_lapses_check CHECK (lapses >= 0);
alter table only public.flashcard_srs add constraint flashcard_srs_last_grade_check CHECK (last_grade IS NULL OR (last_grade = ANY (ARRAY['again'::text, 'hard'::text, 'good'::text, 'easy'::text])));
alter table only public.flashcard_srs add constraint flashcard_srs_pkey PRIMARY KEY (user_id, card_id);
alter table only public.flashcard_srs add constraint flashcard_srs_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
alter table only public.flashcard_srs add constraint flashcard_srs_card_id_fkey FOREIGN KEY (card_id) REFERENCES flashcards(id) ON DELETE CASCADE;
alter table only public.flashcard_review_history add constraint flashcard_review_history_grade_check CHECK (grade = ANY (ARRAY['again'::text, 'hard'::text, 'good'::text, 'easy'::text]));
alter table only public.flashcard_review_history add constraint flashcard_review_history_interval_days_after_check CHECK (interval_days_after >= 0);
alter table only public.flashcard_review_history add constraint flashcard_review_history_ease_factor_after_check CHECK (ease_factor_after >= 1.30 AND ease_factor_after <= 3.50);
alter table only public.flashcard_review_history add constraint flashcard_review_history_repetitions_after_check CHECK (repetitions_after >= 0);
alter table only public.flashcard_review_history add constraint flashcard_review_history_pkey PRIMARY KEY (id);
alter table only public.flashcard_review_history add constraint flashcard_review_history_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
alter table only public.flashcard_review_history add constraint flashcard_review_history_card_id_fkey FOREIGN KEY (card_id) REFERENCES flashcards(id) ON DELETE CASCADE;
alter table only public.csp_violation_reports add constraint csp_violation_reports_pkey PRIMARY KEY (id);
alter table only public.app_error_events add constraint app_error_events_event_type_check CHECK (event_type = ANY (ARRAY['javascript'::text, 'unhandled_promise'::text, 'resource'::text, 'api'::text, 'auth'::text, 'payment'::text, 'not_found'::text, 'client_exception'::text]));
alter table only public.app_error_events add constraint app_error_events_severity_check CHECK (severity = ANY (ARRAY['warning'::text, 'error'::text, 'critical'::text]));
alter table only public.app_error_events add constraint app_error_events_message_check CHECK (char_length(message) >= 1 AND char_length(message) <= 2000);
alter table only public.app_error_events add constraint app_error_events_http_status_check CHECK (http_status IS NULL OR http_status >= 100 AND http_status <= 599);
alter table only public.app_error_events add constraint app_error_events_pkey PRIMARY KEY (id);


-- Indexes
CREATE UNIQUE INDEX profiles_enrollment_code_unique ON public.profiles USING btree (enrollment_code) WHERE (enrollment_code IS NOT NULL);
CREATE INDEX profiles_cpf_idx ON public.profiles USING btree (cpf);
CREATE INDEX profiles_whatsapp_idx ON public.profiles USING btree (whatsapp);
CREATE INDEX profiles_pix_key_idx ON public.profiles USING btree (pix_key);
CREATE INDEX profiles_availability_gin_idx ON public.profiles USING gin (availability);
CREATE INDEX student_frequency_user_id_idx ON public.student_frequency USING btree (user_id);
CREATE INDEX student_frequency_class_date_idx ON public.student_frequency USING btree (class_date DESC);
CREATE INDEX daily_exercise_completion_user_id_idx ON public.daily_exercise_completion USING btree (user_id);
CREATE INDEX daily_exercise_completion_exercise_id_idx ON public.daily_exercise_completion USING btree (exercise_id);
CREATE INDEX class_students_class_number_idx ON public.class_students USING btree (class_number);
CREATE INDEX class_students_user_id_idx ON public.class_students USING btree (user_id);
CREATE INDEX study_roadmap_completion_user_id_idx ON public.study_roadmap_completion USING btree (user_id);
CREATE INDEX study_roadmap_completion_lesson_id_idx ON public.study_roadmap_completion USING btree (lesson_id);
CREATE INDEX teacher_exercises_created_at_idx ON public.teacher_exercises USING btree (created_at DESC);
CREATE INDEX teacher_exercises_scheduled_publish_at_idx ON public.teacher_exercises USING btree (scheduled_publish_at DESC);
CREATE INDEX teacher_classes_class_number_idx ON public.teacher_classes USING btree (class_number);
CREATE UNIQUE INDEX class_students_one_class_per_user_idx ON public.class_students USING btree (user_id);
CREATE INDEX class_lesson_records_class_number_idx ON public.class_lesson_records USING btree (class_number);
CREATE INDEX class_lesson_records_user_id_idx ON public.class_lesson_records USING btree (user_id);
CREATE INDEX class_lesson_records_class_date_idx ON public.class_lesson_records USING btree (class_date DESC);
CREATE INDEX grammar_lessons_created_at_idx ON public.grammar_lessons USING btree (created_at DESC);
CREATE INDEX grammar_lesson_completion_user_id_idx ON public.grammar_lesson_completion USING btree (user_id);
CREATE INDEX grammar_lesson_completion_lesson_id_idx ON public.grammar_lesson_completion USING btree (lesson_id);
CREATE INDEX student_enrollment_invites_code_idx ON public.student_enrollment_invites USING btree (invite_code);
CREATE INDEX student_enrollment_invites_status_idx ON public.student_enrollment_invites USING btree (status);
CREATE UNIQUE INDEX class_students_class_invite_unique_idx ON public.class_students USING btree (class_number, invite_id) WHERE (invite_id IS NOT NULL);
CREATE INDEX class_students_invite_id_idx ON public.class_students USING btree (invite_id);
CREATE INDEX student_frequency_invite_id_idx ON public.student_frequency USING btree (invite_id);
CREATE UNIQUE INDEX student_tags_user_tag_unique_idx ON public.student_tags USING btree (user_id, tag_name) WHERE (user_id IS NOT NULL);
CREATE UNIQUE INDEX student_tags_invite_tag_unique_idx ON public.student_tags USING btree (invite_id, tag_name) WHERE (invite_id IS NOT NULL);
CREATE INDEX student_tags_tag_name_idx ON public.student_tags USING btree (tag_name);
CREATE INDEX class_lesson_records_invite_id_idx ON public.class_lesson_records USING btree (invite_id);
CREATE INDEX teacher_classes_display_order_idx ON public.teacher_classes USING btree (display_order, class_number);
CREATE UNIQUE INDEX teacher_admins_user_id_unique_idx ON public.teacher_admins USING btree (user_id) WHERE (user_id IS NOT NULL);
CREATE INDEX monthly_tuition_reference_month_idx ON public.monthly_tuition USING btree (reference_month);
CREATE INDEX monthly_tuition_due_date_idx ON public.monthly_tuition USING btree (due_date);
CREATE INDEX monthly_tuition_student_id_idx ON public.monthly_tuition USING btree (student_id);
CREATE INDEX monthly_tuition_events_tuition_id_idx ON public.monthly_tuition_events USING btree (tuition_id, created_at DESC);
CREATE INDEX enrollment_email_notifications_status_idx ON public.enrollment_email_notifications USING btree (status, created_at);
CREATE UNIQUE INDEX makeup_class_bookings_confirmed_unique ON public.makeup_class_bookings USING btree (slot_id, student_id) WHERE (status = 'confirmed'::text);
CREATE INDEX makeup_class_slots_starts_at_idx ON public.makeup_class_slots USING btree (starts_at, is_active);
CREATE INDEX makeup_class_bookings_slot_idx ON public.makeup_class_bookings USING btree (slot_id, status);
CREATE INDEX makeup_class_bookings_student_idx ON public.makeup_class_bookings USING btree (student_id, booked_at DESC);
CREATE INDEX makeup_class_email_status_idx ON public.makeup_class_email_notifications USING btree (status, created_at);
CREATE INDEX makeup_class_slots_class_starts_at_idx ON public.makeup_class_slots USING btree (class_number, starts_at, is_active);
CREATE UNIQUE INDEX makeup_class_email_booking_type_unique ON public.makeup_class_email_notifications USING btree (booking_id, notification_type);
CREATE INDEX student_access_logs_user_accessed_idx ON public.student_access_logs USING btree (user_id, accessed_at DESC);
CREATE INDEX student_access_logs_accessed_idx ON public.student_access_logs USING btree (accessed_at DESC);
CREATE INDEX student_access_logs_page_idx ON public.student_access_logs USING btree (page_path);
CREATE INDEX flashcard_decks_owner_id_idx ON public.flashcard_decks USING btree (owner_id);
CREATE INDEX flashcards_deck_id_position_idx ON public.flashcards USING btree (deck_id, "position");
CREATE INDEX flashcard_practice_days_date_idx ON public.flashcard_practice_days USING btree (practice_date DESC);
CREATE INDEX daily_exercise_completion_weekly_status_idx ON public.daily_exercise_completion USING btree (user_id, completed_at) WHERE (completed = true);
CREATE INDEX daily_exercise_completion_source_idx ON public.daily_exercise_completion USING btree (completion_source);
CREATE INDEX exercise_sync_runs_report_date_idx ON public.exercise_sync_runs USING btree (report_date DESC, started_at DESC);
CREATE INDEX profiles_enrolled_archived_idx ON public.profiles USING btree (enrolled, archived);
CREATE INDEX weekly_plan_snapshots_user_week_idx ON public.weekly_plan_snapshots USING btree (user_id, week_start DESC);
CREATE INDEX weekly_student_tasks_user_week_idx ON public.weekly_student_tasks USING btree (user_id, week_start DESC);
CREATE UNIQUE INDEX class_students_one_class_per_invite_idx ON public.class_students USING btree (invite_id) WHERE (invite_id IS NOT NULL);
CREATE UNIQUE INDEX monthly_tuition_provider_payment_id_uidx ON public.monthly_tuition USING btree (provider_payment_id) WHERE (provider_payment_id IS NOT NULL);
CREATE INDEX tuition_payment_attempts_tuition_idx ON public.tuition_payment_attempts USING btree (tuition_id, created_at DESC);
CREATE INDEX tuition_payment_attempts_student_idx ON public.tuition_payment_attempts USING btree (student_id, created_at DESC);
CREATE INDEX tuition_payment_attempts_pending_idx ON public.tuition_payment_attempts USING btree (status, updated_at DESC) WHERE (status = ANY (ARRAY['created'::text, 'pending'::text, 'authorized'::text, 'in_process'::text, 'in_mediation'::text]));
CREATE INDEX pronunciation_attempts_user_created_idx ON public.pronunciation_attempts USING btree (user_id, created_at DESC);
CREATE INDEX pronunciation_attempts_assignment_idx ON public.pronunciation_attempts USING btree (assignment_id, created_at DESC);
CREATE INDEX pronunciation_assignments_active_idx ON public.pronunciation_assignments USING btree (is_active, created_at DESC);
CREATE INDEX exercise_sync_events_received_at_idx ON public.exercise_sync_events USING btree (received_at DESC);
CREATE INDEX exercise_sync_events_user_id_idx ON public.exercise_sync_events USING btree (user_id, received_at DESC);
CREATE INDEX exercise_sync_events_exercise_id_idx ON public.exercise_sync_events USING btree (exercise_id, received_at DESC);
CREATE INDEX exercise_sync_events_status_idx ON public.exercise_sync_events USING btree (status, received_at DESC);
CREATE UNIQUE INDEX class_lesson_records_class_user_date_lesson_unique_idx ON public.class_lesson_records USING btree (class_number, user_id, class_date, lesson_code) WHERE (user_id IS NOT NULL);
CREATE UNIQUE INDEX class_lesson_records_class_invite_date_lesson_unique_idx ON public.class_lesson_records USING btree (class_number, invite_id, class_date, lesson_code) WHERE (invite_id IS NOT NULL);
CREATE UNIQUE INDEX student_google_email_aliases_enrollment_email_uidx ON public.student_google_email_aliases USING btree (enrollment_email) WHERE (active = true);
CREATE INDEX flashcard_srs_user_due_idx ON public.flashcard_srs USING btree (user_id, due_date);
CREATE INDEX flashcard_srs_card_idx ON public.flashcard_srs USING btree (card_id);
CREATE INDEX flashcard_review_history_user_reviewed_idx ON public.flashcard_review_history USING btree (user_id, reviewed_at DESC);
CREATE INDEX flashcard_review_history_card_reviewed_idx ON public.flashcard_review_history USING btree (card_id, reviewed_at DESC);
CREATE INDEX csp_violation_reports_created_at_idx ON public.csp_violation_reports USING btree (created_at DESC);
CREATE INDEX activity_results_user_id_idx ON public.activity_results USING btree (user_id);
CREATE INDEX daily_exercise_completion_completed_by_idx ON public.daily_exercise_completion USING btree (completed_by);
CREATE INDEX exercise_form_sources_created_by_idx ON public.exercise_form_sources USING btree (created_by);
CREATE INDEX grammar_lessons_created_by_idx ON public.grammar_lessons USING btree (created_by);
CREATE INDEX makeup_class_slots_created_by_idx ON public.makeup_class_slots USING btree (created_by);
CREATE INDEX monthly_tuition_created_by_idx ON public.monthly_tuition USING btree (created_by);
CREATE INDEX monthly_tuition_updated_by_idx ON public.monthly_tuition USING btree (updated_by);
CREATE INDEX monthly_tuition_events_actor_id_idx ON public.monthly_tuition_events USING btree (actor_id);
CREATE INDEX pronunciation_assignments_created_by_idx ON public.pronunciation_assignments USING btree (created_by);
CREATE INDEX student_billing_settings_updated_by_idx ON public.student_billing_settings USING btree (updated_by);
CREATE INDEX student_enrollment_invites_created_by_idx ON public.student_enrollment_invites USING btree (created_by);
CREATE INDEX student_enrollment_invites_user_id_idx ON public.student_enrollment_invites USING btree (user_id);
CREATE INDEX student_enrollments_user_id_idx ON public.student_enrollments USING btree (user_id);
CREATE INDEX student_tags_created_by_idx ON public.student_tags USING btree (created_by);
CREATE INDEX teacher_exercises_created_by_idx ON public.teacher_exercises USING btree (created_by);
CREATE UNIQUE INDEX makeup_class_slots_active_class_start_uidx ON public.makeup_class_slots USING btree (class_number, starts_at) WHERE ((is_active = true) AND (class_number IS NOT NULL));
CREATE UNIQUE INDEX profiles_email_normalized_uidx ON public.profiles USING btree (lower(btrim(email))) WHERE (NULLIF(btrim(email), ''::text) IS NOT NULL);
CREATE INDEX app_error_events_created_at_idx ON public.app_error_events USING btree (created_at DESC);
CREATE INDEX app_error_events_type_created_idx ON public.app_error_events USING btree (event_type, created_at DESC);
CREATE INDEX app_error_events_unresolved_idx ON public.app_error_events USING btree (created_at DESC) WHERE (resolved_at IS NULL);
CREATE INDEX app_error_events_fingerprint_idx ON public.app_error_events USING btree (fingerprint, created_at DESC) WHERE (fingerprint IS NOT NULL);


-- Functions
CREATE OR REPLACE FUNCTION public.rls_auto_enable()
 RETURNS event_trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog'
AS $function$
DECLARE
  cmd record;
BEGIN
  FOR cmd IN
    SELECT *
    FROM pg_event_trigger_ddl_commands()
    WHERE command_tag IN ('CREATE TABLE', 'CREATE TABLE AS', 'SELECT INTO')
      AND object_type IN ('table','partitioned table')
  LOOP
     IF cmd.schema_name IS NOT NULL AND cmd.schema_name IN ('public') AND cmd.schema_name NOT IN ('pg_catalog','information_schema') AND cmd.schema_name NOT LIKE 'pg_toast%' AND cmd.schema_name NOT LIKE 'pg_temp%' THEN
      BEGIN
        EXECUTE format('alter table if exists %s enable row level security', cmd.object_identity);
        RAISE LOG 'rls_auto_enable: enabled RLS on %', cmd.object_identity;
      EXCEPTION
        WHEN OTHERS THEN
          RAISE LOG 'rls_auto_enable: failed to enable RLS on %', cmd.object_identity;
      END;
     ELSE
        RAISE LOG 'rls_auto_enable: skip % (either system schema or not in enforced list: %.)', cmd.object_identity, cmd.schema_name;
     END IF;
  END LOOP;
END;
$function$;


CREATE OR REPLACE FUNCTION public.set_updated_at()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
begin
  new.updated_at = now();
  return new;
end;
$function$;


CREATE OR REPLACE FUNCTION public.delete_teacher_student(target_user_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth', 'storage'
AS $function$
declare
  target_email text;
  profile_count_before integer := 0;
  deleted_auth_count integer := 0;
  deleted_profile_count integer := 0;
  deleted_invite_count integer := 0;
  deleted_backup_count integer := 0;
begin
  if not coalesce(public.is_teacher_admin(), false) then
    raise exception 'Acesso negado: usuário não cadastrado como professor.' using errcode = '42501';
  end if;

  select u.email into target_email
  from auth.users u
  where u.id = target_user_id;

  if exists (
    select 1
    from public.teacher_admins ta
    where ta.user_id = target_user_id
       or (target_email is not null and lower(ta.email) = lower(target_email))
  ) then
    raise exception 'Não é permitido excluir uma conta de professor.';
  end if;

  select count(*) into profile_count_before
  from public.profiles p
  where p.id = target_user_id;

  if target_email is null and profile_count_before = 0 then
    raise exception 'Aluno não encontrado.';
  end if;

  if exists (
    select 1
    from storage.objects o
    where o.owner = target_user_id
  ) then
    raise exception 'Este aluno possui arquivos no Storage. Remova os arquivos antes de excluir a conta permanentemente.';
  end if;

  delete from public.student_enrollment_invites
  where user_id = target_user_id;
  get diagnostics deleted_invite_count = row_count;

  if to_regclass('public.backup_student_private_data_20260501') is not null then
    execute 'delete from public.backup_student_private_data_20260501 where user_id = $1'
      using target_user_id;
    get diagnostics deleted_backup_count = row_count;
  end if;

  delete from auth.users
  where id = target_user_id;
  get diagnostics deleted_auth_count = row_count;

  if deleted_auth_count = 0 then
    delete from public.profiles
    where id = target_user_id;
    get diagnostics deleted_profile_count = row_count;
  else
    deleted_profile_count := profile_count_before;
  end if;

  return jsonb_build_object(
    'ok', true,
    'target_user_id', target_user_id,
    'deleted_auth_count', deleted_auth_count,
    'deleted_profile_count', deleted_profile_count,
    'deleted_invite_count', deleted_invite_count,
    'deleted_backup_count', deleted_backup_count
  );
end;
$function$;


CREATE OR REPLACE FUNCTION public.get_teacher_student_frequency(target_user_id uuid)
 RETURNS TABLE(id text, user_id text, class_date date, attendance_status text, class_notes text, created_at timestamp with time zone, updated_at timestamp with time zone)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not public.is_teacher_admin() then
    raise exception 'Acesso negado: usuário não cadastrado como professor.';
  end if;

  return query
  select
    sf.id::text,
    sf.user_id::text,
    sf.class_date,
    sf.attendance_status,
    coalesce(sf.class_notes, '')::text,
    sf.created_at,
    sf.updated_at
  from public.student_frequency sf
  where sf.user_id = target_user_id
  order by sf.class_date desc, sf.created_at desc;
end;
$function$;


CREATE OR REPLACE FUNCTION public.save_teacher_student_frequency(target_user_id uuid, target_class_date date, target_attendance_status text, target_class_notes text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  inserted_id uuid;
begin
  if not public.is_teacher_admin() then
    raise exception 'Acesso negado: usuário não cadastrado como professor.';
  end if;

  if target_attendance_status not in ('Compareceu', 'Faltou') then
    raise exception 'Situação inválida.';
  end if;

  insert into public.student_frequency (user_id, class_date, attendance_status, class_notes)
  values (target_user_id, target_class_date, target_attendance_status, target_class_notes)
  returning id into inserted_id;

  return jsonb_build_object('ok', true, 'id', inserted_id);
end;
$function$;


CREATE OR REPLACE FUNCTION public.is_teacher_admin()
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select exists (
    select 1
    from public.teacher_admins ta
    where ta.user_id = auth.uid()
       or (
         ta.user_id is null
         and lower(ta.email) = lower(auth.jwt() ->> 'email')
       )
  );
$function$;


CREATE OR REPLACE FUNCTION public.update_teacher_student_frequency(target_frequency_id uuid, target_class_date date, target_attendance_status text, target_class_notes text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not public.is_teacher_admin() then
    raise exception 'Acesso negado: usuário não cadastrado como professor.';
  end if;

  if target_attendance_status not in ('Compareceu', 'Faltou') then
    raise exception 'Situação inválida.';
  end if;

  update public.student_frequency
  set
    class_date = target_class_date,
    attendance_status = target_attendance_status,
    class_notes = target_class_notes
  where id = target_frequency_id;

  if not found then
    raise exception 'Registro de frequência não encontrado.';
  end if;

  return jsonb_build_object('ok', true, 'id', target_frequency_id);
end;
$function$;


CREATE OR REPLACE FUNCTION public.delete_teacher_student_frequency(target_frequency_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not public.is_teacher_admin() then
    raise exception 'Acesso negado: usuário não cadastrado como professor.';
  end if;

  delete from public.student_frequency
  where id = target_frequency_id;

  if not found then
    raise exception 'Registro de frequência não encontrado.';
  end if;

  return jsonb_build_object('ok', true, 'id', target_frequency_id);
end;
$function$;


CREATE OR REPLACE FUNCTION public.set_daily_exercise_completion_updated_at()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
                                            begin
                                              new.updated_at = now();
                                                return new;
                                                end;
                                                $function$


CREATE OR REPLACE FUNCTION public.get_teacher_daily_exercise_completion()
 RETURNS TABLE(id text, user_id text, student_name text, student_email text, exercise_id text, exercise_title text, exercise_url text, completed boolean, completed_at timestamp with time zone, updated_at timestamp with time zone)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth'
AS $function$
                                                                                begin
                                                                                  if not public.is_teacher_admin() then
                                                                                      raise exception 'Acesso negado: usuário não cadastrado como professor.';
                                                                                        end if;

                                                                                          return query
                                                                                            select
                                                                                                dec.id::text,
                                                                                                    dec.user_id::text,
                                                                                                        coalesce(p.name, u.raw_user_meta_data ->> 'name', u.email, 'Aluno sem nome')::text as student_name,
                                                                                                            coalesce(p.email, u.email, '')::text as student_email,
                                                                                                                dec.exercise_id,
                                                                                                                    dec.exercise_title,
                                                                                                                        coalesce(dec.exercise_url, '')::text as exercise_url,
                                                                                                                            dec.completed,
                                                                                                                                dec.completed_at,
                                                                                                                                    dec.updated_at
                                                                                                                                      from public.daily_exercise_completion dec
                                                                                                                                        left join public.profiles p on p.id = dec.user_id
                                                                                                                                          left join auth.users u on u.id = dec.user_id
                                                                                                                                            where dec.completed = true
                                                                                                                                                and not exists (
                                                                                                                                                      select 1 from public.teacher_admins ta
                                                                                                                                                            where lower(ta.email) = lower(coalesce(p.email, u.email, ''))
                                                                                                                                                                )
                                                                                                                                                                    and (
                                                                                                                                                                          coalesce(p.enrolled, false) = true
                                                                                                                                                                                or coalesce(p.enrollment_code, '') <> ''
                                                                                                                                                                                      or coalesce((u.raw_user_meta_data ->> 'enrolled')::boolean, false) = true
                                                                                                                                                                                            or coalesce(u.raw_user_meta_data ->> 'enrollment_code', '') <> ''
                                                                                                                                                                                                )
                                                                                                                                                                                                  order by student_name asc, dec.completed_at desc nulls last, dec.updated_at desc;
                                                                                                                                                                                                  end;
                                                                                                                                                                                                  $function$


CREATE OR REPLACE FUNCTION public.set_study_roadmap_completion_updated_at()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
begin
  new.updated_at = now();
  return new;
end;
$function$;


CREATE OR REPLACE FUNCTION public.set_class_resources_updated_at()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
begin
  new.updated_at = now();
  return new;
end;
$function$;


CREATE OR REPLACE FUNCTION public.set_teacher_exercises_updated_at()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
begin
  new.updated_at = now();
  return new;
end;
$function$;


CREATE OR REPLACE FUNCTION public.update_teacher_student_profile(target_user_id uuid, target_name text, target_email text, target_cpf text, target_whatsapp text, target_pix_key text, target_enrollment_code text, target_availability jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth'
AS $function$
declare
  requester_email text;
begin
  requester_email := auth.jwt() ->> 'email';

  if requester_email is null or not exists (
    select 1 from public.teacher_admins ta
    where lower(ta.email) = lower(requester_email)
  ) then
    raise exception 'Acesso negado: usuário não cadastrado como professor.';
  end if;

  if exists (
    select 1 from public.teacher_admins ta
    join auth.users u on lower(u.email) = lower(ta.email)
    where u.id = target_user_id
  ) then
    raise exception 'Não é permitido editar uma conta de professor por esta tela.';
  end if;

  if coalesce(trim(target_name), '') = '' then
    raise exception 'Informe o nome do aluno.';
  end if;

  if coalesce(trim(target_email), '') = '' then
    raise exception 'Informe o e-mail do aluno.';
  end if;

  if length(regexp_replace(coalesce(target_cpf, ''), '\D', '', 'g')) <> 11 then
    raise exception 'CPF inválido.';
  end if;

  if length(regexp_replace(coalesce(target_whatsapp, ''), '\D', '', 'g')) < 10 then
    raise exception 'WhatsApp inválido.';
  end if;

  insert into public.profiles (
    id,
    name,
    email,
    cpf,
    whatsapp,
    pix_key,
    enrollment_code,
    enrolled,
    availability,
    availability_seg_09,
    availability_seg_10,
    availability_seg_12,
    availability_seg_13,
    availability_seg_15,
    availability_seg_17,
    availability_seg_18,
    availability_seg_20,
    availability_seg_21,
    availability_ter_09,
    availability_ter_10,
    availability_ter_12,
    availability_ter_13,
    availability_ter_15,
    availability_ter_17,
    availability_ter_18,
    availability_ter_20,
    availability_ter_21,
    availability_qua_09,
    availability_qua_10,
    availability_qua_12,
    availability_qua_13,
    availability_qua_15,
    availability_qua_17,
    availability_qua_18,
    availability_qua_20,
    availability_qua_21,
    availability_qui_09,
    availability_qui_10,
    availability_qui_12,
    availability_qui_13,
    availability_qui_15,
    availability_qui_17,
    availability_qui_18,
    availability_qui_20,
    availability_qui_21,
    availability_sex_09,
    availability_sex_10,
    availability_sex_12,
    availability_sex_13,
    availability_sex_15,
    availability_sex_17,
    availability_sex_18,
    availability_sex_20,
    availability_sex_21
  )
  values (
    target_user_id,
    trim(target_name),
    trim(target_email),
    regexp_replace(coalesce(target_cpf, ''), '\D', '', 'g'),
    regexp_replace(coalesce(target_whatsapp, ''), '\D', '', 'g'),
    trim(coalesce(target_pix_key, '')),
    trim(coalesce(target_enrollment_code, '')),
    true,
    coalesce(target_availability, '{}'::jsonb),
    coalesce((target_availability -> 'seg') ? '09', false),
    coalesce((target_availability -> 'seg') ? '10', false),
    coalesce((target_availability -> 'seg') ? '12', false),
    coalesce((target_availability -> 'seg') ? '13', false),
    coalesce((target_availability -> 'seg') ? '15', false),
    coalesce((target_availability -> 'seg') ? '17', false),
    coalesce((target_availability -> 'seg') ? '18', false),
    coalesce((target_availability -> 'seg') ? '20', false),
    coalesce((target_availability -> 'seg') ? '21', false),
    coalesce((target_availability -> 'ter') ? '09', false),
    coalesce((target_availability -> 'ter') ? '10', false),
    coalesce((target_availability -> 'ter') ? '12', false),
    coalesce((target_availability -> 'ter') ? '13', false),
    coalesce((target_availability -> 'ter') ? '15', false),
    coalesce((target_availability -> 'ter') ? '17', false),
    coalesce((target_availability -> 'ter') ? '18', false),
    coalesce((target_availability -> 'ter') ? '20', false),
    coalesce((target_availability -> 'ter') ? '21', false),
    coalesce((target_availability -> 'qua') ? '09', false),
    coalesce((target_availability -> 'qua') ? '10', false),
    coalesce((target_availability -> 'qua') ? '12', false),
    coalesce((target_availability -> 'qua') ? '13', false),
    coalesce((target_availability -> 'qua') ? '15', false),
    coalesce((target_availability -> 'qua') ? '17', false),
    coalesce((target_availability -> 'qua') ? '18', false),
    coalesce((target_availability -> 'qua') ? '20', false),
    coalesce((target_availability -> 'qua') ? '21', false),
    coalesce((target_availability -> 'qui') ? '09', false),
    coalesce((target_availability -> 'qui') ? '10', false),
    coalesce((target_availability -> 'qui') ? '12', false),
    coalesce((target_availability -> 'qui') ? '13', false),
    coalesce((target_availability -> 'qui') ? '15', false),
    coalesce((target_availability -> 'qui') ? '17', false),
    coalesce((target_availability -> 'qui') ? '18', false),
    coalesce((target_availability -> 'qui') ? '20', false),
    coalesce((target_availability -> 'qui') ? '21', false),
    coalesce((target_availability -> 'sex') ? '09', false),
    coalesce((target_availability -> 'sex') ? '10', false),
    coalesce((target_availability -> 'sex') ? '12', false),
    coalesce((target_availability -> 'sex') ? '13', false),
    coalesce((target_availability -> 'sex') ? '15', false),
    coalesce((target_availability -> 'sex') ? '17', false),
    coalesce((target_availability -> 'sex') ? '18', false),
    coalesce((target_availability -> 'sex') ? '20', false),
    coalesce((target_availability -> 'sex') ? '21', false)
  )
  on conflict (id) do update
  set
    name = excluded.name,
    email = excluded.email,
    cpf = excluded.cpf,
    whatsapp = excluded.whatsapp,
    pix_key = excluded.pix_key,
    enrollment_code = excluded.enrollment_code,
    enrolled = true,
    availability = excluded.availability,
    availability_seg_09 = excluded.availability_seg_09,
    availability_seg_10 = excluded.availability_seg_10,
    availability_seg_12 = excluded.availability_seg_12,
    availability_seg_13 = excluded.availability_seg_13,
    availability_seg_15 = excluded.availability_seg_15,
    availability_seg_17 = excluded.availability_seg_17,
    availability_seg_18 = excluded.availability_seg_18,
    availability_seg_20 = excluded.availability_seg_20,
    availability_seg_21 = excluded.availability_seg_21,
    availability_ter_09 = excluded.availability_ter_09,
    availability_ter_10 = excluded.availability_ter_10,
    availability_ter_12 = excluded.availability_ter_12,
    availability_ter_13 = excluded.availability_ter_13,
    availability_ter_15 = excluded.availability_ter_15,
    availability_ter_17 = excluded.availability_ter_17,
    availability_ter_18 = excluded.availability_ter_18,
    availability_ter_20 = excluded.availability_ter_20,
    availability_ter_21 = excluded.availability_ter_21,
    availability_qua_09 = excluded.availability_qua_09,
    availability_qua_10 = excluded.availability_qua_10,
    availability_qua_12 = excluded.availability_qua_12,
    availability_qua_13 = excluded.availability_qua_13,
    availability_qua_15 = excluded.availability_qua_15,
    availability_qua_17 = excluded.availability_qua_17,
    availability_qua_18 = excluded.availability_qua_18,
    availability_qua_20 = excluded.availability_qua_20,
    availability_qua_21 = excluded.availability_qua_21,
    availability_qui_09 = excluded.availability_qui_09,
    availability_qui_10 = excluded.availability_qui_10,
    availability_qui_12 = excluded.availability_qui_12,
    availability_qui_13 = excluded.availability_qui_13,
    availability_qui_15 = excluded.availability_qui_15,
    availability_qui_17 = excluded.availability_qui_17,
    availability_qui_18 = excluded.availability_qui_18,
    availability_qui_20 = excluded.availability_qui_20,
    availability_qui_21 = excluded.availability_qui_21,
    availability_sex_09 = excluded.availability_sex_09,
    availability_sex_10 = excluded.availability_sex_10,
    availability_sex_12 = excluded.availability_sex_12,
    availability_sex_13 = excluded.availability_sex_13,
    availability_sex_15 = excluded.availability_sex_15,
    availability_sex_17 = excluded.availability_sex_17,
    availability_sex_18 = excluded.availability_sex_18,
    availability_sex_20 = excluded.availability_sex_20,
    availability_sex_21 = excluded.availability_sex_21;

  update auth.users
  set
    email = trim(target_email),
    raw_user_meta_data = coalesce(raw_user_meta_data, '{}'::jsonb) || jsonb_build_object(
      'name', trim(target_name),
      'cpf', regexp_replace(coalesce(target_cpf, ''), '\D', '', 'g'),
      'whatsapp', regexp_replace(coalesce(target_whatsapp, ''), '\D', '', 'g'),
      'pix_key', trim(coalesce(target_pix_key, '')),
      'enrollment_code', trim(coalesce(target_enrollment_code, '')),
      'enrolled', true,
      'availability', coalesce(target_availability, '{}'::jsonb)
    ),
    updated_at = now()
  where id = target_user_id;

  return jsonb_build_object('ok', true, 'user_id', target_user_id);
end;
$function$;


CREATE OR REPLACE FUNCTION public.save_teacher_class_lesson_record(target_class_number integer, target_user_id uuid, target_class_date date, target_lesson_code text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  return public.save_teacher_class_lesson_record_by_ref(
    target_class_number,
    target_user_id::text,
    'user',
    target_class_date,
    target_lesson_code
  );
end;
$function$;


CREATE OR REPLACE FUNCTION public.get_my_lesson_records()
 RETURNS TABLE(id text, class_number integer, class_name text, class_date date, lesson_code text, created_at timestamp with time zone, updated_at timestamp with time zone)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  return query
  select
    clr.id::text,
    clr.class_number,
    coalesce(tc.class_name, 'Turma ' || clr.class_number)::text as class_name,
    clr.class_date,
    clr.lesson_code,
    clr.created_at,
    clr.updated_at
  from public.class_lesson_records clr
  left join public.teacher_classes tc on tc.class_number = clr.class_number
  where clr.user_id = auth.uid()
  order by clr.class_date desc, clr.created_at desc;
end;
$function$;


CREATE OR REPLACE FUNCTION public.save_teacher_class_resources(target_class_number integer, target_video_lesson_url text, target_lesson_material_url text, target_recorded_lessons_url text, target_whatsapp_group_url text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not public.is_teacher_admin() then
    raise exception 'Acesso negado: usuário não cadastrado como professor.';
  end if;

  perform public.assert_teacher_class_exists(target_class_number);

  insert into public.class_resources (
    class_number,
    video_lesson_url,
    lesson_material_url,
    recorded_lessons_url,
    whatsapp_group_url
  )
  values (
    target_class_number,
    nullif(trim(coalesce(target_video_lesson_url, '')), ''),
    nullif(trim(coalesce(target_lesson_material_url, '')), ''),
    nullif(trim(coalesce(target_recorded_lessons_url, '')), ''),
    nullif(trim(coalesce(target_whatsapp_group_url, '')), '')
  )
  on conflict (class_number) do update
  set
    video_lesson_url = excluded.video_lesson_url,
    lesson_material_url = excluded.lesson_material_url,
    recorded_lessons_url = excluded.recorded_lessons_url,
    whatsapp_group_url = excluded.whatsapp_group_url;

  return jsonb_build_object('ok', true, 'class_number', target_class_number);
end;
$function$;


CREATE OR REPLACE FUNCTION public.set_student_private_data_updated_at()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
begin
  new.updated_at = now();
  return new;
end;
$function$;


CREATE OR REPLACE FUNCTION public.upsert_my_private_student_data(target_cpf text, target_whatsapp text, target_pix_key text, target_consent_lgpd boolean DEFAULT true)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  requester_id uuid;
begin
  requester_id := auth.uid();

  if requester_id is null then
    raise exception 'Usuário não autenticado.';
  end if;

  if length(regexp_replace(coalesce(target_cpf, ''), '\\D', '', 'g')) <> 11 then
    raise exception 'CPF inválido.';
  end if;

  if length(regexp_replace(coalesce(target_whatsapp, ''), '\\D', '', 'g')) < 10 then
    raise exception 'WhatsApp inválido.';
  end if;

  if coalesce(trim(target_pix_key), '') = '' then
    raise exception 'Informe a chave PIX.';
  end if;

  insert into public.student_private_data (
    user_id,
    cpf,
    whatsapp,
    pix_key,
    consent_lgpd,
    consent_lgpd_at
  )
  values (
    requester_id,
    regexp_replace(coalesce(target_cpf, ''), '\\D', '', 'g'),
    regexp_replace(coalesce(target_whatsapp, ''), '\\D', '', 'g'),
    trim(target_pix_key),
    coalesce(target_consent_lgpd, false),
    case when coalesce(target_consent_lgpd, false) then now() else null end
  )
  on conflict (user_id) do update
  set
    cpf = excluded.cpf,
    whatsapp = excluded.whatsapp,
    pix_key = excluded.pix_key,
    consent_lgpd = excluded.consent_lgpd,
    consent_lgpd_at = case
      when excluded.consent_lgpd = true and public.student_private_data.consent_lgpd_at is null then now()
      when excluded.consent_lgpd = true then public.student_private_data.consent_lgpd_at
      else null
    end,
    updated_at = now();

  return jsonb_build_object('ok', true, 'user_id', requester_id);
end;
$function$;


CREATE OR REPLACE FUNCTION public.get_my_private_student_data()
 RETURNS TABLE(cpf text, whatsapp text, pix_key text, consent_lgpd boolean, consent_lgpd_at timestamp with time zone, updated_at timestamp with time zone)
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select
    spd.cpf,
    spd.whatsapp,
    spd.pix_key,
    spd.consent_lgpd,
    spd.consent_lgpd_at,
    spd.updated_at
  from public.student_private_data spd
  where spd.user_id = auth.uid();
$function$;


CREATE OR REPLACE FUNCTION public.get_teacher_private_student_data()
 RETURNS TABLE(user_id text, cpf text, whatsapp text, pix_key text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth'
AS $function$
declare
  requester_email text;
begin
  requester_email := auth.jwt() ->> 'email';

  if requester_email is null or not exists (
    select 1
    from public.teacher_admins ta
    where lower(ta.email) = lower(requester_email)
  ) then
    raise exception 'Acesso negado: usuário não cadastrado como professor.';
  end if;

  return query
  select
    spd.user_id::text as user_id,
    coalesce(spd.cpf, '')::text as cpf,
    coalesce(spd.whatsapp, '')::text as whatsapp,
    coalesce(spd.pix_key, '')::text as pix_key
  from public.student_private_data spd;
end;
$function$;


CREATE OR REPLACE FUNCTION public.assert_teacher_class_exists(target_class_number integer)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not exists (
    select 1 from public.teacher_classes tc
    where tc.class_number = target_class_number
      and tc.is_active = true
  ) then
    raise exception 'Turma não encontrada ou inativa.';
  end if;
end;
$function$;


CREATE OR REPLACE FUNCTION public.get_teacher_classes()
 RETURNS TABLE(id text, class_number integer, class_name text, student_count integer, is_active boolean, created_at timestamp with time zone, updated_at timestamp with time zone)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not public.is_teacher_admin() then
    raise exception 'Acesso negado: usuário não cadastrado como professor.';
  end if;

  return query
  select
    tc.id::text,
    tc.class_number,
    tc.class_name,
    count(cs.id)::integer as student_count,
    tc.is_active,
    tc.created_at,
    tc.updated_at
  from public.teacher_classes tc
  left join public.class_students cs on cs.class_number = tc.class_number
  where tc.is_active = true
  group by tc.id, tc.class_number, tc.class_name, tc.is_active, tc.created_at, tc.updated_at
  order by tc.class_number asc;
end;
$function$;


CREATE OR REPLACE FUNCTION public.create_teacher_class(target_class_name text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  next_number integer;
  next_order integer;
  final_name text;
  inserted_id uuid;
begin
  if not public.is_teacher_admin() then
    raise exception 'Acesso negado: usuário não cadastrado como professor.';
  end if;

  select coalesce(max(class_number), 0) + 1
  into next_number
  from public.teacher_classes;

  select coalesce(max(display_order), 0) + 1
  into next_order
  from public.teacher_classes
  where is_active = true;

  final_name := coalesce(nullif(trim(target_class_name), ''), 'Turma ' || next_number);

  insert into public.teacher_classes (class_number, class_name, display_order, is_active)
  values (next_number, final_name, next_order, true)
  returning id into inserted_id;

  return jsonb_build_object('ok', true, 'id', inserted_id, 'class_number', next_number, 'class_name', final_name);
end;
$function$;


CREATE OR REPLACE FUNCTION public.delete_teacher_class(target_class_number integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  deleted_students integer := 0;
  deleted_resources integer := 0;
begin
  if not public.is_teacher_admin() then
    raise exception 'Acesso negado: usuário não cadastrado como professor.';
  end if;

  if not exists (select 1 from public.teacher_classes where class_number = target_class_number and is_active = true) then
    raise exception 'Turma não encontrada.';
  end if;

  delete from public.class_students where class_number = target_class_number;
  get diagnostics deleted_students = row_count;

  delete from public.class_resources where class_number = target_class_number;
  get diagnostics deleted_resources = row_count;

  update public.teacher_classes
  set is_active = false,
      class_name = class_name || ' (excluída)'
  where class_number = target_class_number;

  return jsonb_build_object(
    'ok', true,
    'class_number', target_class_number,
    'deleted_students', deleted_students,
    'deleted_resources', deleted_resources
  );
end;
$function$;


CREATE OR REPLACE FUNCTION public.save_teacher_class_resources(target_class_number integer, target_video_lesson_url text, target_lesson_material_url text, target_whatsapp_group_url text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  existing_recorded_lessons_url text;
begin
  select cr.recorded_lessons_url
  into existing_recorded_lessons_url
  from public.class_resources cr
  where cr.class_number = target_class_number;

  return public.save_teacher_class_resources(
    target_class_number,
    target_video_lesson_url,
    target_lesson_material_url,
    existing_recorded_lessons_url,
    target_whatsapp_group_url
  );
end;
$function$;


CREATE OR REPLACE FUNCTION public.add_teacher_class_student(target_class_number integer, target_user_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth'
AS $function$
declare
  inserted_id uuid;
begin
  if not public.is_teacher_admin() then
    raise exception 'Acesso negado: usuário não cadastrado como professor.';
  end if;

  perform public.assert_teacher_class_exists(target_class_number);

  if not exists (
    select 1
    from auth.users u
    left join public.profiles p on p.id = u.id
    where u.id = target_user_id
      and not exists (
        select 1 from public.teacher_admins ta
        where lower(ta.email) = lower(u.email)
      )
      and (
        coalesce(p.enrolled, false) = true
        or coalesce(p.enrollment_code, '') <> ''
        or coalesce((u.raw_user_meta_data ->> 'enrolled')::boolean, false) = true
        or coalesce(u.raw_user_meta_data ->> 'enrollment_code', '') <> ''
      )
  ) then
    raise exception 'Aluno matriculado não encontrado.';
  end if;

  insert into public.class_students (class_number, user_id)
  values (target_class_number, target_user_id)
  on conflict (class_number, user_id) do update
  set class_number = excluded.class_number
  returning id into inserted_id;

  return jsonb_build_object('ok', true, 'id', inserted_id);
end;
$function$;


CREATE OR REPLACE FUNCTION public.remove_teacher_class_student(target_class_number integer, target_user_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not public.is_teacher_admin() then
    raise exception 'Acesso negado: usuário não cadastrado como professor.';
  end if;

  perform public.assert_teacher_class_exists(target_class_number);

  delete from public.class_students
  where class_number = target_class_number
    and user_id = target_user_id;

  if not found then
    raise exception 'Aluno não encontrado nesta turma.';
  end if;

  return jsonb_build_object('ok', true);
end;
$function$;


CREATE OR REPLACE FUNCTION public.save_teacher_class_attendance(target_class_number integer, target_class_date date, target_general_notes text, attendance_records jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth'
AS $function$
declare
  item jsonb;
  target_user_id uuid;
  target_status text;
  target_notes text;
  inserted_count integer := 0;
begin
  if not public.is_teacher_admin() then
    raise exception 'Acesso negado: usuário não cadastrado como professor.';
  end if;

  perform public.assert_teacher_class_exists(target_class_number);

  if attendance_records is null or jsonb_array_length(attendance_records) = 0 then
    raise exception 'Nenhum aluno foi selecionado para registrar frequência.';
  end if;

  for item in select * from jsonb_array_elements(attendance_records)
  loop
    target_user_id := (item ->> 'user_id')::uuid;
    target_status := coalesce(item ->> 'attendance_status', 'Compareceu');
    target_notes := coalesce(nullif(item ->> 'class_notes', ''), target_general_notes, '');

    if target_status not in ('Compareceu', 'Faltou') then
      raise exception 'Situação inválida para um dos alunos.';
    end if;

    if not exists (
      select 1 from public.class_students cs
      where cs.class_number = target_class_number
        and cs.user_id = target_user_id
    ) then
      raise exception 'Um dos alunos selecionados não pertence a esta turma.';
    end if;

    insert into public.student_frequency (user_id, class_date, attendance_status, class_notes)
    values (
      target_user_id,
      target_class_date,
      target_status,
      '[Turma ' || target_class_number || '] ' || target_notes
    );

    inserted_count := inserted_count + 1;
  end loop;

  return jsonb_build_object('ok', true, 'inserted_count', inserted_count);
end;
$function$;


CREATE OR REPLACE FUNCTION public.get_enrollment_invite_by_code(target_invite_code text)
 RETURNS TABLE(invite_code text, student_name text, status text, expires_at timestamp with time zone)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  return query
  select
    sei.invite_code,
    sei.student_name,
    sei.status,
    sei.expires_at
  from public.student_enrollment_invites sei
  where upper(sei.invite_code) = upper(trim(target_invite_code))
    and sei.status = 'pending'
    and (sei.expires_at is null or sei.expires_at > now())
  limit 1;
end;
$function$;


CREATE OR REPLACE FUNCTION public.complete_enrollment_invite(target_invite_code text, target_name text, target_cpf text, target_whatsapp text, target_pix_key text, target_availability jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth'
AS $function$
declare
  invite_row public.student_enrollment_invites%rowtype;
  requester_user_id uuid;
  requester_email text;
  clean_cpf text;
  clean_whatsapp text;
  normalized_availability jsonb;
  enrollment_code text;
begin
  requester_user_id := auth.uid();
  requester_email := auth.jwt() ->> 'email';

  if requester_user_id is null then
    raise exception 'Usuário não autenticado.';
  end if;

  select * into invite_row
  from public.student_enrollment_invites
  where upper(invite_code) = upper(trim(target_invite_code))
  limit 1;

  if invite_row.id is null then
    raise exception 'Código de convite inválido.';
  end if;

  if invite_row.status <> 'pending' then
    raise exception 'Este convite não está mais disponível.';
  end if;

  if invite_row.expires_at is not null and invite_row.expires_at <= now() then
    update public.student_enrollment_invites
    set status = 'expired'
    where id = invite_row.id;
    raise exception 'Este convite expirou.';
  end if;

  clean_cpf := regexp_replace(coalesce(target_cpf, ''), '\D', '', 'g');
  clean_whatsapp := regexp_replace(coalesce(target_whatsapp, ''), '\D', '', 'g');
  normalized_availability := coalesce(target_availability, '{}'::jsonb);
  enrollment_code := invite_row.invite_code;

  if coalesce(trim(target_name), '') = '' then
    raise exception 'Informe o nome completo.';
  end if;

  if clean_cpf is null or length(clean_cpf) <> 11 then
    raise exception 'CPF inválido.';
  end if;

  if clean_whatsapp is null or length(clean_whatsapp) < 10 then
    raise exception 'WhatsApp inválido.';
  end if;

  if coalesce(trim(target_pix_key), '') = '' then
    raise exception 'Informe a chave PIX.';
  end if;

  insert into public.profiles (
    id,
    name,
    email,
    cpf,
    whatsapp,
    pix_key,
    availability,
    enrollment_code,
    enrolled,
    availability_seg_09,
    availability_seg_10,
    availability_seg_12,
    availability_seg_13,
    availability_seg_15,
    availability_seg_17,
    availability_seg_18,
    availability_seg_20,
    availability_seg_21,
    availability_ter_09,
    availability_ter_10,
    availability_ter_12,
    availability_ter_13,
    availability_ter_15,
    availability_ter_17,
    availability_ter_18,
    availability_ter_20,
    availability_ter_21,
    availability_qua_09,
    availability_qua_10,
    availability_qua_12,
    availability_qua_13,
    availability_qua_15,
    availability_qua_17,
    availability_qua_18,
    availability_qua_20,
    availability_qua_21,
    availability_qui_09,
    availability_qui_10,
    availability_qui_12,
    availability_qui_13,
    availability_qui_15,
    availability_qui_17,
    availability_qui_18,
    availability_qui_20,
    availability_qui_21,
    availability_sex_09,
    availability_sex_10,
    availability_sex_12,
    availability_sex_13,
    availability_sex_15,
    availability_sex_17,
    availability_sex_18,
    availability_sex_20,
    availability_sex_21
  )
  values (
    requester_user_id,
    trim(target_name),
    requester_email,
    clean_cpf,
    clean_whatsapp,
    trim(target_pix_key),
    normalized_availability,
    enrollment_code,
    true,
    coalesce((normalized_availability -> 'seg') ? '09', false),
    coalesce((normalized_availability -> 'seg') ? '10', false),
    coalesce((normalized_availability -> 'seg') ? '12', false),
    coalesce((normalized_availability -> 'seg') ? '13', false),
    coalesce((normalized_availability -> 'seg') ? '15', false),
    coalesce((normalized_availability -> 'seg') ? '17', false),
    coalesce((normalized_availability -> 'seg') ? '18', false),
    coalesce((normalized_availability -> 'seg') ? '20', false),
    coalesce((normalized_availability -> 'seg') ? '21', false),
    coalesce((normalized_availability -> 'ter') ? '09', false),
    coalesce((normalized_availability -> 'ter') ? '10', false),
    coalesce((normalized_availability -> 'ter') ? '12', false),
    coalesce((normalized_availability -> 'ter') ? '13', false),
    coalesce((normalized_availability -> 'ter') ? '15', false),
    coalesce((normalized_availability -> 'ter') ? '17', false),
    coalesce((normalized_availability -> 'ter') ? '18', false),
    coalesce((normalized_availability -> 'ter') ? '20', false),
    coalesce((normalized_availability -> 'ter') ? '21', false),
    coalesce((normalized_availability -> 'qua') ? '09', false),
    coalesce((normalized_availability -> 'qua') ? '10', false),
    coalesce((normalized_availability -> 'qua') ? '12', false),
    coalesce((normalized_availability -> 'qua') ? '13', false),
    coalesce((normalized_availability -> 'qua') ? '15', false),
    coalesce((normalized_availability -> 'qua') ? '17', false),
    coalesce((normalized_availability -> 'qua') ? '18', false),
    coalesce((normalized_availability -> 'qua') ? '20', false),
    coalesce((normalized_availability -> 'qua') ? '21', false),
    coalesce((normalized_availability -> 'qui') ? '09', false),
    coalesce((normalized_availability -> 'qui') ? '10', false),
    coalesce((normalized_availability -> 'qui') ? '12', false),
    coalesce((normalized_availability -> 'qui') ? '13', false),
    coalesce((normalized_availability -> 'qui') ? '15', false),
    coalesce((normalized_availability -> 'qui') ? '17', false),
    coalesce((normalized_availability -> 'qui') ? '18', false),
    coalesce((normalized_availability -> 'qui') ? '20', false),
    coalesce((normalized_availability -> 'qui') ? '21', false),
    coalesce((normalized_availability -> 'sex') ? '09', false),
    coalesce((normalized_availability -> 'sex') ? '10', false),
    coalesce((normalized_availability -> 'sex') ? '12', false),
    coalesce((normalized_availability -> 'sex') ? '13', false),
    coalesce((normalized_availability -> 'sex') ? '15', false),
    coalesce((normalized_availability -> 'sex') ? '17', false),
    coalesce((normalized_availability -> 'sex') ? '18', false),
    coalesce((normalized_availability -> 'sex') ? '20', false),
    coalesce((normalized_availability -> 'sex') ? '21', false)
  )
  on conflict (id) do update
  set
    name = excluded.name,
    email = excluded.email,
    cpf = excluded.cpf,
    whatsapp = excluded.whatsapp,
    pix_key = excluded.pix_key,
    availability = excluded.availability,
    enrollment_code = excluded.enrollment_code,
    enrolled = true,
    availability_seg_09 = excluded.availability_seg_09,
    availability_seg_10 = excluded.availability_seg_10,
    availability_seg_12 = excluded.availability_seg_12,
    availability_seg_13 = excluded.availability_seg_13,
    availability_seg_15 = excluded.availability_seg_15,
    availability_seg_17 = excluded.availability_seg_17,
    availability_seg_18 = excluded.availability_seg_18,
    availability_seg_20 = excluded.availability_seg_20,
    availability_seg_21 = excluded.availability_seg_21,
    availability_ter_09 = excluded.availability_ter_09,
    availability_ter_10 = excluded.availability_ter_10,
    availability_ter_12 = excluded.availability_ter_12,
    availability_ter_13 = excluded.availability_ter_13,
    availability_ter_15 = excluded.availability_ter_15,
    availability_ter_17 = excluded.availability_ter_17,
    availability_ter_18 = excluded.availability_ter_18,
    availability_ter_20 = excluded.availability_ter_20,
    availability_ter_21 = excluded.availability_ter_21,
    availability_qua_09 = excluded.availability_qua_09,
    availability_qua_10 = excluded.availability_qua_10,
    availability_qua_12 = excluded.availability_qua_12,
    availability_qua_13 = excluded.availability_qua_13,
    availability_qua_15 = excluded.availability_qua_15,
    availability_qua_17 = excluded.availability_qua_17,
    availability_qua_18 = excluded.availability_qua_18,
    availability_qua_20 = excluded.availability_qua_20,
    availability_qua_21 = excluded.availability_qua_21,
    availability_qui_09 = excluded.availability_qui_09,
    availability_qui_10 = excluded.availability_qui_10,
    availability_qui_12 = excluded.availability_qui_12,
    availability_qui_13 = excluded.availability_qui_13,
    availability_qui_15 = excluded.availability_qui_15,
    availability_qui_17 = excluded.availability_qui_17,
    availability_qui_18 = excluded.availability_qui_18,
    availability_qui_20 = excluded.availability_qui_20,
    availability_qui_21 = excluded.availability_qui_21,
    availability_sex_09 = excluded.availability_sex_09,
    availability_sex_10 = excluded.availability_sex_10,
    availability_sex_12 = excluded.availability_sex_12,
    availability_sex_13 = excluded.availability_sex_13,
    availability_sex_15 = excluded.availability_sex_15,
    availability_sex_17 = excluded.availability_sex_17,
    availability_sex_18 = excluded.availability_sex_18,
    availability_sex_20 = excluded.availability_sex_20,
    availability_sex_21 = excluded.availability_sex_21;

  update auth.users
  set raw_user_meta_data = coalesce(raw_user_meta_data, '{}'::jsonb) || jsonb_build_object(
    'name', trim(target_name),
    'cpf', clean_cpf,
    'whatsapp', clean_whatsapp,
    'pix_key', trim(target_pix_key),
    'availability', normalized_availability,
    'enrollment_code', enrollment_code,
    'enrolled', true
  ),
  updated_at = now()
  where id = requester_user_id;

  update public.student_enrollment_invites
  set
    status = 'completed',
    user_id = requester_user_id,
    email = requester_email,
    cpf = clean_cpf,
    whatsapp = clean_whatsapp,
    pix_key = trim(target_pix_key),
    availability = normalized_availability,
    completed_at = now()
  where id = invite_row.id;

  return jsonb_build_object('ok', true, 'enrollment_code', enrollment_code);
end;
$function$;


CREATE OR REPLACE FUNCTION public.get_teacher_class_students(target_class_number integer)
 RETURNS TABLE(id text, class_number integer, user_id text, invite_id text, student_ref_id text, student_ref_type text, student_name text, student_email text, enrollment_code text, pre_enrollment_status text, created_at timestamp with time zone)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth'
AS $function$
begin
  if not public.is_teacher_admin() then
    raise exception 'Acesso negado: usuário não cadastrado como professor.';
  end if;

  perform public.assert_teacher_class_exists(target_class_number);

  return query
  select
    cs.id::text,
    cs.class_number,
    cs.user_id::text,
    cs.invite_id::text,
    coalesce(cs.user_id::text, cs.invite_id::text) as student_ref_id,
    case when cs.user_id is not null then 'user' else 'invite' end::text as student_ref_type,
    coalesce(p.name, u.raw_user_meta_data ->> 'name', sei.student_name, u.email, 'Aluno sem nome')::text as student_name,
    coalesce(p.email, u.email, sei.email, '')::text as student_email,
    coalesce(p.enrollment_code, u.raw_user_meta_data ->> 'enrollment_code', sei.invite_code, '')::text as enrollment_code,
    coalesce(sei.status, case when cs.user_id is not null then 'completed' else 'pending' end)::text as pre_enrollment_status,
    cs.created_at
  from public.class_students cs
  left join public.profiles p on p.id = cs.user_id
  left join auth.users u on u.id = cs.user_id
  left join public.student_enrollment_invites sei on sei.id = cs.invite_id
  where cs.class_number = target_class_number
    and (cs.user_id is null or coalesce(p.archived, false) = false)
  order by student_name asc, student_email asc;
end;
$function$;


CREATE OR REPLACE FUNCTION public.add_teacher_class_student_by_ref(target_class_number integer, target_student_ref_id text, target_student_ref_type text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth'
AS $function$
declare
  inserted_id uuid;
  target_user_id uuid;
  target_invite_id uuid;
  student_type text;
  student_type_internal text;
  class_type_value text;
begin
  if not public.is_teacher_admin() then
    raise exception 'Acesso negado: usuário não cadastrado como professor.';
  end if;

  perform public.assert_teacher_class_exists(target_class_number);

  select tc.class_type into class_type_value
  from public.teacher_classes tc
  where tc.class_number = target_class_number and tc.is_active = true;

  if class_type_value is null then
    raise exception 'Defina a etiqueta da turma antes de matricular alunos.';
  end if;

  if target_student_ref_type = 'user' then
    target_user_id := target_student_ref_id::uuid;

    if not exists (
      select 1 from auth.users u
      where u.id = target_user_id
        and not exists (
          select 1 from public.teacher_admins ta
          where lower(ta.email) = lower(u.email)
        )
    ) then
      raise exception 'Aluno não encontrado.';
    end if;

    select p.class_type into student_type
    from public.profiles p where p.id = target_user_id;

  elsif target_student_ref_type = 'invite' then
    target_invite_id := target_student_ref_id::uuid;

    if not exists (
      select 1 from public.student_enrollment_invites sei
      where sei.id = target_invite_id and sei.status in ('pending', 'completed')
    ) then
      raise exception 'Pré-matrícula não encontrada.';
    end if;

    select p.class_type into student_type
    from public.student_enrollment_invites sei
    join public.profiles p on p.id = sei.user_id
    where sei.id = target_invite_id;
  else
    raise exception 'Tipo de aluno inválido.';
  end if;

  if student_type is null then
    raise exception 'Classifique o tipo de turma do aluno antes de matriculá-lo.';
  end if;

  student_type_internal := case upper(trim(student_type))
    when 'INDIVIDUAL' then 'individual'
    when 'QUARTETO' then 'quartet'
    when '8 ALUNOS' then 'eight_students'
    else null
  end;

  if student_type_internal is null then
    raise exception 'Tipo de turma do aluno inválido: %.', student_type;
  end if;

  if student_type_internal <> class_type_value then
    raise exception 'Tipo incompatível: aluno % e turma %.',
      student_type,
      case class_type_value when 'individual' then 'INDIVIDUAL' when 'quartet' then 'QUARTETO' when 'eight_students' then '8 ALUNOS' else class_type_value end;
  end if;

  if target_student_ref_type = 'user' then
    delete from public.class_students
    where user_id = target_user_id and class_number <> target_class_number;

    insert into public.class_students (class_number, user_id, invite_id)
    values (target_class_number, target_user_id, null)
    on conflict (class_number, user_id) do update
    set user_id = excluded.user_id, invite_id = null
    returning id into inserted_id;
  else
    delete from public.class_students
    where invite_id = target_invite_id and class_number <> target_class_number;

    insert into public.class_students (class_number, user_id, invite_id)
    values (target_class_number, null, target_invite_id)
    on conflict (class_number, invite_id) where invite_id is not null do update
    set invite_id = excluded.invite_id, user_id = null
    returning id into inserted_id;
  end if;

  return jsonb_build_object('ok', true, 'id', inserted_id, 'class_number', target_class_number, 'class_type', class_type_value);
end;
$function$;


CREATE OR REPLACE FUNCTION public.remove_teacher_class_student_by_ref(target_class_number integer, target_student_ref_id text, target_student_ref_type text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not public.is_teacher_admin() then
    raise exception 'Acesso negado: usuário não cadastrado como professor.';
  end if;

  perform public.assert_teacher_class_exists(target_class_number);

  if target_student_ref_type = 'user' then
    delete from public.class_students
    where class_number = target_class_number
      and user_id = target_student_ref_id::uuid;
  elsif target_student_ref_type = 'invite' then
    delete from public.class_students
    where class_number = target_class_number
      and invite_id = target_student_ref_id::uuid;
  else
    raise exception 'Tipo de aluno inválido.';
  end if;

  if not found then
    raise exception 'Aluno não encontrado nesta turma.';
  end if;

  return jsonb_build_object('ok', true);
end;
$function$;


CREATE OR REPLACE FUNCTION public.get_teacher_class_activity_history(target_class_number integer)
 RETURNS TABLE(frequency_id text, class_number integer, user_id text, invite_id text, student_ref_id text, student_ref_type text, student_name text, student_email text, enrollment_code text, class_date date, attendance_status text, class_notes text, created_at timestamp with time zone, updated_at timestamp with time zone)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth'
AS $function$
begin
  if not public.is_teacher_admin() then
    raise exception 'Acesso negado: usuário não cadastrado como professor.';
  end if;

  perform public.assert_teacher_class_exists(target_class_number);

  return query
  select
    sf.id::text as frequency_id,
    cs.class_number,
    sf.user_id::text,
    sf.invite_id::text,
    coalesce(sf.user_id::text, sf.invite_id::text) as student_ref_id,
    case when sf.user_id is not null then 'user' else 'invite' end::text as student_ref_type,
    coalesce(p.name, u.raw_user_meta_data ->> 'name', sei.student_name, u.email, 'Aluno sem nome')::text as student_name,
    coalesce(p.email, u.email, sei.email, '')::text as student_email,
    coalesce(p.enrollment_code, u.raw_user_meta_data ->> 'enrollment_code', sei.invite_code, '')::text as enrollment_code,
    sf.class_date,
    sf.attendance_status,
    coalesce(sf.class_notes, '')::text as class_notes,
    sf.created_at,
    sf.updated_at
  from public.student_frequency sf
  join public.class_students cs
    on cs.class_number = target_class_number
   and (
     (sf.user_id is not null and cs.user_id = sf.user_id)
     or
     (sf.invite_id is not null and cs.invite_id = sf.invite_id)
   )
  left join public.profiles p on p.id = sf.user_id
  left join auth.users u on u.id = sf.user_id
  left join public.student_enrollment_invites sei on sei.id = coalesce(sf.invite_id, cs.invite_id)
  where sf.class_notes ilike ('[Turma ' || target_class_number || ']%')
  order by sf.class_date desc, sf.created_at desc, student_name asc;
end;
$function$;


CREATE OR REPLACE FUNCTION public.save_teacher_class_attendance_by_ref(target_class_number integer, target_class_date date, target_general_notes text, attendance_records jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth'
AS $function$
declare
  item jsonb;
  target_user_id uuid;
  target_invite_id uuid;
  target_ref_id text;
  target_ref_type text;
  target_status text;
  target_notes text;
  inserted_count integer := 0;
begin
  if not public.is_teacher_admin() then
    raise exception 'Acesso negado: usuário não cadastrado como professor.';
  end if;

  perform public.assert_teacher_class_exists(target_class_number);

  if attendance_records is null or jsonb_array_length(attendance_records) = 0 then
    raise exception 'Nenhum aluno foi selecionado para registrar frequência.';
  end if;

  for item in select * from jsonb_array_elements(attendance_records)
  loop
    target_ref_id := item ->> 'student_ref_id';
    target_ref_type := item ->> 'student_ref_type';
    target_status := coalesce(item ->> 'attendance_status', 'Compareceu');
    target_notes := coalesce(nullif(item ->> 'class_notes', ''), target_general_notes, '');
    target_user_id := null;
    target_invite_id := null;

    if target_status not in ('Compareceu', 'Faltou') then
      raise exception 'Situação inválida para um dos alunos.';
    end if;

    if target_ref_type = 'user' then
      target_user_id := target_ref_id::uuid;
      if not exists (
        select 1 from public.class_students cs
        where cs.class_number = target_class_number
          and cs.user_id = target_user_id
      ) then
        raise exception 'Um dos alunos selecionados não pertence a esta turma.';
      end if;
    elsif target_ref_type = 'invite' then
      target_invite_id := target_ref_id::uuid;
      if not exists (
        select 1 from public.class_students cs
        where cs.class_number = target_class_number
          and cs.invite_id = target_invite_id
      ) then
        raise exception 'Uma das pré-matrículas selecionadas não pertence a esta turma.';
      end if;
    else
      raise exception 'Tipo de aluno inválido.';
    end if;

    insert into public.student_frequency (user_id, invite_id, class_date, attendance_status, class_notes)
    values (
      target_user_id,
      target_invite_id,
      target_class_date,
      target_status,
      '[Turma ' || target_class_number || '] ' || target_notes
    );

    inserted_count := inserted_count + 1;
  end loop;

  return jsonb_build_object('ok', true, 'inserted_count', inserted_count);
end;
$function$;


CREATE OR REPLACE FUNCTION public.migrate_invite_records_to_user()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if new.status = 'completed' and new.user_id is not null then
    -- A turma vinculada ao convite concluído passa a ser a turma atual do aluno.
    delete from public.class_students
    where user_id = new.user_id
      and (invite_id is distinct from new.id);

    update public.class_students
    set user_id = new.user_id
    where invite_id = new.id
      and user_id is null;

    update public.student_frequency
    set user_id = new.user_id
    where invite_id = new.id
      and user_id is null;
  end if;

  return new;
end;
$function$;


CREATE OR REPLACE FUNCTION public.get_teacher_student_tags()
 RETURNS TABLE(id text, user_id text, invite_id text, student_ref_id text, student_ref_type text, tag_name text, created_at timestamp with time zone)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not public.is_teacher_admin() then
    raise exception 'Acesso negado: usuário não cadastrado como professor.';
  end if;

  return query
  select
    st.id::text,
    st.user_id::text,
    st.invite_id::text,
    coalesce(st.user_id::text, st.invite_id::text) as student_ref_id,
    case when st.user_id is not null then 'user' else 'invite' end::text as student_ref_type,
    st.tag_name::text,
    st.created_at
  from public.student_tags st
  order by st.created_at desc;
end;
$function$;


CREATE OR REPLACE FUNCTION public.toggle_teacher_student_tag(target_student_ref_id text, target_student_ref_type text, target_tag_name text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth'
AS $function$
declare
  target_user_id uuid;
  target_invite_id uuid;
  existing_id uuid;
  normalized_tag text;
begin
  if not public.is_teacher_admin() then
    raise exception 'Acesso negado: usuário não cadastrado como professor.';
  end if;

  normalized_tag := lower(trim(target_tag_name));

  if normalized_tag = '' then
    raise exception 'Tag inválida.';
  end if;

  if target_student_ref_type = 'user' then
    target_user_id := target_student_ref_id::uuid;

    select id into existing_id
    from public.student_tags
    where user_id = target_user_id
      and tag_name = normalized_tag
    limit 1;

    if existing_id is not null then
      delete from public.student_tags where id = existing_id;
      return jsonb_build_object('ok', true, 'tagged', false, 'tag_name', normalized_tag);
    end if;

    insert into public.student_tags(user_id, tag_name, created_by)
    values (target_user_id, normalized_tag, auth.uid());

    return jsonb_build_object('ok', true, 'tagged', true, 'tag_name', normalized_tag);
  elsif target_student_ref_type = 'invite' then
    target_invite_id := target_student_ref_id::uuid;

    select id into existing_id
    from public.student_tags
    where invite_id = target_invite_id
      and tag_name = normalized_tag
    limit 1;

    if existing_id is not null then
      delete from public.student_tags where id = existing_id;
      return jsonb_build_object('ok', true, 'tagged', false, 'tag_name', normalized_tag);
    end if;

    insert into public.student_tags(invite_id, tag_name, created_by)
    values (target_invite_id, normalized_tag, auth.uid());

    return jsonb_build_object('ok', true, 'tagged', true, 'tag_name', normalized_tag);
  else
    raise exception 'Tipo de aluno inválido.';
  end if;
end;
$function$;


CREATE OR REPLACE FUNCTION public.migrate_invite_student_tags_to_user()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if new.status = 'completed' and new.user_id is not null then
    update public.student_tags
    set user_id = new.user_id
    where invite_id = new.id
      and user_id is null;
  end if;

  return new;
end;
$function$;


CREATE OR REPLACE FUNCTION public.get_teacher_class_lesson_records(target_class_number integer)
 RETURNS TABLE(id text, class_number integer, user_id text, invite_id text, student_ref_id text, student_ref_type text, class_date date, lesson_code text, created_at timestamp with time zone, updated_at timestamp with time zone)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not public.is_teacher_admin() then
    raise exception 'Acesso negado: usuário não cadastrado como professor.';
  end if;

  perform public.assert_teacher_class_exists(target_class_number);

  return query
  select
    clr.id::text,
    clr.class_number,
    clr.user_id::text,
    clr.invite_id::text,
    coalesce(clr.user_id::text, clr.invite_id::text) as student_ref_id,
    case when clr.user_id is not null then 'user' else 'invite' end::text as student_ref_type,
    clr.class_date,
    clr.lesson_code,
    clr.created_at,
    clr.updated_at
  from public.class_lesson_records clr
  where exists (
    select 1
    from public.class_students cs
    where cs.class_number = target_class_number
      and (
        (clr.user_id is not null and cs.user_id = clr.user_id)
        or
        (clr.invite_id is not null and cs.invite_id = clr.invite_id)
      )
  )
  order by clr.class_date desc, clr.created_at desc;
end;
$function$;


CREATE OR REPLACE FUNCTION public.save_teacher_class_lesson_record_by_ref(target_class_number integer, target_student_ref_id text, target_student_ref_type text, target_class_date date, target_lesson_code text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth'
AS $function$
declare
  target_user_id uuid;
  target_invite_id uuid;
  saved_id uuid;
begin
  if not public.is_teacher_admin() then
    raise exception 'Acesso negado: usuário não cadastrado como professor.';
  end if;

  perform public.assert_teacher_class_exists(target_class_number);

  if nullif(trim(target_student_ref_id), '') is null then
    raise exception 'Aluno inválido: referência vazia.';
  end if;

  if not (
    target_lesson_code ~ '^L([1-9]|[1-6][0-9]|7[0-4])$'
    or target_lesson_code in (
      'Feriado',
      'Teacher Cancelou',
      'Não compareceu',
      'Conversation',
      'Outras atividades',
      'Problemas técnicos'
    )
  ) then
    raise exception 'Registro inválido. Use L1 a L74 ou uma das opções especiais.';
  end if;

  if target_student_ref_type = 'user' then
    target_user_id := target_student_ref_id::uuid;
    if not exists (
      select 1 from public.class_students cs
      where cs.class_number = target_class_number and cs.user_id = target_user_id
    ) then
      raise exception 'Este aluno não pertence a esta turma.';
    end if;

    insert into public.class_lesson_records(class_number,user_id,invite_id,class_date,lesson_code)
    values (target_class_number,target_user_id,null,target_class_date,target_lesson_code)
    on conflict (class_number,user_id,class_date,lesson_code) where user_id is not null
    do update set updated_at = now()
    returning id into saved_id;

  elsif target_student_ref_type = 'invite' then
    target_invite_id := target_student_ref_id::uuid;
    if not exists (
      select 1 from public.class_students cs
      where cs.class_number = target_class_number and cs.invite_id = target_invite_id
    ) then
      raise exception 'Esta pré-matrícula não pertence a esta turma.';
    end if;

    insert into public.class_lesson_records(class_number,user_id,invite_id,class_date,lesson_code)
    values (target_class_number,null,target_invite_id,target_class_date,target_lesson_code)
    on conflict (class_number,invite_id,class_date,lesson_code) where invite_id is not null
    do update set updated_at = now()
    returning id into saved_id;
  else
    raise exception 'Tipo de aluno inválido.';
  end if;

  return jsonb_build_object(
    'ok', true,
    'id', saved_id,
    'class_number', target_class_number,
    'student_ref_id', coalesce(target_user_id::text, target_invite_id::text),
    'student_ref_type', target_student_ref_type,
    'class_date', target_class_date,
    'lesson_code', target_lesson_code
  );
end;
$function$;


CREATE OR REPLACE FUNCTION public.get_teacher_class_resources(target_class_number integer)
 RETURNS TABLE(class_number integer, video_lesson_url text, lesson_material_url text, recorded_lessons_url text, whatsapp_group_url text, updated_at timestamp with time zone)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not public.is_teacher_admin() then
    raise exception 'Acesso negado: usuário não cadastrado como professor.';
  end if;

  perform public.assert_teacher_class_exists(target_class_number);

  return query
  select
    cr.class_number,
    coalesce(cr.video_lesson_url, '')::text,
    coalesce(cr.lesson_material_url, '')::text,
    coalesce(cr.recorded_lessons_url, '')::text,
    coalesce(cr.whatsapp_group_url, '')::text,
    cr.updated_at
  from public.class_resources cr
  where cr.class_number = target_class_number;
end;
$function$;


CREATE OR REPLACE FUNCTION public.get_my_student_class()
 RETURNS TABLE(id text, class_number integer, class_name text, user_id text, student_name text, student_email text, enrollment_code text, video_lesson_url text, lesson_material_url text, recorded_lessons_url text, whatsapp_group_url text, created_at timestamp with time zone)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth'
AS $function$
begin
  return query
  select
    cs.id::text,
    cs.class_number,
    coalesce(tc.class_name, 'Turma ' || cs.class_number)::text as class_name,
    cs.user_id::text,
    coalesce(p.name, u.raw_user_meta_data ->> 'name', u.email, 'Aluno sem nome')::text as student_name,
    coalesce(p.email, u.email, '')::text as student_email,
    coalesce(p.enrollment_code, u.raw_user_meta_data ->> 'enrollment_code', '')::text as enrollment_code,
    coalesce(cr.video_lesson_url, '')::text as video_lesson_url,
    coalesce(cr.lesson_material_url, '')::text as lesson_material_url,
    coalesce(cr.recorded_lessons_url, '')::text as recorded_lessons_url,
    coalesce(cr.whatsapp_group_url, '')::text as whatsapp_group_url,
    cs.created_at
  from public.class_students cs
  left join public.teacher_classes tc on tc.class_number = cs.class_number and tc.is_active = true
  left join public.profiles p on p.id = cs.user_id
  left join auth.users u on u.id = cs.user_id
  left join public.class_resources cr on cr.class_number = cs.class_number
  where cs.user_id = auth.uid()
  order by cs.created_at desc;
end;
$function$;


CREATE OR REPLACE FUNCTION public.save_teacher_classes_order(classes_order jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  item jsonb;
  target_class_number integer;
  target_display_order integer;
  updated_count integer := 0;
begin
  if not public.is_teacher_admin() then
    raise exception 'Acesso negado: usuário não cadastrado como professor.';
  end if;

  if classes_order is null or jsonb_typeof(classes_order) <> 'array' then
    raise exception 'Formato de ordem inválido.';
  end if;

  for item in select * from jsonb_array_elements(classes_order)
  loop
    target_class_number := (item ->> 'class_number')::integer;
    target_display_order := (item ->> 'display_order')::integer;

    if target_class_number is null or target_display_order is null or target_display_order < 1 then
      raise exception 'Item de ordem inválido.';
    end if;

    update public.teacher_classes
    set display_order = target_display_order
    where class_number = target_class_number
      and is_active = true;

    if found then
      updated_count := updated_count + 1;
    end if;
  end loop;

  return jsonb_build_object('ok', true, 'updated_count', updated_count);
end;
$function$;


CREATE OR REPLACE FUNCTION public.create_teacher_exercise(target_exercise_id text, target_exercise_title text, target_exercise_url text, target_scheduled_publish_at timestamp with time zone DEFAULT NULL::timestamp with time zone)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  new_id uuid;
begin
  if not public.is_teacher_admin() then
    raise exception 'Acesso negado: usuário não cadastrado como professor.';
  end if;

  if coalesce(trim(target_exercise_title), '') = '' then
    raise exception 'Informe o título do exercício.';
  end if;

  if coalesce(trim(target_exercise_url), '') = '' then
    raise exception 'Informe o link do exercício.';
  end if;

  insert into public.teacher_exercises (
    exercise_id,
    exercise_title,
    exercise_url,
    created_by,
    is_active,
    scheduled_publish_at
  )
  values (
    target_exercise_id,
    trim(target_exercise_title),
    trim(target_exercise_url),
    auth.uid(),
    true,
    target_scheduled_publish_at
  )
  returning id into new_id;

  return jsonb_build_object('ok', true, 'id', new_id, 'scheduled_publish_at', target_scheduled_publish_at);
end;
$function$;


CREATE OR REPLACE FUNCTION public.get_teacher_created_exercises()
 RETURNS TABLE(id text, exercise_id text, exercise_title text, exercise_url text, is_active boolean, scheduled_publish_at timestamp with time zone, created_at timestamp with time zone, updated_at timestamp with time zone)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not public.is_teacher_admin() then
    raise exception 'Acesso negado: usuário não cadastrado como professor.';
  end if;

  return query
  select
    te.id::text,
    te.exercise_id,
    te.exercise_title,
    te.exercise_url,
    te.is_active,
    te.scheduled_publish_at,
    te.created_at,
    te.updated_at
  from public.teacher_exercises te
  order by coalesce(te.scheduled_publish_at, te.created_at) desc, te.created_at desc;
end;
$function$;


CREATE OR REPLACE FUNCTION public.delete_teacher_exercise(target_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  target_exercise_id text;
  deleted_completion_count integer := 0;
  deleted_exercise_count integer := 0;
begin
  if not public.is_teacher_admin() then
    raise exception 'Acesso negado: usuário não cadastrado como professor.';
  end if;

  select te.exercise_id
  into target_exercise_id
  from public.teacher_exercises te
  where te.id = target_id;

  if target_exercise_id is null then
    raise exception 'Exercício não encontrado.';
  end if;

  if to_regclass('public.daily_exercise_completion') is not null then
    delete from public.daily_exercise_completion
    where exercise_id = target_exercise_id;
    get diagnostics deleted_completion_count = row_count;
  end if;

  delete from public.teacher_exercises
  where id = target_id;
  get diagnostics deleted_exercise_count = row_count;

  return jsonb_build_object(
    'ok', deleted_exercise_count = 1,
    'deleted_exercise_count', deleted_exercise_count,
    'deleted_completion_count', deleted_completion_count
  );
end;
$function$;


CREATE OR REPLACE FUNCTION public.get_public_teacher_exercises()
 RETURNS TABLE(exercise_id text, exercise_title text, exercise_url text, scheduled_publish_at timestamp with time zone, created_at timestamp with time zone)
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select
    te.exercise_id,
    te.exercise_title,
    te.exercise_url,
    te.scheduled_publish_at,
    te.created_at
  from public.teacher_exercises te
  where te.is_active = true
    and (te.scheduled_publish_at is null or te.scheduled_publish_at <= now())
  order by coalesce(te.scheduled_publish_at, te.created_at) desc, te.created_at desc;
$function$;


CREATE OR REPLACE FUNCTION public.get_teacher_students()
 RETURNS TABLE(id text, user_id text, name text, email text, cpf text, whatsapp text, pix_key text, enrollment_code text, enrolled boolean, availability jsonb, source text, created_at timestamp with time zone)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth'
AS $function$
declare
  requester_email text;
begin
  requester_email := auth.jwt() ->> 'email';

  if requester_email is null or not exists (
    select 1 from public.teacher_admins ta
    where lower(ta.email) = lower(requester_email)
  ) then
    raise exception 'Acesso negado: usuário não cadastrado como professor.';
  end if;

  return query
  with profile_rows as (
    select
      p.id::uuid as uid,
      p.id::text as id,
      p.id::text as user_id,
      coalesce(p.name, '')::text as name,
      coalesce(p.email, '')::text as email,
      coalesce(p.cpf, '')::text as cpf,
      coalesce(p.whatsapp, '')::text as whatsapp,
      coalesce(p.pix_key, '')::text as pix_key,
      coalesce(p.enrollment_code, '')::text as enrollment_code,
      coalesce(p.enrolled, false)::boolean as enrolled,
      coalesce(p.availability::jsonb, '{}'::jsonb) as availability,
      'profiles'::text as source,
      p.created_at as created_at
    from public.profiles p
    where coalesce(p.archived, false) = false
  ),
  auth_rows as (
    select
      u.id::uuid as uid,
      u.id::text as id,
      u.id::text as user_id,
      coalesce(u.raw_user_meta_data ->> 'name', '')::text as name,
      coalesce(u.email, '')::text as email,
      coalesce(u.raw_user_meta_data ->> 'cpf', '')::text as cpf,
      coalesce(u.raw_user_meta_data ->> 'whatsapp', '')::text as whatsapp,
      coalesce(u.raw_user_meta_data ->> 'pix_key', '')::text as pix_key,
      coalesce(u.raw_user_meta_data ->> 'enrollment_code', '')::text as enrollment_code,
      coalesce((u.raw_user_meta_data ->> 'enrolled')::boolean, false)::boolean as enrolled,
      coalesce(u.raw_user_meta_data -> 'availability', '{}'::jsonb) as availability,
      'auth.users'::text as source,
      u.created_at as created_at
    from auth.users u
    where not exists (
      select 1 from public.teacher_admins ta
      where lower(ta.email) = lower(u.email)
    )
  ),
  merged_rows as (
    select * from profile_rows
    union all
    select * from auth_rows ar
    where not exists (
      select 1 from public.profiles p
      where p.id = ar.uid
    )
  )
  select
    mr.id,
    mr.user_id,
    mr.name,
    mr.email,
    mr.cpf,
    mr.whatsapp,
    mr.pix_key,
    mr.enrollment_code,
    mr.enrolled,
    mr.availability,
    mr.source,
    mr.created_at
  from merged_rows mr
  where not exists (
    select 1 from public.teacher_admins ta
    where lower(ta.email) = lower(mr.email)
  )
  order by mr.name asc nulls last, mr.email asc nulls last;
end;
$function$;


CREATE OR REPLACE FUNCTION public.get_teacher_billing_students()
 RETURNS TABLE(student_id uuid, name text, email text, monthly_fee numeric, due_day smallint, billing_start_month date, billing_active boolean, billing_notes text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not coalesce(public.is_teacher_admin(), false) then
    raise exception 'Acesso negado: usuário não cadastrado como administrador.';
  end if;

  return query
  select
    p.id,
    coalesce(p.name, '')::text,
    coalesce(p.email, '')::text,
    s.monthly_fee,
    s.due_day,
    s.billing_start_month,
    s.active,
    coalesce(s.notes, '')::text
  from public.profiles p
  left join public.student_billing_settings s on s.student_id = p.id
  where coalesce(p.enrolled, false) = true
    and coalesce(p.archived, false) = false
    and not exists (
      select 1
      from public.teacher_admins ta
      where ta.user_id = p.id
         or lower(ta.email) = lower(coalesce(p.email, ''))
    )
  order by p.name asc nulls last, p.email asc nulls last;
end;
$function$;


CREATE OR REPLACE FUNCTION public.save_student_billing_settings(target_student_id uuid, target_monthly_fee numeric, target_due_day integer, target_billing_start_month date, target_active boolean, target_notes text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  normalized_start_month date;
begin
  if not coalesce(public.is_teacher_admin(), false) then
    raise exception 'Acesso negado: usuário não cadastrado como administrador.';
  end if;

  if target_monthly_fee is null or target_monthly_fee <= 0 then
    raise exception 'Informe um valor mensal maior que zero.';
  end if;

  if target_due_day is null or target_due_day < 1 or target_due_day > 31 then
    raise exception 'O dia do vencimento deve estar entre 1 e 31.';
  end if;

  if not exists (
    select 1
    from public.profiles p
    where p.id = target_student_id
      and coalesce(p.enrolled, false) = true
  ) then
    raise exception 'Aluno matriculado não encontrado.';
  end if;

  normalized_start_month := date_trunc(
    'month',
    coalesce(target_billing_start_month, current_date)
  )::date;

  insert into public.student_billing_settings (
    student_id,
    monthly_fee,
    due_day,
    billing_start_month,
    active,
    notes,
    updated_at,
    updated_by
  ) values (
    target_student_id,
    round(target_monthly_fee, 2),
    target_due_day,
    normalized_start_month,
    coalesce(target_active, true),
    nullif(trim(coalesce(target_notes, '')), ''),
    now(),
    auth.uid()
  )
  on conflict (student_id) do update
  set
    monthly_fee = excluded.monthly_fee,
    due_day = excluded.due_day,
    billing_start_month = excluded.billing_start_month,
    active = excluded.active,
    notes = excluded.notes,
    updated_at = now(),
    updated_by = auth.uid();

  return jsonb_build_object('ok', true, 'student_id', target_student_id);
end;
$function$;


CREATE OR REPLACE FUNCTION public.generate_monthly_tuition(target_reference_month date)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  normalized_reference_month date;
  affected_count integer := 0;
begin
  if not coalesce(public.is_teacher_admin(), false) then
    raise exception 'Acesso negado: usuário não cadastrado como administrador.';
  end if;

  normalized_reference_month := date_trunc(
    'month',
    coalesce(target_reference_month, current_date)
  )::date;

  insert into public.monthly_tuition (
    student_id,
    reference_month,
    due_date,
    amount_due,
    created_by,
    updated_by
  )
  select
    s.student_id,
    generated_month.reference_month::date,
    make_date(
      extract(year from generated_month.reference_month)::integer,
      extract(month from generated_month.reference_month)::integer,
      least(
        s.due_day::integer,
        extract(
          day from (
            date_trunc('month', generated_month.reference_month)
            + interval '1 month - 1 day'
          )
        )::integer
      )
    ),
    s.monthly_fee,
    auth.uid(),
    auth.uid()
  from public.student_billing_settings s
  join public.profiles p on p.id = s.student_id
  cross join lateral generate_series(
    s.billing_start_month::timestamp,
    normalized_reference_month::timestamp,
    interval '1 month'
  ) as generated_month(reference_month)
  where s.active = true
    and s.billing_start_month <= normalized_reference_month
    and coalesce(p.enrolled, false) = true
  on conflict (student_id, reference_month) do update
  set
    due_date = excluded.due_date,
    amount_due = excluded.amount_due,
    updated_at = now(),
    updated_by = auth.uid()
  where public.monthly_tuition.payment_date is null
    and (
      public.monthly_tuition.due_date is distinct from excluded.due_date
      or public.monthly_tuition.amount_due is distinct from excluded.amount_due
    );

  get diagnostics affected_count = row_count;
  return affected_count;
end;
$function$;


CREATE OR REPLACE FUNCTION public.get_teacher_monthly_tuition(target_reference_month date)
 RETURNS TABLE(tuition_id uuid, student_id uuid, student_name text, student_email text, reference_month date, due_date date, amount_due numeric, payment_date date, amount_paid numeric, payment_method text, payment_notes text, payment_status text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  normalized_reference_month date;
begin
  if not coalesce(public.is_teacher_admin(), false) then
    raise exception 'Acesso negado: usuário não cadastrado como administrador.';
  end if;

  normalized_reference_month := date_trunc(
    'month',
    coalesce(target_reference_month, current_date)
  )::date;

  return query
  select
    mt.id,
    mt.student_id,
    coalesce(p.name, '')::text,
    coalesce(p.email, '')::text,
    mt.reference_month,
    mt.due_date,
    mt.amount_due,
    mt.payment_date,
    mt.amount_paid,
    mt.payment_method,
    coalesce(mt.payment_notes, '')::text,
    case
      when mt.payment_date is not null then 'paid'
      when mt.due_date < current_date then 'overdue'
      when mt.due_date <= current_date + 7 then 'due_soon'
      else 'open'
    end::text
  from public.monthly_tuition mt
  join public.profiles p on p.id = mt.student_id
  where mt.reference_month = normalized_reference_month
     or (
       mt.reference_month < normalized_reference_month
       and mt.payment_date is null
     )
  order by mt.due_date asc, p.name asc nulls last;
end;
$function$;


CREATE OR REPLACE FUNCTION public.get_teacher_student_tuition_history(target_student_id uuid)
 RETURNS TABLE(tuition_id uuid, reference_month date, due_date date, amount_due numeric, payment_date date, amount_paid numeric, payment_method text, payment_notes text, payment_status text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not coalesce(public.is_teacher_admin(), false) then
    raise exception 'Acesso negado: usuário não cadastrado como administrador.';
  end if;

  return query
  select
    mt.id,
    mt.reference_month,
    mt.due_date,
    mt.amount_due,
    mt.payment_date,
    mt.amount_paid,
    mt.payment_method,
    coalesce(mt.payment_notes, '')::text,
    case
      when mt.payment_date is not null then 'paid'
      when mt.due_date < current_date then 'overdue'
      when mt.due_date <= current_date + 7 then 'due_soon'
      else 'open'
    end::text
  from public.monthly_tuition mt
  where mt.student_id = target_student_id
  order by mt.reference_month desc;
end;
$function$;


CREATE OR REPLACE FUNCTION public.record_tuition_payment(target_tuition_id uuid, target_payment_date date, target_amount_paid numeric, target_payment_method text, target_payment_notes text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  target_row public.monthly_tuition%rowtype;
  normalized_method text;
begin
  if not coalesce(public.is_teacher_admin(), false) then
    raise exception 'Acesso negado: usuário não cadastrado como administrador.';
  end if;

  select * into target_row
  from public.monthly_tuition mt
  where mt.id = target_tuition_id
  for update;

  if not found then
    raise exception 'Mensalidade não encontrada.';
  end if;

  if target_amount_paid is null or target_amount_paid <= 0 then
    raise exception 'Informe um valor pago maior que zero.';
  end if;

  normalized_method := lower(trim(coalesce(target_payment_method, '')));
  if normalized_method not in ('pix', 'cash', 'bank_transfer', 'card', 'other') then
    raise exception 'Forma de pagamento inválida.';
  end if;

  update public.monthly_tuition
  set
    payment_date = coalesce(target_payment_date, current_date),
    amount_paid = round(target_amount_paid, 2),
    payment_method = normalized_method,
    payment_notes = nullif(trim(coalesce(target_payment_notes, '')), ''),
    payment_provider = null,
    provider_payment_id = null,
    updated_at = now(),
    updated_by = auth.uid()
  where id = target_tuition_id;

  insert into public.monthly_tuition_events (tuition_id, action, actor_id, details)
  values (
    target_tuition_id,
    'payment_recorded',
    auth.uid(),
    jsonb_build_object(
      'payment_date', coalesce(target_payment_date, current_date),
      'amount_paid', round(target_amount_paid, 2),
      'payment_method', normalized_method,
      'payment_notes', nullif(trim(coalesce(target_payment_notes, '')), '')
    )
  );

  return jsonb_build_object('ok', true, 'tuition_id', target_tuition_id);
end;
$function$;


CREATE OR REPLACE FUNCTION public.reverse_tuition_payment(target_tuition_id uuid, target_reason text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  previous_payment jsonb;
begin
  if not coalesce(public.is_teacher_admin(), false) then
    raise exception 'Acesso negado: usuário não cadastrado como administrador.';
  end if;

  select jsonb_build_object(
    'payment_date', mt.payment_date,
    'amount_paid', mt.amount_paid,
    'payment_method', mt.payment_method,
    'payment_notes', mt.payment_notes,
    'payment_provider', mt.payment_provider,
    'provider_payment_id', mt.provider_payment_id
  )
  into previous_payment
  from public.monthly_tuition mt
  where mt.id = target_tuition_id
    and mt.payment_date is not null
  for update;

  if not found then
    raise exception 'Pagamento registrado não encontrado.';
  end if;

  update public.monthly_tuition
  set
    payment_date = null,
    amount_paid = null,
    payment_method = null,
    payment_notes = null,
    payment_provider = null,
    provider_payment_id = null,
    updated_at = now(),
    updated_by = auth.uid()
  where id = target_tuition_id;

  insert into public.monthly_tuition_events (tuition_id, action, actor_id, details)
  values (
    target_tuition_id,
    'payment_reversed',
    auth.uid(),
    previous_payment || jsonb_build_object(
      'reason', nullif(trim(coalesce(target_reason, '')), '')
    )
  );

  return jsonb_build_object('ok', true, 'tuition_id', target_tuition_id);
end;
$function$;


CREATE OR REPLACE FUNCTION public.sync_enrolled_auth_profile(target_user_id uuid, target_email text, target_metadata jsonb)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  normalized_metadata jsonb := coalesce(target_metadata, '{}'::jsonb);
  normalized_availability jsonb := '{}'::jsonb;
  authoritative_enrollment_code text;
  has_authoritative_enrollment boolean := false;
begin
  if target_user_id is null then
    return false;
  end if;

  if exists (
    select 1
    from public.teacher_admins ta
    where ta.user_id = target_user_id
       or lower(ta.email) = lower(coalesce(target_email, ''))
  ) then
    return false;
  end if;

  -- Existing database state is authoritative.
  select nullif(trim(p.enrollment_code), '')
    into authoritative_enrollment_code
  from public.profiles p
  where p.id = target_user_id
    and coalesce(p.enrolled, false) = true
    and coalesce(p.archived, false) = false
  limit 1;

  if found then
    has_authoritative_enrollment := true;
  end if;

  -- A completed enrollment invite is also authoritative. Email fallback is
  -- acceptable here because Supabase Auth has already verified the account email.
  if not has_authoritative_enrollment then
    select nullif(trim(sei.invite_code), '')
      into authoritative_enrollment_code
    from public.student_enrollment_invites sei
    where sei.status = 'completed'
      and (
        sei.user_id = target_user_id
        or (
          sei.user_id is null
          and coalesce(target_email, '') <> ''
          and lower(coalesce(sei.email, '')) = lower(target_email)
        )
      )
    order by sei.completed_at desc nulls last, sei.created_at desc
    limit 1;

    if found then
      has_authoritative_enrollment := true;
    end if;
  end if;

  if not has_authoritative_enrollment then
    return false;
  end if;

  if jsonb_typeof(normalized_metadata -> 'availability') = 'object' then
    normalized_availability := normalized_metadata -> 'availability';
  end if;

  insert into public.profiles (
    id, name, email, cpf, whatsapp, pix_key, availability,
    enrollment_code, enrolled
  ) values (
    target_user_id,
    nullif(trim(coalesce(normalized_metadata ->> 'name', '')), ''),
    nullif(trim(coalesce(target_email, '')), ''),
    nullif(trim(coalesce(normalized_metadata ->> 'cpf', '')), ''),
    nullif(trim(coalesce(normalized_metadata ->> 'whatsapp', '')), ''),
    nullif(trim(coalesce(normalized_metadata ->> 'pix_key', '')), ''),
    normalized_availability,
    authoritative_enrollment_code,
    true
  )
  on conflict (id) do update
  set
    name = coalesce(nullif(public.profiles.name, ''), excluded.name),
    email = coalesce(nullif(public.profiles.email, ''), excluded.email),
    cpf = coalesce(nullif(public.profiles.cpf, ''), excluded.cpf),
    whatsapp = coalesce(nullif(public.profiles.whatsapp, ''), excluded.whatsapp),
    pix_key = coalesce(nullif(public.profiles.pix_key, ''), excluded.pix_key),
    availability = case
      when public.profiles.availability is null
        or public.profiles.availability = '{}'::jsonb
      then excluded.availability
      else public.profiles.availability
    end,
    enrollment_code = coalesce(
      nullif(public.profiles.enrollment_code, ''),
      excluded.enrollment_code
    ),
    enrolled = true;

  return true;
end;
$function$;


CREATE OR REPLACE FUNCTION public.handle_enrolled_auth_user_profile()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  perform public.sync_enrolled_auth_profile(
    new.id,
    new.email,
    new.raw_user_meta_data
  );
  return new;
end;
$function$;


CREATE OR REPLACE FUNCTION public.queue_enrollment_email_notification()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  became_enrolled boolean := false;
begin
  if tg_op = 'INSERT' then
    became_enrolled := coalesce(new.enrolled, false);
  elsif tg_op = 'UPDATE' then
    became_enrolled :=
      coalesce(new.enrolled, false)
      and not coalesce(old.enrolled, false);
  end if;

  if became_enrolled and not exists (
    select 1
    from public.teacher_admins ta
    where ta.user_id = new.id
       or lower(ta.email) = lower(coalesce(new.email, ''))
  ) then
    insert into public.enrollment_email_notifications (student_id)
    values (new.id)
    on conflict (student_id) do nothing;
  end if;

  return new;
end;
$function$;


CREATE OR REPLACE FUNCTION public.book_makeup_class(target_slot_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth'
AS $function$
declare
  target_slot public.makeup_class_slots%rowtype;
  target_class_number integer;
  target_class_name text;
  target_meeting_url text;
  target_student_name text;
  target_student_email text;
  confirmed_count integer;
  existing_booking_id uuid;
  inserted_booking_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Faca login para agendar uma reposicao.';
  end if;

  select *
  into target_slot
  from public.makeup_class_slots s
  where s.id = target_slot_id
  for update;

  if target_slot.id is null then
    raise exception 'Horario nao encontrado.';
  end if;

  if not target_slot.is_active
    or target_slot.starts_at <= now()
  then
    raise exception 'Este horario nao esta mais disponivel.';
  end if;

  select b.id
  into existing_booking_id
  from public.makeup_class_bookings b
  where b.slot_id = target_slot.id
    and b.student_id = auth.uid()
    and b.status = 'confirmed'
  limit 1;

  if existing_booking_id is not null then
    return jsonb_build_object(
      'ok', true,
      'booking_id', existing_booking_id,
      'already_booked', true
    );
  end if;

  if target_slot.class_number is null
    or coalesce(trim(target_slot.class_name), '') = ''
  then
    raise exception 'Este horario nao possui uma turma definida. Escolha outro horario.';
  end if;

  if not exists (
    select 1
    from public.class_students cs
    join public.teacher_classes tc
      on tc.class_number = cs.class_number
     and tc.is_active = true
    where cs.user_id = auth.uid()
  ) then
    raise exception 'Voce ainda nao foi inscrito em uma turma pelo professor.';
  end if;

  if coalesce(trim(target_slot.meeting_url), '') !~* '^https?://' then
    raise exception 'O link da videoaula deste horario e invalido. Avise o professor.';
  end if;

  target_class_number := target_slot.class_number;
  target_class_name := target_slot.class_name;
  target_meeting_url := target_slot.meeting_url;

  select
    coalesce(
      nullif(trim(p.name), ''),
      nullif(trim(u.raw_user_meta_data ->> 'name'), ''),
      u.email,
      'Aluno'
    ),
    coalesce(
      nullif(trim(p.email), ''),
      u.email,
      ''
    )
  into
    target_student_name,
    target_student_email
  from auth.users u
  left join public.profiles p
    on p.id = u.id
  where u.id = auth.uid();

  if coalesce(target_student_email, '') = '' then
    raise exception 'Seu cadastro nao possui e-mail. Atualize o perfil antes de agendar.';
  end if;

  select count(*)::integer
  into confirmed_count
  from public.makeup_class_bookings b
  where b.slot_id = target_slot.id
    and b.status = 'confirmed';

  if confirmed_count >= target_slot.capacity then
    raise exception 'A ultima vaga deste horario acabou de ser reservada. Escolha outro horario.';
  end if;

  insert into public.makeup_class_bookings (
    slot_id,
    student_id,
    class_number,
    class_name,
    student_name,
    student_email,
    meeting_url
  )
  values (
    target_slot.id,
    auth.uid(),
    target_class_number,
    target_class_name,
    target_student_name,
    target_student_email,
    target_meeting_url
  )
  returning id into inserted_booking_id;

  insert into public.makeup_class_email_notifications (
    booking_id,
    notification_type
  )
  values (
    inserted_booking_id,
    'booking_confirmation'
  );

  return jsonb_build_object(
    'ok', true,
    'booking_id', inserted_booking_id,
    'email_queued', true
  );
end;
$function$;


CREATE OR REPLACE FUNCTION public.get_my_makeup_bookings()
 RETURNS TABLE(id text, slot_id text, starts_at timestamp with time zone, ends_at timestamp with time zone, status text, class_number integer, class_name text, meeting_url text, email_status text, booked_at timestamp with time zone)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if auth.uid() is null then
    raise exception 'Faca login para visualizar suas reposicoes.';
  end if;

  return query
  select
    b.id::text,
    b.slot_id::text,
    s.starts_at,
    s.ends_at,
    b.status,
    b.class_number,
    b.class_name,
    b.meeting_url,
    case
      when b.status = 'cancelled'
        and n.id is null
      then 'not_requested'
      else coalesce(n.status, 'pending')
    end::text as email_status,
    b.booked_at
  from public.makeup_class_bookings b
  join public.makeup_class_slots s
    on s.id = b.slot_id
  left join public.makeup_class_email_notifications n
    on n.booking_id = b.id
   and n.notification_type = case
     when b.status = 'cancelled'
       then 'cancellation'
     else 'booking_confirmation'
   end
  where b.student_id = auth.uid()
  order by
    case
      when s.starts_at >= now()
        and b.status = 'confirmed'
      then 0
      else 1
    end,
    case
      when s.starts_at >= now()
      then s.starts_at
    end asc,
    s.starts_at desc;
end;
$function$;


CREATE OR REPLACE FUNCTION public.get_teacher_makeup_bookings()
 RETURNS TABLE(id text, slot_id text, student_id text, student_name text, student_email text, class_number integer, class_name text, status text, email_status text, email_error text, booked_at timestamp with time zone)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not public.is_teacher_admin() then
    raise exception 'Acesso negado: usuario nao cadastrado como professor.';
  end if;

  return query
  select
    b.id::text,
    b.slot_id::text,
    b.student_id::text,
    b.student_name,
    b.student_email,
    b.class_number,
    b.class_name,
    b.status,
    coalesce(n.status, 'pending')::text,
    coalesce(n.last_error, '')::text,
    b.booked_at
  from public.makeup_class_bookings b
  left join public.makeup_class_email_notifications n
    on n.booking_id = b.id
   and n.notification_type = 'booking_confirmation'
  order by b.booked_at desc;
end;
$function$;


CREATE OR REPLACE FUNCTION public.cancel_makeup_class_slot(target_slot_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  cancelled_count integer;
begin
  if not public.is_teacher_admin() then
    raise exception 'Acesso negado: usuario nao cadastrado como professor.';
  end if;

  update public.makeup_class_slots
  set is_active = false
  where id = target_slot_id;

  if not found then
    raise exception 'Horario nao encontrado.';
  end if;

  update public.makeup_class_bookings
  set
    status = 'cancelled',
    cancelled_at = now()
  where slot_id = target_slot_id
    and status = 'confirmed';

  get diagnostics cancelled_count = row_count;

  return jsonb_build_object(
    'ok', true,
    'cancelled_bookings', cancelled_count
  );
end;
$function$;


CREATE OR REPLACE FUNCTION public.cancel_makeup_class_booking(target_booking_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not public.is_teacher_admin() then
    raise exception 'Acesso negado: usuario nao cadastrado como professor.';
  end if;

  update public.makeup_class_bookings
  set
    status = 'cancelled',
    cancelled_at = now()
  where id = target_booking_id
    and status = 'confirmed';

  if not found then
    raise exception 'Reserva confirmada nao encontrada.';
  end if;

  return jsonb_build_object(
    'ok', true
  );
end;
$function$;


CREATE OR REPLACE FUNCTION public.get_teacher_makeup_classes()
 RETURNS TABLE(class_number integer, class_name text, video_lesson_url text, student_count integer)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not public.is_teacher_admin() then
    raise exception 'Acesso negado: usuario nao cadastrado como professor.';
  end if;

  return query
  select
    tc.class_number,
    coalesce(
      nullif(trim(tc.class_name), ''),
      'Turma ' || tc.class_number
    )::text,
    coalesce(
      nullif(trim(cr.video_lesson_url), ''),
      ''
    )::text,
    count(cs.user_id)::integer
  from public.teacher_classes tc
  left join public.class_resources cr
    on cr.class_number = tc.class_number
  left join public.class_students cs
    on cs.class_number = tc.class_number
  where tc.is_active = true
  group by
    tc.class_number,
    tc.class_name,
    cr.video_lesson_url
  order by tc.class_number asc;
end;
$function$;


CREATE OR REPLACE FUNCTION public.create_makeup_class_slot(target_class_number integer, target_date date, target_start_time time without time zone, target_end_time time without time zone, target_capacity integer DEFAULT 1, target_notes text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  target_starts_at timestamptz;
  target_ends_at timestamptz;
  target_class_name text;
  target_meeting_url text;
  inserted_id uuid;
begin
  if not public.is_teacher_admin() then
    raise exception 'Acesso negado: usuario nao cadastrado como professor.';
  end if;

  if target_date is null
    or target_start_time is null
    or target_end_time is null
  then
    raise exception 'Informe a data, o inicio e o termino.';
  end if;

  if target_class_number is null then
    raise exception 'Escolha a turma deste horario.';
  end if;

  select
    coalesce(
      nullif(trim(tc.class_name), ''),
      'Turma ' || tc.class_number
    ),
    coalesce(
      nullif(trim(cr.video_lesson_url), ''),
      ''
    )
  into
    target_class_name,
    target_meeting_url
  from public.teacher_classes tc
  left join public.class_resources cr
    on cr.class_number = tc.class_number
  where tc.class_number = target_class_number
    and tc.is_active = true;

  if target_class_name is null then
    raise exception 'Turma nao encontrada ou inativa.';
  end if;

  if target_meeting_url = '' then
    raise exception 'Cadastre o link da videoaula desta turma antes de publicar o horario.';
  end if;

  if target_meeting_url !~* '^https?://' then
    raise exception 'O link da videoaula desta turma e invalido.';
  end if;

  if target_end_time <= target_start_time then
    raise exception 'O termino precisa ser depois do inicio.';
  end if;

  if target_capacity is null
    or target_capacity < 1
    or target_capacity > 50
  then
    raise exception 'A quantidade de vagas deve estar entre 1 e 50.';
  end if;

  target_starts_at :=
    (target_date + target_start_time)
    at time zone 'America/Sao_Paulo';

  target_ends_at :=
    (target_date + target_end_time)
    at time zone 'America/Sao_Paulo';

  if target_starts_at <= now() then
    raise exception 'Publique somente horarios futuros.';
  end if;

  insert into public.makeup_class_slots (
    class_number,
    class_name,
    meeting_url,
    starts_at,
    ends_at,
    capacity,
    notes,
    created_by
  )
  values (
    target_class_number,
    target_class_name,
    target_meeting_url,
    target_starts_at,
    target_ends_at,
    target_capacity,
    nullif(trim(target_notes), ''),
    auth.uid()
  )
  returning id into inserted_id;

  return jsonb_build_object(
    'ok', true,
    'id', inserted_id,
    'class_number', target_class_number,
    'class_name', target_class_name,
    'starts_at', target_starts_at,
    'ends_at', target_ends_at
  );
end;
$function$;


CREATE OR REPLACE FUNCTION public.get_available_makeup_slots()
 RETURNS TABLE(id text, class_number integer, class_name text, starts_at timestamp with time zone, ends_at timestamp with time zone, remaining_spots integer, notes text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if auth.uid() is null then
    raise exception 'Faca login para visualizar os horarios.';
  end if;

  if not exists (
    select 1
    from public.class_students cs
    join public.teacher_classes tc
      on tc.class_number = cs.class_number
     and tc.is_active = true
    where cs.user_id = auth.uid()
  ) then
    raise exception 'Voce ainda nao foi inscrito em uma turma pelo professor.';
  end if;

  return query
  select
    s.id::text,
    s.class_number,
    s.class_name,
    s.starts_at,
    s.ends_at,
    (s.capacity - count(b.id))::integer as remaining_spots,
    coalesce(s.notes, '')::text
  from public.makeup_class_slots s
  left join public.makeup_class_bookings b
    on b.slot_id = s.id
   and b.status = 'confirmed'
  where s.is_active = true
    and s.starts_at > now()
    and s.class_number is not null
    and coalesce(trim(s.meeting_url), '') ~* '^https?://'
  group by
    s.id,
    s.class_number,
    s.class_name,
    s.starts_at,
    s.ends_at,
    s.capacity,
    s.notes
  having count(b.id) < s.capacity
  order by s.starts_at asc;
end;
$function$;


CREATE OR REPLACE FUNCTION public.cancel_my_makeup_class_booking(target_booking_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  current_status text;
  target_starts_at timestamptz;
begin
  if auth.uid() is null then
    raise exception 'Faca login para cancelar uma reposicao.';
  end if;

  select
    b.status,
    s.starts_at
  into
    current_status,
    target_starts_at
  from public.makeup_class_bookings b
  join public.makeup_class_slots s
    on s.id = b.slot_id
  where b.id = target_booking_id
    and b.student_id = auth.uid()
  for update of b;

  if not found then
    raise exception 'Reserva nao encontrada ou nao pertence a este aluno.';
  end if;

  if current_status = 'cancelled' then
    return jsonb_build_object(
      'ok', true,
      'already_cancelled', true
    );
  end if;

  if current_status <> 'confirmed' then
    raise exception 'Somente reservas confirmadas podem ser canceladas.';
  end if;

  if target_starts_at <= now() then
    raise exception 'Nao e possivel cancelar uma reposicao que ja comecou.';
  end if;

  update public.makeup_class_bookings
  set
    status = 'cancelled',
    cancelled_at = now()
  where id = target_booking_id
    and student_id = auth.uid()
    and status = 'confirmed';

  insert into public.makeup_class_email_notifications (
    booking_id,
    notification_type
  )
  values (
    target_booking_id,
    'cancellation'
  )
  on conflict (booking_id, notification_type)
  do nothing;

  return jsonb_build_object(
    'ok', true,
    'booking_id', target_booking_id,
    'email_queued', true
  );
end;
$function$;


CREATE OR REPLACE FUNCTION public.get_teacher_makeup_slots()
 RETURNS TABLE(id text, class_number integer, class_name text, meeting_url text, starts_at timestamp with time zone, ends_at timestamp with time zone, capacity integer, notes text, is_active boolean, confirmed_bookings integer, created_at timestamp with time zone)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not public.is_teacher_admin() then
    raise exception 'Acesso negado: usuario nao cadastrado como professor.';
  end if;

  return query
  select
    s.id::text,
    s.class_number,
    coalesce(s.class_name, '')::text,
    coalesce(s.meeting_url, '')::text,
    s.starts_at,
    s.ends_at,
    s.capacity,
    coalesce(s.notes, '')::text,
    s.is_active,
    count(b.id)::integer as confirmed_bookings,
    s.created_at
  from public.makeup_class_slots s
  left join public.makeup_class_bookings b
    on b.slot_id = s.id
   and b.status = 'confirmed'
  group by
    s.id,
    s.class_number,
    s.class_name,
    s.meeting_url,
    s.starts_at,
    s.ends_at,
    s.capacity,
    s.notes,
    s.is_active,
    s.created_at
  order by
    case
      when s.starts_at >= now()
        and s.is_active
      then 0
      else 1
    end,
    case
      when s.starts_at >= now()
        and s.is_active
      then s.starts_at
    end asc,
    s.starts_at desc;
end;
$function$;


CREATE OR REPLACE FUNCTION public.log_student_page_access(target_page_path text, target_page_title text DEFAULT NULL::text, target_timezone text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth'
AS $function$
declare
  requester_id uuid;
  requester_email text;
  safe_page_path text;
  inserted_id uuid;
begin
  requester_id := auth.uid();
  requester_email := auth.jwt() ->> 'email';

  if requester_id is null then
    return jsonb_build_object('logged', false, 'reason', 'not_authenticated');
  end if;

  if exists (
    select 1
    from public.teacher_admins ta
    where lower(ta.email) = lower(coalesce(requester_email, ''))
       or ta.user_id = requester_id
  ) then
    return jsonb_build_object('logged', false, 'reason', 'teacher');
  end if;

  safe_page_path := split_part(
    split_part(coalesce(nullif(trim(target_page_path), ''), '/'), '?', 1),
    '#',
    1
  );
  safe_page_path := left(safe_page_path, 300);

  if left(safe_page_path, 1) <> '/' then
    safe_page_path := '/' || safe_page_path;
  end if;

  -- Limpeza automática da retenção de 90 dias.
  delete from public.student_access_logs sal
  where sal.accessed_at < now() - interval '90 days';

  insert into public.student_access_logs (
    user_id,
    page_path,
    page_title,
    timezone
  )
  values (
    requester_id,
    safe_page_path,
    left(nullif(trim(target_page_title), ''), 200),
    left(nullif(trim(target_timezone), ''), 100)
  )
  returning id into inserted_id;

  return jsonb_build_object(
    'logged', true,
    'access_id', inserted_id
  );
end;
$function$;


CREATE OR REPLACE FUNCTION public.get_teacher_student_accesses(target_days integer DEFAULT 30, target_user_id uuid DEFAULT NULL::uuid)
 RETURNS TABLE(log_id uuid, user_id uuid, student_name text, student_email text, accessed_at timestamp with time zone, page_path text, page_title text, timezone text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth'
AS $function$
declare
  requester_email text;
  safe_days integer;
  period_start timestamptz;
begin
  requester_email := auth.jwt() ->> 'email';

  if requester_email is null or not exists (
    select 1
    from public.teacher_admins ta
    where lower(ta.email) = lower(requester_email)
       or ta.user_id = auth.uid()
  ) then
    raise exception 'Acesso negado: usuário não cadastrado como professor.';
  end if;

  safe_days := greatest(1, least(coalesce(target_days, 30), 90));
  period_start := now() - (safe_days::text || ' days')::interval;

  return query
  select
    sal.id as log_id,
    sal.user_id,
    coalesce(
      nullif(trim(p.name), ''),
      nullif(trim(u.raw_user_meta_data ->> 'name'), ''),
      split_part(coalesce(u.email, 'Aluno'), '@', 1)
    )::text as student_name,
    coalesce(nullif(trim(p.email), ''), u.email, '')::text as student_email,
    sal.accessed_at,
    sal.page_path,
    sal.page_title,
    sal.timezone
  from public.student_access_logs sal
  join auth.users u on u.id = sal.user_id
  left join public.profiles p on p.id = sal.user_id
  where sal.accessed_at >= period_start
    and (target_user_id is null or sal.user_id = target_user_id)
    and not exists (
      select 1
      from public.teacher_admins ta
      where lower(ta.email) = lower(coalesce(u.email, ''))
         or ta.user_id = u.id
    )
  order by sal.accessed_at desc
  limit 2000;
end;
$function$;


CREATE OR REPLACE FUNCTION public.set_flashcards_updated_at()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
begin
  new.updated_at = now();
  return new;
end;
$function$;


CREATE OR REPLACE FUNCTION public.save_flashcard_deck(p_deck_id uuid, p_title text, p_description text, p_is_shared boolean, p_cards jsonb)
 RETURNS uuid
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  v_deck_id uuid;
  v_changed integer;
begin
  if (select auth.uid()) is null then
    raise exception 'Usuário não autenticado.';
  end if;

  if char_length(btrim(coalesce(p_title, ''))) not between 1 and 120 then
    raise exception 'O nome do conjunto deve ter entre 1 e 120 caracteres.';
  end if;

  if char_length(coalesce(p_description, '')) > 500 then
    raise exception 'A descrição deve ter no máximo 500 caracteres.';
  end if;

  if p_cards is null or jsonb_typeof(p_cards) <> 'array'
     or jsonb_array_length(p_cards) not between 1 and 200 then
    raise exception 'O conjunto deve ter entre 1 e 200 cartões.';
  end if;

  if exists (
    select 1
    from jsonb_array_elements(p_cards) as card(value)
    where char_length(btrim(coalesce(card.value ->> 'english_word', ''))) not between 1 and 180
       or char_length(btrim(coalesce(card.value ->> 'translation', ''))) not between 1 and 300
  ) then
    raise exception 'Todos os cartões precisam de uma palavra em inglês e uma tradução válidas.';
  end if;

  if p_deck_id is null then
    insert into public.flashcard_decks (owner_id, title, description, is_shared)
    values (
      (select auth.uid()),
      btrim(p_title),
      nullif(btrim(coalesce(p_description, '')), ''),
      coalesce(p_is_shared, false)
    )
    returning id into v_deck_id;
  else
    update public.flashcard_decks
    set title = btrim(p_title),
        description = nullif(btrim(coalesce(p_description, '')), ''),
        is_shared = coalesce(p_is_shared, false)
    where id = p_deck_id
      and owner_id = (select auth.uid())
    returning id into v_deck_id;

    get diagnostics v_changed = row_count;
    if v_changed <> 1 then
      raise exception 'Conjunto não encontrado ou acesso negado.';
    end if;

    delete from public.flashcards where deck_id = v_deck_id;
  end if;

  insert into public.flashcards (deck_id, english_word, translation, position)
  select
    v_deck_id,
    btrim(card.value ->> 'english_word'),
    btrim(card.value ->> 'translation'),
    (card.ordinality - 1)::integer
  from jsonb_array_elements(p_cards) with ordinality as card(value, ordinality);

  return v_deck_id;
end;
$function$;


CREATE OR REPLACE FUNCTION public.save_flashcard_deck(p_deck_id uuid, p_owner_id uuid, p_title text, p_description text, p_cards jsonb)
 RETURNS uuid
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  v_deck_id uuid;
  v_owner_id uuid;
  v_changed integer;
  v_is_teacher boolean;
  v_card record;
  v_card_id uuid;
  v_keep_ids uuid[] := array[]::uuid[];
begin
  if (select auth.uid()) is null then
    raise exception 'Usuário não autenticado.';
  end if;

  v_is_teacher := (select public.is_teacher_admin());

  if char_length(btrim(coalesce(p_title, ''))) not between 1 and 120 then
    raise exception 'O nome do conjunto deve ter entre 1 e 120 caracteres.';
  end if;

  if char_length(coalesce(p_description, '')) > 500 then
    raise exception 'A descrição deve ter no máximo 500 caracteres.';
  end if;

  if p_cards is null or jsonb_typeof(p_cards) <> 'array'
     or jsonb_array_length(p_cards) not between 1 and 200 then
    raise exception 'O conjunto deve ter entre 1 e 200 cartões.';
  end if;

  if exists (
    select 1
    from jsonb_array_elements(p_cards) as card(value)
    where char_length(btrim(coalesce(card.value ->> 'english_word', ''))) not between 1 and 180
       or char_length(btrim(coalesce(card.value ->> 'translation', ''))) not between 1 and 300
  ) then
    raise exception 'Todos os cartões precisam de uma palavra em inglês e uma tradução válidas.';
  end if;

  if p_deck_id is not null and exists (
    select 1
    from jsonb_array_elements(p_cards) as card(value)
    where nullif(card.value ->> 'id', '') is not null
    group by card.value ->> 'id'
    having count(*) > 1
  ) then
    raise exception 'Um mesmo cartão não pode aparecer duas vezes no conjunto.';
  end if;

  if p_deck_id is null then
    v_owner_id := coalesce(p_owner_id, (select auth.uid()));

    if v_owner_id <> (select auth.uid()) and not v_is_teacher then
      raise exception 'Somente o professor pode criar um conjunto para outro aluno.';
    end if;

    insert into public.flashcard_decks (owner_id, title, description)
    values (
      v_owner_id,
      btrim(p_title),
      nullif(btrim(coalesce(p_description, '')), '')
    )
    returning id into v_deck_id;
  else
    update public.flashcard_decks
    set title = btrim(p_title),
        description = nullif(btrim(coalesce(p_description, '')), '')
    where id = p_deck_id
      and (
        owner_id = (select auth.uid())
        or v_is_teacher
      )
    returning id, owner_id into v_deck_id, v_owner_id;

    get diagnostics v_changed = row_count;
    if v_changed <> 1 then
      raise exception 'Conjunto não encontrado ou acesso negado.';
    end if;

    if p_owner_id is not null and p_owner_id <> v_owner_id then
      raise exception 'O proprietário de um conjunto existente não pode ser alterado.';
    end if;

    update public.flashcards
    set position = position + 1000
    where deck_id = v_deck_id;
  end if;

  for v_card in
    select card.value, card.ordinality
    from jsonb_array_elements(p_cards) with ordinality as card(value, ordinality)
    order by card.ordinality
  loop
    v_card_id := null;

    if p_deck_id is not null and nullif(v_card.value ->> 'id', '') is not null then
      begin
        v_card_id := (v_card.value ->> 'id')::uuid;
      exception when invalid_text_representation then
        raise exception 'Identificador de cartão inválido.';
      end;
    end if;

    if v_card_id is not null then
      update public.flashcards
      set english_word = btrim(v_card.value ->> 'english_word'),
          translation = btrim(v_card.value ->> 'translation'),
          position = (v_card.ordinality - 1)::integer
      where id = v_card_id
        and deck_id = v_deck_id;

      get diagnostics v_changed = row_count;
      if v_changed <> 1 then
        raise exception 'Cartão não encontrado neste conjunto.';
      end if;
    else
      insert into public.flashcards (deck_id, english_word, translation, position)
      values (
        v_deck_id,
        btrim(v_card.value ->> 'english_word'),
        btrim(v_card.value ->> 'translation'),
        (v_card.ordinality - 1)::integer
      )
      returning id into v_card_id;
    end if;

    v_keep_ids := array_append(v_keep_ids, v_card_id);
  end loop;

  if p_deck_id is not null then
    delete from public.flashcards
    where deck_id = v_deck_id
      and not (id = any(v_keep_ids));
  end if;

  return v_deck_id;
end;
$function$;


CREATE OR REPLACE FUNCTION public.record_flashcard_practice_day()
 RETURNS date
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  v_practice_date date;
begin
  if (select auth.uid()) is null then
    raise exception 'Usuário não autenticado.';
  end if;

  v_practice_date := (now() at time zone 'America/Sao_Paulo')::date;

  insert into public.flashcard_practice_days (user_id, practice_date)
  values ((select auth.uid()), v_practice_date)
  on conflict (user_id, practice_date) do nothing;

  return v_practice_date;
end;
$function$;


CREATE OR REPLACE FUNCTION public.get_teacher_weekly_exercise_status()
 RETURNS TABLE(user_id text, student_name text, student_email text, enrollment_started_at timestamp with time zone, completed_exercises integer, credited_weeks integer, elapsed_weeks integer, overdue_weeks integer, current_week_number integer, current_week_start timestamp with time zone, current_week_due_at timestamp with time zone, current_week_completed boolean, last_completed_at timestamp with time zone, status text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  if not exists (
    select 1
    from public.teacher_admins ta
    where lower(ta.email) = lower(auth.jwt() ->> 'email')
  ) then
    raise exception 'Acesso negado: usuário não cadastrado como professor.';
  end if;

  return query
  with enrolled_students as (
    select
      u.id as student_user_id,
      coalesce(
        nullif(trim(p.name), ''),
        nullif(trim(u.raw_user_meta_data ->> 'name'), ''),
        u.email,
        'Aluno sem nome'
      )::text as resolved_name,
      coalesce(nullif(trim(p.email), ''), u.email, '')::text as resolved_email,
      coalesce(
        (
          select min(sei.completed_at)
          from public.student_enrollment_invites sei
          where sei.user_id = u.id
            and sei.status = 'completed'
            and sei.completed_at is not null
        ),
        p.created_at,
        u.created_at
      ) as enrollment_date
    from auth.users u
    left join public.profiles p on p.id = u.id
    where not exists (
      select 1
      from public.teacher_admins ta
      where lower(ta.email) = lower(coalesce(p.email, u.email, ''))
    )
      and (
        coalesce(p.enrolled, false) = true
        or coalesce(p.enrollment_code, '') <> ''
        or coalesce(lower(u.raw_user_meta_data ->> 'enrolled') in ('true', 't', '1', 'yes'), false)
        or coalesce(u.raw_user_meta_data ->> 'enrollment_code', '') <> ''
      )
  ),
  students_with_weeks as (
    select
      es.*,
      greatest(
        0,
        floor(extract(epoch from (now() - es.enrollment_date)) / 604800)
      )::integer as finished_week_count
    from enrolled_students es
    where es.enrollment_date is not null
  ),
  completion_buckets as (
    select
      sw.student_user_id,
      floor(
        extract(epoch from (dec.completed_at - sw.enrollment_date)) / 604800
      )::integer as week_index,
      dec.completed_at
    from students_with_weeks sw
    join public.daily_exercise_completion dec
      on dec.user_id = sw.student_user_id
     and dec.completed = true
     and dec.completed_at is not null
     and dec.completed_at >= sw.enrollment_date
  ),
  completion_stats as (
    select
      sw.student_user_id,
      count(cb.completed_at)::integer as exercise_count,
      count(distinct cb.week_index) filter (
        where cb.week_index >= 0
          and cb.week_index < sw.finished_week_count
      )::integer as finished_weeks_with_credit,
      coalesce(bool_or(cb.week_index = sw.finished_week_count), false) as active_week_completed,
      max(cb.completed_at) as most_recent_completion
    from students_with_weeks sw
    left join completion_buckets cb on cb.student_user_id = sw.student_user_id
    group by sw.student_user_id
  ),
  calculated as (
    select
      sw.student_user_id,
      sw.resolved_name,
      sw.resolved_email,
      sw.enrollment_date,
      coalesce(cs.exercise_count, 0) as exercise_count,
      coalesce(cs.finished_weeks_with_credit, 0) as finished_weeks_with_credit,
      sw.finished_week_count,
      greatest(sw.finished_week_count - coalesce(cs.finished_weeks_with_credit, 0), 0)::integer as missing_week_count,
      coalesce(cs.active_week_completed, false) as active_week_completed,
      cs.most_recent_completion
    from students_with_weeks sw
    left join completion_stats cs on cs.student_user_id = sw.student_user_id
  )
  select
    c.student_user_id::text as user_id,
    c.resolved_name::text as student_name,
    c.resolved_email::text as student_email,
    c.enrollment_date as enrollment_started_at,
    c.exercise_count::integer as completed_exercises,
    c.finished_weeks_with_credit::integer as credited_weeks,
    c.finished_week_count::integer as elapsed_weeks,
    c.missing_week_count::integer as overdue_weeks,
    (c.finished_week_count + 1)::integer as current_week_number,
    c.enrollment_date + (c.finished_week_count * interval '7 days') as current_week_start,
    c.enrollment_date + ((c.finished_week_count + 1) * interval '7 days') as current_week_due_at,
    c.active_week_completed::boolean as current_week_completed,
    c.most_recent_completion as last_completed_at,
    case
      when c.missing_week_count > 0 then 'late'
      when c.active_week_completed then 'up_to_date'
      else 'current_week_pending'
    end::text as status
  from calculated c
  order by
    case when c.missing_week_count > 0 then 0 when not c.active_week_completed then 1 else 2 end,
    c.missing_week_count desc,
    c.resolved_name asc,
    c.resolved_email asc;
end;
$function$;


CREATE OR REPLACE FUNCTION public.set_daily_exercise_completion_actor()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth'
AS $function$
begin
  if coalesce(auth.jwt() ->> 'role', '') = 'authenticated' then
    raise exception 'A conclusão de exercícios é registrada exclusivamente pelo monitoramento automático.';
  end if;

  if new.completed = false then
    new.completed_at = null;
  end if;

  new.updated_at = now();
  return new;
end;
$function$;


CREATE OR REPLACE FUNCTION public.get_teacher_student_exercise_completion(target_user_id uuid)
 RETURNS TABLE(exercise_id text, exercise_title text, exercise_url text, completed boolean, completed_at timestamp with time zone, completion_source text, completed_by_email text, updated_at timestamp with time zone)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth'
AS $function$
begin
  if not public.is_teacher_admin() then
    raise exception 'Acesso negado: usuário não cadastrado como professor.';
  end if;

  if not exists (
    select 1
    from auth.users u
    left join public.profiles p on p.id = u.id
    where u.id = target_user_id
      and not exists (
        select 1 from public.teacher_admins ta
        where lower(ta.email) = lower(coalesce(p.email, u.email, ''))
      )
      and (
        coalesce(p.enrolled, false) = true
        or coalesce(p.enrollment_code, '') <> ''
        or coalesce(lower(u.raw_user_meta_data ->> 'enrolled') in ('true', 't', '1', 'yes'), false)
        or coalesce(u.raw_user_meta_data ->> 'enrollment_code', '') <> ''
      )
  ) then
    raise exception 'Aluno matriculado não encontrado.';
  end if;

  return query
  select
    te.exercise_id,
    te.exercise_title,
    te.exercise_url,
    coalesce(dec.completed, false),
    dec.completed_at,
    coalesce(dec.completion_source, 'student')::text,
    coalesce(dec.completed_by_email, '')::text,
    dec.updated_at
  from public.teacher_exercises te
  left join public.daily_exercise_completion dec
    on dec.user_id = target_user_id
   and dec.exercise_id = te.exercise_id
  where te.is_active = true
    and (te.scheduled_publish_at is null or te.scheduled_publish_at <= now())
  order by coalesce(te.scheduled_publish_at, te.created_at) asc, te.created_at asc;
end;
$function$;


CREATE OR REPLACE FUNCTION public.set_teacher_student_exercise_completion(target_user_id uuid, target_exercise_id text, target_completed boolean, target_completed_at timestamp with time zone DEFAULT NULL::timestamp with time zone)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth'
AS $function$
declare
  target_title text;
  target_url text;
  actor_email text;
  effective_completed_at timestamptz;
begin
  if not public.is_teacher_admin() then
    raise exception 'Acesso negado: usuário não cadastrado como professor.';
  end if;

  if not exists (
    select 1
    from auth.users u
    left join public.profiles p on p.id = u.id
    where u.id = target_user_id
      and not exists (
        select 1 from public.teacher_admins ta
        where lower(ta.email) = lower(coalesce(p.email, u.email, ''))
      )
      and (
        coalesce(p.enrolled, false) = true
        or coalesce(p.enrollment_code, '') <> ''
        or coalesce(lower(u.raw_user_meta_data ->> 'enrolled') in ('true', 't', '1', 'yes'), false)
        or coalesce(u.raw_user_meta_data ->> 'enrollment_code', '') <> ''
      )
  ) then
    raise exception 'Aluno matriculado não encontrado.';
  end if;

  select te.exercise_title, te.exercise_url
  into target_title, target_url
  from public.teacher_exercises te
  where te.exercise_id = target_exercise_id
    and te.is_active = true
    and (te.scheduled_publish_at is null or te.scheduled_publish_at <= now());

  if target_title is null then
    raise exception 'Exercício publicado não encontrado.';
  end if;

  if target_completed then
    effective_completed_at := target_completed_at;
    if effective_completed_at is null then
      raise exception 'Informe a data em que o exercício foi feito.';
    end if;
    if effective_completed_at > now() + interval '5 minutes' then
      raise exception 'A data de conclusão não pode estar no futuro.';
    end if;
  else
    effective_completed_at := null;
  end if;

  actor_email := nullif(trim(auth.jwt() ->> 'email'), '');

  insert into public.daily_exercise_completion (
    user_id, exercise_id, exercise_title, exercise_url,
    completed, completed_at, completion_source,
    completed_by, completed_by_email, updated_at
  )
  values (
    target_user_id, target_exercise_id, target_title, target_url,
    target_completed, effective_completed_at, 'teacher',
    auth.uid(), actor_email, now()
  )
  on conflict (user_id, exercise_id)
  do update set
    exercise_title = excluded.exercise_title,
    exercise_url = excluded.exercise_url,
    completed = excluded.completed,
    completed_at = excluded.completed_at,
    completion_source = 'teacher',
    completed_by = auth.uid(),
    completed_by_email = actor_email,
    updated_at = now();

  return jsonb_build_object(
    'ok', true,
    'user_id', target_user_id,
    'exercise_id', target_exercise_id,
    'completed', target_completed,
    'completed_at', effective_completed_at,
    'completion_source', 'teacher'
  );
end;
$function$;


CREATE OR REPLACE FUNCTION public.set_exercise_schedule_start_date()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  if tg_op = 'INSERT' then
    if new.enrolled is true and new.exercise_schedule_start_date is null then
      new.exercise_schedule_start_date := (now() at time zone 'America/Sao_Paulo')::date;
    end if;
    return new;
  end if;

  if old.exercise_schedule_start_date is not null then
    new.exercise_schedule_start_date := old.exercise_schedule_start_date;
  elsif new.enrolled is true and coalesce(old.enrolled, false) is false then
    new.exercise_schedule_start_date := (now() at time zone 'America/Sao_Paulo')::date;
  end if;

  return new;
end;
$function$;


CREATE OR REPLACE FUNCTION public.archive_teacher_student(target_user_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth'
AS $function$
begin
  if not coalesce(public.is_teacher_admin(), false) then
    raise exception 'Acesso negado: usuário não cadastrado como professor.' using errcode = '42501';
  end if;

  update public.profiles
     set archived = true,
         archived_at = now()
   where id = target_user_id;

  if not found then
    insert into public.profiles (
      id, name, email, created_at, enrolled, availability, archived, archived_at
    )
    select
      u.id,
      coalesce(u.raw_user_meta_data ->> 'name', ''),
      u.email,
      u.created_at,
      coalesce((u.raw_user_meta_data ->> 'enrolled')::boolean, false),
      coalesce(u.raw_user_meta_data -> 'availability', '{}'::jsonb),
      true,
      now()
    from auth.users u
    where u.id = target_user_id;

    if not found then
      raise exception 'Aluno não encontrado.';
    end if;
  end if;
end;
$function$;


CREATE OR REPLACE FUNCTION public.unarchive_teacher_student(target_user_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not coalesce(public.is_teacher_admin(), false) then
    raise exception 'Acesso negado: usuário não cadastrado como professor.' using errcode = '42501';
  end if;

  update public.profiles
     set archived = false,
         archived_at = null
   where id = target_user_id
     and archived = true;

  if not found then
    raise exception 'Aluno arquivado não encontrado.';
  end if;
end;
$function$;


CREATE OR REPLACE FUNCTION public.ensure_weekly_plan_snapshot(target_user_id uuid)
 RETURNS TABLE(id uuid, user_id uuid, week_number integer, week_start date, week_end date, roadmap_target_lesson integer, created_at timestamp with time zone)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  caller_id uuid := auth.uid();
  schedule_start date;
  created_date date;
  local_today date := (now() at time zone 'America/Sao_Paulo')::date;
  computed_week integer;
  computed_start date;
  computed_end date;
  target_lesson integer;
begin
  if caller_id is null then
    raise exception 'Autenticação necessária.' using errcode = '42501';
  end if;

  if caller_id <> target_user_id and not coalesce(public.is_teacher_admin(), false) then
    raise exception 'Acesso negado.' using errcode = '42501';
  end if;

  select
    p.exercise_schedule_start_date,
    (p.created_at at time zone 'America/Sao_Paulo')::date
  into schedule_start, created_date
  from public.profiles p
  where p.id = target_user_id
    and coalesce(p.enrolled, false) = true
    and coalesce(p.archived, false) = false;

  if not found then
    raise exception 'Aluno ativo não encontrado.';
  end if;

  schedule_start := coalesce(
    schedule_start,
    case
      when created_date is null or created_date <= date '2026-07-30' then date '2026-07-30'
      else created_date
    end
  );

  computed_week := greatest(1, floor((local_today - schedule_start)::numeric / 7)::integer + 1);
  computed_start := schedule_start + ((computed_week - 1) * 7);
  computed_end := computed_start + 6;

  select min(gs.n)
    into target_lesson
  from generate_series(1, 24) as gs(n)
  where not exists (
    select 1
    from public.study_roadmap_completion src
    where src.user_id = target_user_id
      and src.lesson_number = gs.n
      and src.completed = true
  );

  insert into public.weekly_plan_snapshots (
    user_id, week_number, week_start, week_end, roadmap_target_lesson
  ) values (
    target_user_id, computed_week, computed_start, computed_end, target_lesson
  )
  on conflict on constraint weekly_plan_snapshots_user_week_key do nothing;

  return query
  select s.id, s.user_id, s.week_number, s.week_start, s.week_end,
         s.roadmap_target_lesson, s.created_at
  from public.weekly_plan_snapshots s
  where s.user_id = target_user_id
    and s.week_start = computed_start
  limit 1;
end;
$function$;


CREATE OR REPLACE FUNCTION public.set_my_weekly_task_completed(target_task_id uuid, target_completed boolean)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  caller_id uuid := auth.uid();
  task_owner uuid;
begin
  if caller_id is null then
    raise exception 'Autenticação necessária.' using errcode = '42501';
  end if;

  select t.user_id into task_owner
  from public.weekly_student_tasks t
  where t.id = target_task_id;

  if task_owner is null then
    raise exception 'Tarefa não encontrada.';
  end if;

  if caller_id <> task_owner and not coalesce(public.is_teacher_admin(), false) then
    raise exception 'Acesso negado.' using errcode = '42501';
  end if;

  update public.weekly_student_tasks
  set completed = coalesce(target_completed, false),
      completed_at = case when coalesce(target_completed, false) then coalesce(completed_at, now()) else null end,
      updated_at = now()
  where id = target_task_id;
end;
$function$;


CREATE OR REPLACE FUNCTION public.get_teacher_classes_with_type()
 RETURNS TABLE(id text, class_number integer, class_name text, class_type text, student_count integer, is_active boolean, created_at timestamp with time zone, updated_at timestamp with time zone)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not coalesce(public.is_teacher_admin(), false) then
    raise exception 'Acesso negado: usuário não cadastrado como professor.' using errcode = '42501';
  end if;

  return query
  select
    tc.id::text,
    tc.class_number,
    tc.class_name,
    tc.class_type,
    count(cs.id)::integer as student_count,
    tc.is_active,
    tc.created_at,
    tc.updated_at
  from public.teacher_classes tc
  left join public.class_students cs on cs.class_number = tc.class_number
  where tc.is_active = true
  group by tc.id, tc.class_number, tc.class_name, tc.class_type, tc.is_active, tc.created_at, tc.updated_at
  order by tc.class_number asc;
end;
$function$;


CREATE OR REPLACE FUNCTION public.create_teacher_class_with_type(target_class_name text, target_class_type text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  next_number integer;
  next_order integer;
  final_name text;
  normalized_type text;
  inserted_id uuid;
begin
  if not coalesce(public.is_teacher_admin(), false) then
    raise exception 'Acesso negado: usuário não cadastrado como professor.' using errcode = '42501';
  end if;

  normalized_type := lower(trim(coalesce(target_class_type, '')));
  if normalized_type not in ('quartet','individual','eight_students') then
    raise exception 'Tipo de turma inválido. Use quartet, individual ou eight_students.';
  end if;

  select coalesce(max(class_number), 0) + 1 into next_number from public.teacher_classes;
  select coalesce(max(display_order), 0) + 1 into next_order from public.teacher_classes where is_active = true;
  final_name := coalesce(nullif(trim(target_class_name), ''), 'Turma ' || next_number);

  insert into public.teacher_classes (class_number, class_name, class_type, display_order, is_active)
  values (next_number, final_name, normalized_type, next_order, true)
  returning id into inserted_id;

  return jsonb_build_object('ok', true,'id', inserted_id,'class_number', next_number,'class_name', final_name,'class_type', normalized_type);
end;
$function$;


CREATE OR REPLACE FUNCTION public.set_teacher_class_type(target_class_number integer, target_class_type text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  normalized_type text;
  updated_name text;
begin
  if not coalesce(public.is_teacher_admin(), false) then
    raise exception 'Acesso negado: usuário não cadastrado como professor.' using errcode = '42501';
  end if;

  normalized_type := lower(trim(coalesce(target_class_type, '')));
  if normalized_type not in ('quartet','individual','eight_students') then
    raise exception 'Tipo de turma inválido. Use quartet, individual ou eight_students.';
  end if;

  update public.teacher_classes
     set class_type = normalized_type,
         updated_at = now()
   where class_number = target_class_number
     and is_active = true
  returning class_name into updated_name;

  if not found then raise exception 'Turma não encontrada.'; end if;

  return jsonb_build_object('ok', true,'class_number', target_class_number,'class_name', updated_name,'class_type', normalized_type);
end;
$function$;


CREATE OR REPLACE FUNCTION public.get_group_classes_with_available_spots()
 RETURNS TABLE(class_number integer, class_name text, class_weekday smallint, class_start_time time without time zone, occupied_spots integer, available_spots integer)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  if not coalesce(public.is_teacher_admin(), false) then
    raise exception 'Acesso negado: usuário não cadastrado como professor.' using errcode = '42501';
  end if;

  return query
  with class_counts as (
    select tc.class_number, tc.class_name, tc.class_weekday, tc.class_start_time,
      case when tc.class_number in (48,73) then 5 else 4 end::integer as capacity_limit,
      count(cs.id) filter (
        where cs.invite_id is not null
           or (cs.user_id is not null and coalesce(p.enrolled,false)=true and coalesce(p.archived,false)=false)
      )::integer as occupied_spots
    from public.teacher_classes tc
    left join public.class_students cs on cs.class_number = tc.class_number
    left join public.profiles p on p.id = cs.user_id
    where tc.is_active = true and tc.class_type = 'quartet'
    group by tc.class_number, tc.class_name, tc.class_weekday, tc.class_start_time
  )
  select cc.class_number, cc.class_name, cc.class_weekday, cc.class_start_time,
         cc.occupied_spots, greatest(0, cc.capacity_limit - cc.occupied_spots)::integer
  from class_counts cc
  where cc.occupied_spots < cc.capacity_limit
  order by (cc.capacity_limit - cc.occupied_spots) desc, cc.class_name asc, cc.class_number asc;
end;
$function$;


CREATE OR REPLACE FUNCTION public.get_available_group_classes_for_students()
 RETURNS TABLE(class_number integer, class_name text, class_weekday smallint, class_start_time time without time zone, occupied_spots integer, available_spots integer)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  caller_id uuid := auth.uid();
  caller_class_type text;
  target_db_type text;
  base_capacity integer;
begin
  if caller_id is null then raise exception 'Autenticação necessária.' using errcode = '42501'; end if;

  select p.class_type into caller_class_type
  from public.profiles p
  where p.id = caller_id
    and coalesce(p.enrolled,false)=true
    and coalesce(p.archived,false)=false;

  if caller_class_type is null then
    raise exception 'Seu tipo de turma ainda não foi definido pelo professor.' using errcode = '42501';
  end if;

  target_db_type := case caller_class_type
    when 'INDIVIDUAL' then 'individual'
    when 'QUARTETO' then 'quartet'
    when '8 ALUNOS' then 'eight_students'
    else null end;
  base_capacity := case caller_class_type
    when 'INDIVIDUAL' then 1
    when 'QUARTETO' then 4
    when '8 ALUNOS' then 8
    else null end;

  if target_db_type is null or base_capacity is null then raise exception 'Tipo de turma inválido no perfil do aluno.'; end if;

  return query
  with class_counts as (
    select tc.class_number, tc.class_name, tc.class_weekday, tc.class_start_time,
      case when tc.class_number in (48,73) then 5 else base_capacity end::integer as capacity_limit,
      count(cs.id) filter (
        where cs.invite_id is not null
           or (cs.user_id is not null and coalesce(p.enrolled,false)=true and coalesce(p.archived,false)=false)
      )::integer as occupied_spots
    from public.teacher_classes tc
    left join public.class_students cs on cs.class_number = tc.class_number
    left join public.profiles p on p.id = cs.user_id
    where tc.is_active = true
      and tc.class_type = target_db_type
      and not exists (
        select 1 from public.class_students mine
        where mine.user_id = caller_id and mine.class_number = tc.class_number
      )
    group by tc.class_number, tc.class_name, tc.class_weekday, tc.class_start_time
  )
  select cc.class_number, cc.class_name, cc.class_weekday, cc.class_start_time,
         cc.occupied_spots, greatest(0, cc.capacity_limit - cc.occupied_spots)::integer
  from class_counts cc
  where cc.occupied_spots < cc.capacity_limit
  order by (cc.capacity_limit - cc.occupied_spots) desc, cc.class_name asc, cc.class_number asc;
end;
$function$;


CREATE OR REPLACE FUNCTION public.switch_my_group_class(target_class_number integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth', 'pg_temp'
AS $function$
declare
  caller_id uuid := auth.uid();
  old_class_number integer;
  occupied_count integer;
  caller_class_type text;
  target_db_type text;
  capacity integer;
begin
  if caller_id is null then raise exception 'Autenticação necessária.' using errcode = '42501'; end if;

  select p.class_type into caller_class_type
  from public.profiles p
  where p.id = caller_id
    and coalesce(p.enrolled,false)=true
    and coalesce(p.archived,false)=false;

  if caller_class_type is null then raise exception 'Seu tipo de turma ainda não foi definido pelo professor.' using errcode = '42501'; end if;

  target_db_type := case caller_class_type
    when 'INDIVIDUAL' then 'individual'
    when 'QUARTETO' then 'quartet'
    when '8 ALUNOS' then 'eight_students'
    else null end;
  capacity := case caller_class_type
    when 'INDIVIDUAL' then 1
    when 'QUARTETO' then 4
    when '8 ALUNOS' then 8
    else null end;

  if target_db_type is null or capacity is null then raise exception 'Tipo de turma inválido no perfil do aluno.'; end if;

  select cs.class_number into old_class_number
  from public.class_students cs where cs.user_id = caller_id limit 1;

  if old_class_number = target_class_number then
    return jsonb_build_object('ok',true,'changed',false,'old_class_number',old_class_number,'new_class_number',target_class_number);
  end if;

  perform 1 from public.teacher_classes tc
  where tc.class_number = target_class_number and tc.is_active = true and tc.class_type = target_db_type
  for update;
  if not found then raise exception 'Esta turma não é compatível com o seu tipo de turma.'; end if;

  if target_class_number in (48,73) then capacity := 5; end if;

  perform pg_advisory_xact_lock(73007, target_class_number);

  select count(*)::integer into occupied_count
  from public.class_students cs
  left join public.profiles p on p.id = cs.user_id
  where cs.class_number = target_class_number
    and (cs.invite_id is not null or (cs.user_id is not null and coalesce(p.enrolled,false)=true and coalesce(p.archived,false)=false));

  if occupied_count >= capacity then raise exception 'Esta turma não possui mais vagas.'; end if;

  delete from public.class_students where user_id = caller_id;
  insert into public.class_students (class_number,user_id,invite_id) values (target_class_number,caller_id,null);

  return jsonb_build_object('ok',true,'changed',true,'old_class_number',old_class_number,'new_class_number',target_class_number,'available_spots_after_change',capacity - occupied_count - 1);
end;
$function$;


CREATE OR REPLACE FUNCTION public.enforce_class_students_capacity()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  occupied_count integer;
  capacity_limit integer;
  new_occupies_spot boolean := false;
begin
  if new.class_number is null then
    return new;
  end if;

  capacity_limit := case when new.class_number in (48, 73) then 5 else 4 end;

  perform pg_advisory_xact_lock(73008, new.class_number);

  if new.invite_id is not null then
    new_occupies_spot := true;
  elsif new.user_id is not null then
    select exists (
      select 1 from public.profiles p
      where p.id = new.user_id
        and coalesce(p.enrolled, false) = true
        and coalesce(p.archived, false) = false
    ) into new_occupies_spot;
  end if;

  if not new_occupies_spot then return new; end if;

  select count(*)::integer into occupied_count
  from public.class_students cs
  left join public.profiles p on p.id = cs.user_id
  where cs.class_number = new.class_number
    and (tg_op <> 'UPDATE' or cs.id <> new.id)
    and (new.user_id is null or cs.user_id is distinct from new.user_id)
    and (new.invite_id is null or cs.invite_id is distinct from new.invite_id)
    and (
      cs.invite_id is not null
      or (cs.user_id is not null and coalesce(p.enrolled,false)=true and coalesce(p.archived,false)=false)
    );

  if occupied_count >= capacity_limit then
    raise exception 'Esta turma já atingiu o limite máximo de % alunos.', capacity_limit;
  end if;

  return new;
end;
$function$;


CREATE OR REPLACE FUNCTION public.sync_auto_makeup_slots_30_days()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  deleted_count integer := 0;
  inserted_count integer := 0;
begin
  delete from public.makeup_class_slots s
  where s.is_auto_generated = true
    and s.starts_at > now()
    and not exists (
      select 1
      from public.makeup_class_bookings b
      where b.slot_id = s.id
        and b.status = 'confirmed'
    );
  get diagnostics deleted_count = row_count;

  with student_counts as (
    select
      tc.class_number,
      count(cs.id) filter (
        where cs.invite_id is not null
           or (
             cs.user_id is not null
             and coalesce(p.enrolled, false) = true
             and coalesce(p.archived, false) = false
           )
      )::integer as student_count
    from public.teacher_classes tc
    left join public.class_students cs on cs.class_number = tc.class_number
    left join public.profiles p on p.id = cs.user_id
    where tc.is_active = true
    group by tc.class_number
  ), desired as (
    select
      tc.class_number,
      coalesce(nullif(trim(tc.class_name), ''), 'Turma ' || tc.class_number)::text as class_name,
      nullif(trim(cr.video_lesson_url), '')::text as meeting_url,
      d::date as class_date,
      ((d::date + tc.class_start_time) at time zone 'America/Sao_Paulo') as starts_at,
      (((d::date + tc.class_start_time) + interval '1 hour') at time zone 'America/Sao_Paulo') as ends_at,
      case sc.student_count
        when 4 then 1
        when 3 then 2
        when 2 then 3
        else 0
      end::integer as capacity
    from public.teacher_classes tc
    join student_counts sc on sc.class_number = tc.class_number
    left join public.class_resources cr on cr.class_number = tc.class_number
    cross join generate_series(
      (now() at time zone 'America/Sao_Paulo')::date,
      (now() at time zone 'America/Sao_Paulo')::date + 29,
      interval '1 day'
    ) as d
    where tc.is_active = true
      and coalesce(tc.makeup_slots_enabled, true) = true
      and tc.class_weekday between 1 and 7
      and tc.class_start_time is not null
      and extract(isodow from d)::integer = tc.class_weekday
      and sc.student_count in (2, 3, 4)
      and nullif(trim(cr.video_lesson_url), '') ~* '^https?://'
  )
  insert into public.makeup_class_slots (
    class_number, class_name, meeting_url, starts_at, ends_at,
    capacity, notes, is_active, created_by, is_auto_generated
  )
  select
    d.class_number, d.class_name, d.meeting_url, d.starts_at, d.ends_at,
    d.capacity, null, true, null, true
  from desired d
  where d.starts_at > now()
    and not exists (
      select 1
      from public.makeup_class_slots existing
      where existing.class_number = d.class_number
        and existing.starts_at = d.starts_at
        and existing.is_active = true
    );
  get diagnostics inserted_count = row_count;

  return jsonb_build_object(
    'ok', true,
    'window_days', 30,
    'deleted_unbooked_auto_slots', deleted_count,
    'inserted_auto_slots', inserted_count,
    'generated_at', now()
  );
end;
$function$;


CREATE OR REPLACE FUNCTION public.enforce_makeup_slots_enabled()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  if new.class_number is not null
     and exists (
       select 1
       from public.teacher_classes tc
       where tc.class_number = new.class_number
         and coalesce(tc.makeup_slots_enabled, true) = false
     ) then
    raise exception 'Esta turma não permite horários de reposição.';
  end if;
  return new;
end;
$function$;


CREATE OR REPLACE FUNCTION public.get_google_form_integrations()
 RETURNS TABLE(id uuid, exercise_id text, exercise_title text, spreadsheet_id text, spreadsheet_url text, import_existing boolean, status text, trigger_created_at timestamp with time zone, historical_sync_at timestamp with time zone, historical_processed integer, historical_unmatched integer, last_error text, created_at timestamp with time zone, updated_at timestamp with time zone)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth'
AS $function$
begin
  if not public.is_teacher_admin() then
    raise exception 'Acesso restrito ao professor';
  end if;

  return query
  select
    s.id,
    s.exercise_id,
    e.exercise_title,
    s.spreadsheet_id,
    s.spreadsheet_url,
    s.import_existing,
    s.status,
    s.trigger_created_at,
    s.historical_sync_at,
    s.historical_processed,
    s.historical_unmatched,
    s.last_error,
    s.created_at,
    s.updated_at
  from public.exercise_form_sources s
  join public.teacher_exercises e on e.exercise_id = s.exercise_id
  order by s.created_at desc;
end;
$function$;


CREATE OR REPLACE FUNCTION public.upsert_google_form_integration(target_exercise_id text, target_spreadsheet_url text, target_import_existing boolean DEFAULT true)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth'
AS $function$
declare
  normalized_url text := trim(coalesce(target_spreadsheet_url, ''));
  parsed_spreadsheet_id text;
  result_id uuid;
  conflicting_exercise text;
begin
  if not public.is_teacher_admin() then
    raise exception 'Acesso restrito ao professor';
  end if;

  if not exists (
    select 1 from public.teacher_exercises
    where exercise_id = trim(coalesce(target_exercise_id, ''))
  ) then
    raise exception 'Exercício não encontrado';
  end if;

  parsed_spreadsheet_id := substring(
    normalized_url from 'docs\.google\.com/spreadsheets/d/([A-Za-z0-9_-]+)'
  );

  if parsed_spreadsheet_id is null or parsed_spreadsheet_id = '' then
    raise exception 'URL de planilha do Google Sheets inválida';
  end if;

  select exercise_id into conflicting_exercise
  from public.exercise_form_sources
  where spreadsheet_id = parsed_spreadsheet_id
    and exercise_id <> trim(target_exercise_id)
  limit 1;

  if conflicting_exercise is not null then
    raise exception 'Esta planilha já está vinculada a outro exercício';
  end if;

  insert into public.exercise_form_sources (
    exercise_id,
    spreadsheet_id,
    spreadsheet_url,
    import_existing,
    status,
    created_by,
    last_error,
    updated_at
  )
  values (
    trim(target_exercise_id),
    parsed_spreadsheet_id,
    normalized_url,
    coalesce(target_import_existing, true),
    'pending',
    auth.uid(),
    null,
    now()
  )
  on conflict (exercise_id) do update set
    spreadsheet_id = excluded.spreadsheet_id,
    spreadsheet_url = excluded.spreadsheet_url,
    import_existing = excluded.import_existing,
    status = 'pending',
    created_by = auth.uid(),
    last_error = null,
    historical_processed = 0,
    historical_unmatched = 0,
    historical_sync_at = null,
    trigger_created_at = null,
    updated_at = now()
  returning id into result_id;

  return result_id;
end;
$function$;


CREATE OR REPLACE FUNCTION public.retry_google_form_integration(target_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth'
AS $function$
begin
  if not public.is_teacher_admin() then
    raise exception 'Acesso restrito ao professor';
  end if;

  update public.exercise_form_sources
  set status = 'pending',
      last_error = null,
      updated_at = now()
  where id = target_id;

  if not found then
    raise exception 'Integração não encontrada';
  end if;
end;
$function$;


CREATE OR REPLACE FUNCTION public.disconnect_google_form_integration(target_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth'
AS $function$
begin
  if not public.is_teacher_admin() then
    raise exception 'Acesso restrito ao professor';
  end if;

  update public.exercise_form_sources
  set status = 'disconnect_requested',
      last_error = null,
      updated_at = now()
  where id = target_id;

  if not found then
    raise exception 'Integração não encontrada';
  end if;
end;
$function$;


CREATE OR REPLACE FUNCTION public.set_tuition_payment_attempt_updated_at()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
begin
  new.updated_at := now();
  return new;
end;
$function$;


CREATE OR REPLACE FUNCTION public.get_my_pending_tuitions()
 RETURNS TABLE(tuition_id uuid, reference_month date, due_date date, amount_due numeric, payment_status text, attempt_id uuid, provider_payment_id text, attempt_status text, attempt_status_detail text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  current_user_id uuid := auth.uid();
begin
  if current_user_id is null then
    raise exception 'É necessário entrar na conta para consultar mensalidades.';
  end if;

  return query
  select
    mt.id,
    mt.reference_month,
    mt.due_date,
    mt.amount_due,
    case
      when mt.due_date < current_date then 'overdue'
      when mt.due_date = current_date then 'due_today'
      when mt.due_date = current_date + 1 then 'due_tomorrow'
      when mt.due_date = current_date + 2 then 'due_in_two_days'
      when mt.due_date <= current_date + 7 then 'due_soon'
      else 'open'
    end::text,
    latest_attempt.id,
    latest_attempt.provider_payment_id,
    latest_attempt.status,
    latest_attempt.status_detail
  from public.monthly_tuition mt
  left join lateral (
    select
      attempt.id,
      attempt.provider_payment_id,
      attempt.status,
      attempt.status_detail
    from public.tuition_payment_attempts attempt
    where attempt.tuition_id = mt.id
      and attempt.student_id = current_user_id
    order by attempt.created_at desc
    limit 1
  ) latest_attempt on true
  where mt.student_id = current_user_id
    and mt.payment_date is null
    and mt.reference_month <= date_trunc('month', current_date)::date
  order by mt.due_date asc, mt.reference_month asc;
end;
$function$;


CREATE OR REPLACE FUNCTION public.process_mercado_pago_payment(target_attempt_id uuid, target_provider_payment_id text, target_status text, target_status_detail text, target_amount numeric, target_payment_method text, target_live_mode boolean, target_provider_created_at timestamp with time zone, target_provider_updated_at timestamp with time zone, target_approved_at timestamp with time zone)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  attempt_row public.tuition_payment_attempts%rowtype;
  tuition_row public.monthly_tuition%rowtype;
  normalized_status text := lower(trim(coalesce(target_status, '')));
  normalized_method text := lower(trim(coalesce(target_payment_method, '')));
  normalized_provider_payment_id text := trim(coalesce(target_provider_payment_id, ''));
  affected_count integer := 0;
  payment_was_applied boolean := false;
  payment_was_reversed boolean := false;
begin
  if normalized_provider_payment_id = '' or length(normalized_provider_payment_id) > 128 then
    raise exception 'Identificador de pagamento inválido.';
  end if;

  if normalized_status not in (
    'created', 'pending', 'approved', 'authorized', 'in_process',
    'in_mediation', 'rejected', 'cancelled', 'refunded', 'charged_back'
  ) then
    raise exception 'Status de pagamento inválido.';
  end if;

  if normalized_method not in ('pix', 'card') then
    raise exception 'Forma de pagamento inválida.';
  end if;

  select *
  into attempt_row
  from public.tuition_payment_attempts attempt
  where attempt.id = target_attempt_id
  for update;

  if not found then
    raise exception 'Tentativa de pagamento não encontrada.';
  end if;

  select *
  into tuition_row
  from public.monthly_tuition tuition
  where tuition.id = attempt_row.tuition_id
    and tuition.student_id = attempt_row.student_id
  for update;

  if not found then
    raise exception 'Mensalidade vinculada não encontrada.';
  end if;

  if round(target_amount, 2) is distinct from round(attempt_row.amount, 2)
     or round(target_amount, 2) is distinct from round(tuition_row.amount_due, 2) then
    raise exception 'O valor confirmado não corresponde à mensalidade.';
  end if;

  if attempt_row.provider_payment_id is not null
     and attempt_row.provider_payment_id <> normalized_provider_payment_id then
    raise exception 'A tentativa já está vinculada a outro pagamento.';
  end if;

  update public.tuition_payment_attempts
  set
    provider_payment_id = normalized_provider_payment_id,
    status = normalized_status,
    status_detail = nullif(trim(coalesce(target_status_detail, '')), ''),
    payment_method = normalized_method,
    live_mode = target_live_mode,
    provider_created_at = coalesce(provider_created_at, target_provider_created_at),
    provider_updated_at = coalesce(target_provider_updated_at, now())
  where id = attempt_row.id;

  if normalized_status = 'approved' then
    update public.monthly_tuition
    set
      payment_date = coalesce(target_approved_at::date, current_date),
      amount_paid = round(target_amount, 2),
      payment_method = normalized_method,
      payment_notes = 'Mercado Pago · pagamento ' || normalized_provider_payment_id,
      payment_provider = 'mercado_pago',
      provider_payment_id = normalized_provider_payment_id,
      updated_at = now(),
      updated_by = null
    where id = tuition_row.id
      and payment_date is null;

    get diagnostics affected_count = row_count;
    payment_was_applied := affected_count > 0;

    if payment_was_applied then
      insert into public.monthly_tuition_events (tuition_id, action, actor_id, details)
      values (
        tuition_row.id,
        'payment_recorded',
        null,
        jsonb_build_object(
          'source', 'mercado_pago',
          'attempt_id', attempt_row.id,
          'provider_payment_id', normalized_provider_payment_id,
          'amount_paid', round(target_amount, 2),
          'payment_method', normalized_method,
          'status_detail', nullif(trim(coalesce(target_status_detail, '')), '')
        )
      );
    end if;

    if payment_was_applied
       or (
         tuition_row.payment_provider = 'mercado_pago'
         and tuition_row.provider_payment_id = normalized_provider_payment_id
       ) then
      update public.tuition_payment_attempts
      set applied_at = coalesce(applied_at, coalesce(target_approved_at, now()))
      where id = attempt_row.id;
    end if;
  elsif normalized_status in ('cancelled', 'refunded', 'charged_back')
        and attempt_row.applied_at is not null
        and attempt_row.reversed_at is null then
    update public.monthly_tuition
    set
      payment_date = null,
      amount_paid = null,
      payment_method = null,
      payment_notes = null,
      payment_provider = null,
      provider_payment_id = null,
      updated_at = now(),
      updated_by = null
    where id = tuition_row.id
      and payment_provider = 'mercado_pago'
      and provider_payment_id = normalized_provider_payment_id;

    get diagnostics affected_count = row_count;
    payment_was_reversed := affected_count > 0;

    if payment_was_reversed then
      insert into public.monthly_tuition_events (tuition_id, action, actor_id, details)
      values (
        tuition_row.id,
        'payment_reversed',
        null,
        jsonb_build_object(
          'source', 'mercado_pago',
          'attempt_id', attempt_row.id,
          'provider_payment_id', normalized_provider_payment_id,
          'provider_status', normalized_status,
          'status_detail', nullif(trim(coalesce(target_status_detail, '')), '')
        )
      );

      update public.tuition_payment_attempts
      set reversed_at = coalesce(reversed_at, now())
      where id = attempt_row.id;
    end if;
  end if;

  return jsonb_build_object(
    'ok', true,
    'tuition_id', tuition_row.id,
    'attempt_id', attempt_row.id,
    'status', normalized_status,
    'payment_applied', payment_was_applied,
    'payment_reversed', payment_was_reversed
  );
end;
$function$;


CREATE OR REPLACE FUNCTION public.get_student_login_route_internal(target_email text)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth'
AS $function$
declare
  normalized_email text;
begin
  normalized_email := lower(trim(coalesce(target_email, '')));

  if normalized_email = '' or length(normalized_email) > 320 then
    return 'google_only';
  end if;

  if exists (
    select 1
    from auth.users u
    left join public.profiles p on p.id = u.id
    where lower(coalesce(u.email, '')) = normalized_email
      and coalesce(p.enrolled, lower(coalesce(u.raw_user_meta_data ->> 'enrolled', 'false')) = 'true', false) = true
      and not exists (
        select 1
        from public.teacher_admins ta
        where ta.user_id = u.id
           or lower(ta.email) = normalized_email
      )
      and exists (
        select 1
        from auth.identities i
        where i.user_id = u.id
          and i.provider = 'google'
      )
  ) then
    return 'google_only';
  end if;

  if exists (
    select 1
    from auth.users u
    left join public.profiles p on p.id = u.id
    where lower(coalesce(u.email, '')) = normalized_email
      and coalesce(p.enrolled, lower(coalesce(u.raw_user_meta_data ->> 'enrolled', 'false')) = 'true', false) = true
      and p.first_portal_access_at is not null
      and not exists (
        select 1
        from public.teacher_admins ta
        where ta.user_id = u.id
           or lower(ta.email) = normalized_email
      )
  ) then
    return 'password_allowed';
  end if;

  return 'google_only';
end;
$function$;


CREATE OR REPLACE FUNCTION public.get_teacher_student_access_statuses()
 RETURNS TABLE(user_id uuid, student_name text, student_email text, has_accessed boolean, first_access_at timestamp with time zone, last_access_at timestamp with time zone)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth'
AS $function$
declare
  requester_email text;
begin
  requester_email := auth.jwt() ->> 'email';

  if requester_email is null or not exists (
    select 1
    from public.teacher_admins ta
    where lower(ta.email) = lower(requester_email)
       or ta.user_id = auth.uid()
  ) then
    raise exception 'Acesso negado: usuário não cadastrado como professor.';
  end if;

  return query
  select
    u.id as user_id,
    coalesce(
      nullif(trim(p.name), ''),
      nullif(trim(u.raw_user_meta_data ->> 'name'), ''),
      split_part(coalesce(u.email, 'Aluno'), '@', 1)
    )::text as student_name,
    coalesce(nullif(trim(p.email), ''), u.email, '')::text as student_email,
    (p.first_portal_access_at is not null) as has_accessed,
    p.first_portal_access_at as first_access_at,
    p.last_portal_access_at as last_access_at
  from auth.users u
  left join public.profiles p on p.id = u.id
  where coalesce(p.enrolled, lower(coalesce(u.raw_user_meta_data ->> 'enrolled', 'false')) = 'true', false) = true
    and not exists (
      select 1
      from public.teacher_admins ta
      where ta.user_id = u.id
         or lower(ta.email) = lower(coalesce(u.email, ''))
    )
  order by (p.first_portal_access_at is not null) asc,
           student_name asc;
end;
$function$;


CREATE OR REPLACE FUNCTION public.sync_student_portal_access_status()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  update public.profiles
  set first_portal_access_at = coalesce(first_portal_access_at, new.accessed_at),
      last_portal_access_at = greatest(coalesce(last_portal_access_at, new.accessed_at), new.accessed_at)
  where id = new.user_id;
  return new;
end;
$function$;


CREATE OR REPLACE FUNCTION public.delete_teacher_class_lesson_record(target_record_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth'
AS $function$
declare
  deleted_row public.class_lesson_records%rowtype;
begin
  if not public.is_teacher_admin() then
    raise exception 'Acesso negado: usuário não cadastrado como professor.';
  end if;

  delete from public.class_lesson_records
  where id = target_record_id
  returning * into deleted_row;

  if deleted_row.id is null then
    raise exception 'Registro de lição não encontrado.';
  end if;

  return jsonb_build_object(
    'ok', true,
    'id', deleted_row.id,
    'class_number', deleted_row.class_number,
    'class_date', deleted_row.class_date,
    'lesson_code', deleted_row.lesson_code
  );
end;
$function$;


CREATE OR REPLACE FUNCTION public.get_student_google_link_candidate_internal(target_google_user_id uuid, target_google_email text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  normalized_google_email text := lower(btrim(coalesce(target_google_email, '')));
  matched_profile public.profiles%rowtype;
  matched_mode text;
begin
  if target_google_user_id is null or normalized_google_email = '' then
    return jsonb_build_object('show_prompt', false, 'reason', 'invalid_user');
  end if;

  if exists (
    select 1 from public.student_google_account_links l
    where l.google_user_id = target_google_user_id
  ) then
    return jsonb_build_object('show_prompt', false, 'reason', 'already_confirmed');
  end if;

  select p.* into matched_profile
  from public.profiles p
  where p.id = target_google_user_id
    and p.enrolled = true
    and coalesce(p.archived, false) = false
    and not exists (select 1 from public.teacher_admins ta where ta.user_id = p.id)
  limit 1;

  if found then
    matched_mode := 'automatic';
  else
    select p.* into matched_profile
    from public.student_google_email_aliases a
    join public.profiles p on lower(btrim(coalesce(p.email, ''))) = a.enrollment_email
    where a.google_email = normalized_google_email
      and a.active = true
      and p.enrolled = true
      and coalesce(p.archived, false) = false
      and not exists (select 1 from public.teacher_admins ta where ta.user_id = p.id)
      and not exists (
        select 1 from public.student_google_account_links l
        where l.legacy_user_id = p.id
      )
    limit 1;

    if found then matched_mode := 'alias'; end if;
  end if;

  if matched_profile.id is null then
    return jsonb_build_object('show_prompt', false, 'reason', 'no_match');
  end if;

  return jsonb_build_object(
    'show_prompt', true,
    'mode', matched_mode,
    'legacy_user_id', matched_profile.id,
    'enrollment_email', lower(btrim(coalesce(matched_profile.email, ''))),
    'student_name', coalesce(matched_profile.name, '')
  );
end;
$function$;


CREATE OR REPLACE FUNCTION public.confirm_or_migrate_student_google_link_internal(target_google_user_id uuid, target_legacy_user_id uuid, target_google_email text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  normalized_google_email text := lower(btrim(coalesce(target_google_email, '')));
  source_profile public.profiles%rowtype;
  target_profile public.profiles%rowtype;
  ref record;
  mode_value text;
begin
  if target_google_user_id is null or target_legacy_user_id is null or normalized_google_email = '' then
    raise exception 'Dados de vinculação inválidos.';
  end if;

  select p.* into source_profile
  from public.profiles p
  where p.id = target_legacy_user_id
    and p.enrolled = true
    and coalesce(p.archived, false) = false
  for update;

  if source_profile.id is null then
    raise exception 'Matrícula não encontrada ou inativa.';
  end if;

  if exists (select 1 from public.teacher_admins ta where ta.user_id = target_legacy_user_id) then
    raise exception 'Conta administrativa não pode ser migrada por este fluxo.';
  end if;

  if target_google_user_id = target_legacy_user_id then
    mode_value := 'automatic';

    insert into public.student_google_account_links (
      google_user_id, legacy_user_id, enrollment_email, google_email, link_mode, confirmed_at, updated_at
    ) values (
      target_google_user_id,
      target_legacy_user_id,
      lower(btrim(coalesce(source_profile.email, ''))),
      normalized_google_email,
      mode_value,
      now(),
      now()
    )
    on conflict (google_user_id) do update
    set enrollment_email = excluded.enrollment_email,
        google_email = excluded.google_email,
        link_mode = excluded.link_mode,
        confirmed_at = now(),
        updated_at = now();

    return jsonb_build_object('linked', true, 'mode', mode_value, 'legacy_user_id', target_legacy_user_id);
  end if;

  if not exists (
    select 1
    from public.student_google_email_aliases a
    where a.google_email = normalized_google_email
      and a.enrollment_email = lower(btrim(coalesce(source_profile.email, '')))
      and a.active = true
  ) then
    raise exception 'Este e-mail Google não possui alias autorizado para a matrícula encontrada.';
  end if;

  if exists (
    select 1 from public.student_google_account_links l
    where l.legacy_user_id = target_legacy_user_id
       or l.google_user_id = target_google_user_id
  ) then
    raise exception 'Esta matrícula ou conta Google já foi vinculada.';
  end if;

  select p.* into target_profile
  from public.profiles p
  where p.id = target_google_user_id
  for update;

  if target_profile.id is not null and target_profile.enrolled = true then
    raise exception 'A conta Google já possui outra matrícula ativa.';
  end if;

  delete from public.profiles
  where id = target_google_user_id
    and enrolled = false;

  -- O código de matrícula é único. Liberamos temporariamente o valor na linha
  -- legada, mantendo o valor original em source_profile. Se qualquer etapa
  -- posterior falhar, a transação inteira é revertida automaticamente.
  update public.profiles
  set enrollment_code = null
  where id = target_legacy_user_id;

  insert into public.profiles
  select (jsonb_populate_record(
    null::public.profiles,
    to_jsonb(source_profile) || jsonb_build_object('id', target_google_user_id)
  )).*;

  for ref in
    select ns.nspname as schema_name, cls.relname as table_name, att.attname as column_name
    from pg_constraint c
    join pg_class cls on cls.oid = c.conrelid
    join pg_namespace ns on ns.oid = cls.relnamespace
    join lateral unnest(c.conkey) with ordinality ck(attnum, ord) on true
    join pg_attribute att on att.attrelid = c.conrelid and att.attnum = ck.attnum
    where c.contype = 'f'
      and c.confrelid = 'public.profiles'::regclass
      and ns.nspname = 'public'
      and cls.relname <> 'profiles'
  loop
    execute format('update %I.%I set %I = $1 where %I = $2', ref.schema_name, ref.table_name, ref.column_name, ref.column_name)
      using target_google_user_id, target_legacy_user_id;
  end loop;

  for ref in
    select ns.nspname as schema_name, cls.relname as table_name, att.attname as column_name
    from pg_constraint c
    join pg_class cls on cls.oid = c.conrelid
    join pg_namespace ns on ns.oid = cls.relnamespace
    join lateral unnest(c.conkey) with ordinality ck(attnum, ord) on true
    join pg_attribute att on att.attrelid = c.conrelid and att.attnum = ck.attnum
    where c.contype = 'f'
      and c.confrelid = 'auth.users'::regclass
      and ns.nspname = 'public'
      and cls.relname not in ('profiles', 'teacher_admins')
  loop
    execute format('update %I.%I set %I = $1 where %I = $2', ref.schema_name, ref.table_name, ref.column_name, ref.column_name)
      using target_google_user_id, target_legacy_user_id;
  end loop;

  delete from public.profiles where id = target_legacy_user_id;

  mode_value := 'alias';
  insert into public.student_google_account_links (
    google_user_id, legacy_user_id, enrollment_email, google_email, link_mode, confirmed_at, updated_at
  ) values (
    target_google_user_id,
    target_legacy_user_id,
    lower(btrim(coalesce(source_profile.email, ''))),
    normalized_google_email,
    mode_value,
    now(),
    now()
  );

  return jsonb_build_object('linked', true, 'mode', mode_value, 'legacy_user_id', target_legacy_user_id);
end;
$function$;


CREATE OR REPLACE FUNCTION public.preserve_linked_student_enrollment_email()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
begin
  if old.enrolled = true
     and new.email is distinct from old.email
     and exists (
       select 1 from public.student_google_account_links l
       where l.google_user_id = old.id
     ) then
    new.email := old.email;
  end if;
  return new;
end;
$function$;


CREATE OR REPLACE FUNCTION public.normalize_profile_enrollment_code()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
begin
  if new.enrollment_code is not null then
    new.enrollment_code := nullif(btrim(new.enrollment_code), '');
  end if;
  return new;
end;
$function$;


CREATE OR REPLACE FUNCTION public.activate_completed_google_student_profile()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth'
AS $function$
declare
  provider_name text;
  candidate_code text;
begin
  select u.raw_app_meta_data ->> 'provider'
    into provider_name
  from auth.users u
  where u.id = new.id;

  if coalesce(new.profile_completed, false) = true
     and coalesce(new.enrolled, false) = false
     and provider_name = 'google'
     and not exists (
       select 1
       from public.teacher_admins ta
       where ta.user_id = new.id
          or lower(ta.email) = lower(coalesce(new.email, ''))
     ) then
    new.enrolled := true;

    if nullif(btrim(new.enrollment_code), '') is null then
      loop
        candidate_code := upper(substr(md5(gen_random_uuid()::text || clock_timestamp()::text), 1, 5));
        exit when not exists (
          select 1
          from public.profiles p
          where p.enrollment_code = candidate_code
            and p.id <> new.id
        );
      end loop;
      new.enrollment_code := candidate_code;
    end if;
  end if;

  return new;
end;
$function$;


CREATE OR REPLACE FUNCTION public.consume_api_rate_limit(target_bucket_key text, target_window_seconds integer, target_max_requests integer)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  current_window timestamptz;
  new_count integer;
begin
  if target_bucket_key is null or length(target_bucket_key) < 1 or length(target_bucket_key) > 200 then
    raise exception 'invalid rate limit bucket key';
  end if;
  if target_window_seconds < 1 or target_window_seconds > 86400 then
    raise exception 'invalid rate limit window';
  end if;
  if target_max_requests < 1 or target_max_requests > 10000 then
    raise exception 'invalid rate limit maximum';
  end if;

  current_window := to_timestamp(
    floor(extract(epoch from clock_timestamp()) / target_window_seconds) * target_window_seconds
  );

  insert into public.api_rate_limit_buckets(bucket_key, window_start, request_count, updated_at)
  values (target_bucket_key, current_window, 1, now())
  on conflict (bucket_key, window_start)
  do update set
    request_count = public.api_rate_limit_buckets.request_count + 1,
    updated_at = now()
  returning request_count into new_count;

  return new_count <= target_max_requests;
end;
$function$;


CREATE OR REPLACE FUNCTION public.protect_profile_security_fields()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  requester_email text := nullif(auth.jwt() ->> 'email', '');
begin
  if current_user = 'authenticated'
     and auth.uid() is not null
     and not coalesce(public.is_teacher_admin(), false)
  then
    if tg_op = 'INSERT' then
      new.email := requester_email;
      new.created_at := now();
      new.enrollment_code := null;
      new.enrolled := false;
      new.exercise_schedule_start_date := null;
      new.archived := false;
      new.archived_at := null;
      new.class_type := null;
      new.first_portal_access_at := null;
      new.last_portal_access_at := null;
    elsif tg_op = 'UPDATE' then
      if new.email is distinct from old.email
         or new.created_at is distinct from old.created_at
         or coalesce(new.enrollment_code, '') is distinct from coalesce(old.enrollment_code, '')
         or new.enrolled is distinct from old.enrolled
         or new.exercise_schedule_start_date is distinct from old.exercise_schedule_start_date
         or new.archived is distinct from old.archived
         or new.archived_at is distinct from old.archived_at
         or new.class_type is distinct from old.class_type
         or new.first_portal_access_at is distinct from old.first_portal_access_at
         or new.last_portal_access_at is distinct from old.last_portal_access_at
      then
        raise exception 'Campos administrativos do perfil não podem ser alterados diretamente.'
          using errcode = '42501';
      end if;
    end if;
  end if;

  return new;
end;
$function$;


CREATE OR REPLACE FUNCTION public.record_flashcard_review(p_card_id uuid, p_grade text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  v_today date := (now() at time zone 'America/Sao_Paulo')::date;
  v_user_id uuid := (select auth.uid());
  v_owner_id uuid;
  v_interval integer := 0;
  v_repetitions integer := 0;
  v_lapses integer := 0;
  v_ease numeric(4,2) := 2.50;
  v_due date;
  v_existing boolean := false;
begin
  if v_user_id is null then
    raise exception 'Usuário não autenticado.';
  end if;

  if p_grade not in ('again', 'hard', 'good', 'easy') then
    raise exception 'Avaliação SRS inválida.';
  end if;

  select deck.owner_id
  into v_owner_id
  from public.flashcards card
  join public.flashcard_decks deck on deck.id = card.deck_id
  where card.id = p_card_id;

  if v_owner_id is null then
    raise exception 'Cartão não encontrado.';
  end if;

  if v_owner_id <> v_user_id then
    raise exception 'Somente o aluno proprietário pode alterar a agenda deste cartão.';
  end if;

  select interval_days, repetitions, lapses, ease_factor
  into v_interval, v_repetitions, v_lapses, v_ease
  from public.flashcard_srs
  where user_id = v_user_id
    and card_id = p_card_id
  for update;

  v_existing := found;
  if not v_existing then
    v_interval := 0;
    v_repetitions := 0;
    v_lapses := 0;
    v_ease := 2.50;
  end if;

  case p_grade
    when 'again' then
      v_interval := 0;
      v_repetitions := 0;
      v_lapses := v_lapses + 1;
      v_ease := greatest(1.30, v_ease - 0.20);
      v_due := v_today;
    when 'hard' then
      if v_repetitions = 0 then
        v_interval := 1;
      else
        v_interval := greatest(1, ceil(v_interval * 1.20)::integer);
      end if;
      v_repetitions := v_repetitions + 1;
      v_ease := greatest(1.30, v_ease - 0.15);
      v_due := v_today + v_interval;
    when 'good' then
      if v_repetitions = 0 then
        v_interval := 1;
      elsif v_repetitions = 1 then
        v_interval := 3;
      else
        v_interval := greatest(1, round(v_interval * v_ease)::integer);
      end if;
      v_repetitions := v_repetitions + 1;
      v_due := v_today + v_interval;
    when 'easy' then
      if v_repetitions = 0 then
        v_interval := 4;
      elsif v_repetitions = 1 then
        v_interval := 7;
      else
        v_interval := greatest(1, round(v_interval * v_ease * 1.30)::integer);
      end if;
      v_repetitions := v_repetitions + 1;
      v_ease := least(3.50, v_ease + 0.15);
      v_due := v_today + v_interval;
  end case;

  insert into public.flashcard_srs (
    user_id, card_id, ease_factor, interval_days, repetitions, lapses,
    due_date, last_grade, last_reviewed_at
  )
  values (
    v_user_id, p_card_id, v_ease, v_interval, v_repetitions, v_lapses,
    v_due, p_grade, now()
  )
  on conflict (user_id, card_id) do update
  set ease_factor = excluded.ease_factor,
      interval_days = excluded.interval_days,
      repetitions = excluded.repetitions,
      lapses = excluded.lapses,
      due_date = excluded.due_date,
      last_grade = excluded.last_grade,
      last_reviewed_at = excluded.last_reviewed_at,
      updated_at = now();

  insert into public.flashcard_review_history (
    user_id, card_id, grade, interval_days_after, due_date_after,
    ease_factor_after, repetitions_after
  )
  values (
    v_user_id, p_card_id, p_grade, v_interval, v_due,
    v_ease, v_repetitions
  );

  return jsonb_build_object(
    'card_id', p_card_id,
    'user_id', v_user_id,
    'grade', p_grade,
    'due_date', v_due,
    'interval_days', v_interval,
    'repetitions', v_repetitions,
    'lapses', v_lapses,
    'ease_factor', v_ease,
    'last_reviewed_at', now()
  );
end;
$function$;


CREATE OR REPLACE FUNCTION public.prevent_new_duplicate_profile_cpf()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  new_cpf text := regexp_replace(coalesce(new.cpf, ''), '\D', '', 'g');
  old_cpf text;
begin
  if new_cpf = '' then
    return new;
  end if;

  if tg_op = 'UPDATE' then
    old_cpf := regexp_replace(coalesce(old.cpf, ''), '\D', '', 'g');
    if new_cpf = old_cpf then
      return new;
    end if;
  end if;

  if exists (
    select 1
    from public.profiles p
    where p.id <> new.id
      and regexp_replace(coalesce(p.cpf, ''), '\D', '', 'g') = new_cpf
  ) then
    raise exception 'Já existe outro perfil com este CPF.' using errcode = '23505';
  end if;

  return new;
end;
$function$;


CREATE OR REPLACE FUNCTION public.prune_app_error_events(target_days integer DEFAULT 90)
 RETURNS integer
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  deleted_count integer;
begin
  if target_days < 7 or target_days > 365 then
    raise exception 'Período de retenção inválido.';
  end if;
  delete from public.app_error_events
  where created_at < now() - make_interval(days => target_days);
  get diagnostics deleted_count = row_count;
  return deleted_count;
end;
$function$;


CREATE OR REPLACE FUNCTION public.dispatch_makeup_notification_webhook()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'pg_temp'
AS $function$
declare
  webhook_secret text;
begin
  select ds.decrypted_secret
    into webhook_secret
  from vault.decrypted_secrets ds
  where ds.name = 'teacherflavius_notification_webhook_secret'
  limit 1;

  if nullif(webhook_secret, '') is null then
    raise warning 'Makeup notification webhook secret is unavailable';
    return new;
  end if;

  perform net.http_post(
    url := 'https://wnigzpvgsbpjdxvjzugt.supabase.co/functions/v1/notify-makeup-booking',
    body := jsonb_build_object(
      'type', 'INSERT',
      'table', tg_table_name,
      'schema', tg_table_schema,
      'record', to_jsonb(new),
      'old_record', null
    ),
    params := '{}'::jsonb,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-webhook-secret', webhook_secret
    ),
    timeout_milliseconds := 10000
  );

  return new;
end;
$function$;



-- Row Level Security
alter table public.profiles enable row level security;
alter table public.activity_results enable row level security;
alter table public.student_frequency enable row level security;
alter table public.teacher_admins enable row level security;
alter table public.student_enrollments enable row level security;
alter table public.daily_exercise_completion enable row level security;
alter table public.class_students enable row level security;
alter table public.study_roadmap_completion enable row level security;
alter table public.class_resources enable row level security;
alter table public.teacher_exercises enable row level security;
alter table public.teacher_classes enable row level security;
alter table public.class_lesson_records enable row level security;
alter table public.student_private_data enable row level security;
alter table public.backup_profiles_20260501 enable row level security;
alter table public.backup_student_private_data_20260501 enable row level security;
alter table public.backup_auth_users_metadata_20260501 enable row level security;
alter table public.grammar_lessons enable row level security;
alter table public.grammar_lesson_completion enable row level security;
alter table public.student_enrollment_invites enable row level security;
alter table public.student_tags enable row level security;
alter table public.student_billing_settings enable row level security;
alter table public.monthly_tuition enable row level security;
alter table public.monthly_tuition_events enable row level security;
alter table public.enrollment_email_notifications enable row level security;
alter table public.makeup_class_slots enable row level security;
alter table public.makeup_class_bookings enable row level security;
alter table public.makeup_class_email_notifications enable row level security;
alter table public.student_access_logs enable row level security;
alter table public.flashcard_decks enable row level security;
alter table public.flashcards enable row level security;
alter table public.flashcard_practice_days enable row level security;
alter table public.exercise_sync_runs enable row level security;
alter table public.weekly_plan_snapshots enable row level security;
alter table public.weekly_student_tasks enable row level security;
alter table public.exercise_form_sources enable row level security;
alter table public.tuition_payment_attempts enable row level security;
alter table public.pronunciation_assignments enable row level security;
alter table public.pronunciation_attempts enable row level security;
alter table public.exercise_sync_events enable row level security;
alter table public.student_google_email_aliases enable row level security;
alter table public.student_google_account_links enable row level security;
alter table public.api_rate_limit_buckets enable row level security;
alter table public.flashcard_srs enable row level security;
alter table public.flashcard_review_history enable row level security;
alter table public.csp_violation_reports enable row level security;
alter table public.app_error_events enable row level security;


-- RLS policies
create policy "Users can insert own activity results" on public.activity_results as restrictive for insert to authenticated
  with check ((( SELECT auth.uid() AS uid) = user_id));

create policy "Users can read own activity results" on public.activity_results as restrictive for select to authenticated
  using ((( SELECT auth.uid() AS uid) = user_id));

create policy "Professor pode consultar erros da aplicação" on public.app_error_events as restrictive for select to authenticated
  using (( SELECT is_teacher_admin() AS is_teacher_admin));

create policy "Professor pode resolver erros da aplicação" on public.app_error_events as restrictive for update to authenticated
  using (( SELECT is_teacher_admin() AS is_teacher_admin))
  with check (( SELECT is_teacher_admin() AS is_teacher_admin));

create policy "Alunos e professores podem visualizar registros de lições" on public.class_lesson_records as restrictive for select to authenticated
  using ((( SELECT is_teacher_admin() AS is_teacher_admin) OR (( SELECT auth.uid() AS uid) = user_id)));

create policy "Professores podem atualizar registros de lições" on public.class_lesson_records as restrictive for update to authenticated
  using (( SELECT is_teacher_admin() AS is_teacher_admin))
  with check (( SELECT is_teacher_admin() AS is_teacher_admin));

create policy "Professores podem excluir registros de lições" on public.class_lesson_records as restrictive for delete to authenticated
  using (( SELECT is_teacher_admin() AS is_teacher_admin));

create policy "Professores podem inserir registros de lições" on public.class_lesson_records as restrictive for insert to authenticated
  with check (( SELECT is_teacher_admin() AS is_teacher_admin));

create policy "Alunos e professores podem visualizar recursos da turma" on public.class_resources as restrictive for select to authenticated
  using ((( SELECT is_teacher_admin() AS is_teacher_admin) OR (EXISTS ( SELECT 1
   FROM class_students cs
  WHERE ((cs.class_number = class_resources.class_number) AND (cs.user_id = ( SELECT auth.uid() AS uid)))))));

create policy "Professores podem atualizar recursos da turma" on public.class_resources as restrictive for update to authenticated
  using (( SELECT is_teacher_admin() AS is_teacher_admin))
  with check (( SELECT is_teacher_admin() AS is_teacher_admin));

create policy "Professores podem excluir recursos da turma" on public.class_resources as restrictive for delete to authenticated
  using (( SELECT is_teacher_admin() AS is_teacher_admin));

create policy "Professores podem inserir recursos da turma" on public.class_resources as restrictive for insert to authenticated
  with check (( SELECT is_teacher_admin() AS is_teacher_admin));

create policy "Alunos e professores podem visualizar vínculos de turma" on public.class_students as restrictive for select to authenticated
  using ((( SELECT is_teacher_admin() AS is_teacher_admin) OR (( SELECT auth.uid() AS uid) = user_id)));

create policy "Alunos podem ver seus exercícios diários" on public.daily_exercise_completion as restrictive for select to authenticated
  using ((( SELECT auth.uid() AS uid) = user_id));

create policy "Professor pode visualizar conclusoes de exercicios" on public.daily_exercise_completion as restrictive for select to authenticated
  using (( SELECT is_teacher_admin() AS is_teacher_admin));

create policy "Administrador visualiza notificacoes de matricula" on public.enrollment_email_notifications as restrictive for select to authenticated
  using (is_teacher_admin());

create policy "Professor pode visualizar eventos de sincronizacao" on public.exercise_sync_events as restrictive for select to authenticated
  using (( SELECT is_teacher_admin() AS is_teacher_admin));

create policy "Professores podem ver relatórios de sincronização" on public.exercise_sync_runs as restrictive for select to authenticated
  using (( SELECT is_teacher_admin() AS is_teacher_admin));

create policy "Usuários podem atualizar seus conjuntos" on public.flashcard_decks as restrictive for update to authenticated
  using (((owner_id = ( SELECT auth.uid() AS uid)) OR ( SELECT is_teacher_admin() AS is_teacher_admin)))
  with check (((owner_id = ( SELECT auth.uid() AS uid)) OR ( SELECT is_teacher_admin() AS is_teacher_admin)));

create policy "Usuários podem criar seus conjuntos" on public.flashcard_decks as restrictive for insert to authenticated
  with check (((owner_id = ( SELECT auth.uid() AS uid)) OR ( SELECT is_teacher_admin() AS is_teacher_admin)));

create policy "Usuários podem excluir seus conjuntos" on public.flashcard_decks as restrictive for delete to authenticated
  using (((owner_id = ( SELECT auth.uid() AS uid)) OR ( SELECT is_teacher_admin() AS is_teacher_admin)));

create policy "Usuários podem visualizar conjuntos permitidos" on public.flashcard_decks as restrictive for select to authenticated
  using (((owner_id = ( SELECT auth.uid() AS uid)) OR ( SELECT is_teacher_admin() AS is_teacher_admin)));

create policy "Alunos e professor podem visualizar dias de prática" on public.flashcard_practice_days as restrictive for select to authenticated
  using (((user_id = ( SELECT auth.uid() AS uid)) OR ( SELECT is_teacher_admin() AS is_teacher_admin)));

create policy "Alunos podem registrar o dia atual de prática" on public.flashcard_practice_days as restrictive for insert to authenticated
  with check (((user_id = ( SELECT auth.uid() AS uid)) AND (practice_date = ((now() AT TIME ZONE 'America/Sao_Paulo'::text))::date)));

create policy "Alunos e professor podem visualizar histórico SRS" on public.flashcard_review_history as restrictive for select to authenticated
  using (((user_id = ( SELECT auth.uid() AS uid)) OR ( SELECT is_teacher_admin() AS is_teacher_admin)));

create policy "Alunos podem registrar o próprio histórico SRS" on public.flashcard_review_history as restrictive for insert to authenticated
  with check (((user_id = ( SELECT auth.uid() AS uid)) AND (EXISTS ( SELECT 1
   FROM (flashcards card
     JOIN flashcard_decks deck ON ((deck.id = card.deck_id)))
  WHERE ((card.id = flashcard_review_history.card_id) AND (deck.owner_id = ( SELECT auth.uid() AS uid)))))));

create policy "Alunos e professor podem visualizar progresso SRS" on public.flashcard_srs as restrictive for select to authenticated
  using (((user_id = ( SELECT auth.uid() AS uid)) OR ( SELECT is_teacher_admin() AS is_teacher_admin)));

create policy "Alunos podem atualizar o próprio progresso SRS" on public.flashcard_srs as restrictive for update to authenticated
  using (((user_id = ( SELECT auth.uid() AS uid)) AND (EXISTS ( SELECT 1
   FROM (flashcards card
     JOIN flashcard_decks deck ON ((deck.id = card.deck_id)))
  WHERE ((card.id = flashcard_srs.card_id) AND (deck.owner_id = ( SELECT auth.uid() AS uid)))))))
  with check (((user_id = ( SELECT auth.uid() AS uid)) AND (EXISTS ( SELECT 1
   FROM (flashcards card
     JOIN flashcard_decks deck ON ((deck.id = card.deck_id)))
  WHERE ((card.id = flashcard_srs.card_id) AND (deck.owner_id = ( SELECT auth.uid() AS uid)))))));

create policy "Alunos podem criar o próprio progresso SRS" on public.flashcard_srs as restrictive for insert to authenticated
  with check (((user_id = ( SELECT auth.uid() AS uid)) AND (EXISTS ( SELECT 1
   FROM (flashcards card
     JOIN flashcard_decks deck ON ((deck.id = card.deck_id)))
  WHERE ((card.id = flashcard_srs.card_id) AND (deck.owner_id = ( SELECT auth.uid() AS uid)))))));

create policy "Usuários podem atualizar cartões dos próprios conjuntos" on public.flashcards as restrictive for update to authenticated
  using ((EXISTS ( SELECT 1
   FROM flashcard_decks deck
  WHERE ((deck.id = flashcards.deck_id) AND ((deck.owner_id = ( SELECT auth.uid() AS uid)) OR ( SELECT is_teacher_admin() AS is_teacher_admin))))))
  with check ((EXISTS ( SELECT 1
   FROM flashcard_decks deck
  WHERE ((deck.id = flashcards.deck_id) AND ((deck.owner_id = ( SELECT auth.uid() AS uid)) OR ( SELECT is_teacher_admin() AS is_teacher_admin))))));

create policy "Usuários podem criar cartões nos próprios conjuntos" on public.flashcards as restrictive for insert to authenticated
  with check ((EXISTS ( SELECT 1
   FROM flashcard_decks deck
  WHERE ((deck.id = flashcards.deck_id) AND ((deck.owner_id = ( SELECT auth.uid() AS uid)) OR ( SELECT is_teacher_admin() AS is_teacher_admin))))));

create policy "Usuários podem excluir cartões dos próprios conjuntos" on public.flashcards as restrictive for delete to authenticated
  using ((EXISTS ( SELECT 1
   FROM flashcard_decks deck
  WHERE ((deck.id = flashcards.deck_id) AND ((deck.owner_id = ( SELECT auth.uid() AS uid)) OR ( SELECT is_teacher_admin() AS is_teacher_admin))))));

create policy "Usuários podem visualizar cartões permitidos" on public.flashcards as restrictive for select to authenticated
  using ((EXISTS ( SELECT 1
   FROM flashcard_decks deck
  WHERE ((deck.id = flashcards.deck_id) AND ((deck.owner_id = ( SELECT auth.uid() AS uid)) OR ( SELECT is_teacher_admin() AS is_teacher_admin))))));

create policy "Alunos podem atualizar suas conclusoes de gramatica" on public.grammar_lesson_completion as restrictive for update to authenticated
  using ((user_id = ( SELECT auth.uid() AS uid)))
  with check ((user_id = ( SELECT auth.uid() AS uid)));

create policy "Alunos podem criar suas conclusoes de gramatica" on public.grammar_lesson_completion as restrictive for insert to authenticated
  with check ((user_id = ( SELECT auth.uid() AS uid)));

create policy "Alunos podem visualizar suas conclusoes de gramatica" on public.grammar_lesson_completion as restrictive for select to authenticated
  using ((user_id = ( SELECT auth.uid() AS uid)));

create policy "Professor pode visualizar conclusoes de gramatica" on public.grammar_lesson_completion as restrictive for select to authenticated
  using (( SELECT is_teacher_admin() AS is_teacher_admin));

create policy "Alunos autenticados podem visualizar aulas de gramatica" on public.grammar_lessons as restrictive for select to authenticated
  using (true);

create policy "Professores podem criar aulas de gramatica" on public.grammar_lessons as restrictive for insert to authenticated
  with check (is_teacher_admin());

create policy "Professores podem editar aulas de gramatica" on public.grammar_lessons as restrictive for update to authenticated
  using (is_teacher_admin())
  with check (is_teacher_admin());

create policy "Professores podem excluir aulas de gramatica" on public.grammar_lessons as restrictive for delete to authenticated
  using (is_teacher_admin());

create policy "Administrador visualiza notificacoes de reposicao" on public.makeup_class_email_notifications as restrictive for select to authenticated
  using (is_teacher_admin());

create policy "Administradores gerenciam mensalidades" on public.monthly_tuition as restrictive for all to authenticated
  using (is_teacher_admin())
  with check (is_teacher_admin());

create policy "Administradores visualizam eventos financeiros" on public.monthly_tuition_events as restrictive for select to authenticated
  using (is_teacher_admin());

create policy "Alunos e professores podem atualizar perfis" on public.profiles as restrictive for update to authenticated
  using ((( SELECT is_teacher_admin() AS is_teacher_admin) OR (( SELECT auth.uid() AS uid) = id)))
  with check ((( SELECT is_teacher_admin() AS is_teacher_admin) OR (( SELECT auth.uid() AS uid) = id)));

create policy "Alunos e professores podem visualizar perfis" on public.profiles as restrictive for select to authenticated
  using ((( SELECT is_teacher_admin() AS is_teacher_admin) OR (( SELECT auth.uid() AS uid) = id)));

create policy "Users can insert own profile" on public.profiles as restrictive for insert to authenticated
  with check (((( SELECT auth.uid() AS uid) = id) AND (enrolled = false) AND (COALESCE(enrollment_code, ''::text) = ''::text) AND (COALESCE(archived, false) = false) AND (archived_at IS NULL) AND (class_type IS NULL) AND (exercise_schedule_start_date IS NULL) AND (first_portal_access_at IS NULL) AND (last_portal_access_at IS NULL)));

create policy "Authenticated users can view active pronunciation assignments" on public.pronunciation_assignments as restrictive for select to authenticated
  using ((( SELECT is_teacher_admin() AS is_teacher_admin) OR (is_active = true)));

create policy "Teachers can manage pronunciation assignments" on public.pronunciation_assignments as restrictive for all to authenticated
  using (( SELECT is_teacher_admin() AS is_teacher_admin))
  with check (( SELECT is_teacher_admin() AS is_teacher_admin));

create policy "Students can read own pronunciation attempts" on public.pronunciation_attempts as restrictive for select to authenticated
  using ((( SELECT is_teacher_admin() AS is_teacher_admin) OR (( SELECT auth.uid() AS uid) = user_id)));

create policy "Teachers can update pronunciation attempts" on public.pronunciation_attempts as restrictive for update to authenticated
  using (( SELECT is_teacher_admin() AS is_teacher_admin))
  with check (( SELECT is_teacher_admin() AS is_teacher_admin));

create policy "Professor pode visualizar acessos dos alunos" on public.student_access_logs as restrictive for select to authenticated
  using (( SELECT is_teacher_admin() AS is_teacher_admin));

create policy "Administradores gerenciam configurações financeiras" on public.student_billing_settings as restrictive for all to authenticated
  using (is_teacher_admin())
  with check (is_teacher_admin());

create policy "Professores podem atualizar convites de matricula" on public.student_enrollment_invites as restrictive for update to authenticated
  using (is_teacher_admin())
  with check (is_teacher_admin());

create policy "Professores podem criar convites de matricula" on public.student_enrollment_invites as restrictive for insert to authenticated
  with check (is_teacher_admin());

create policy "Professores podem excluir convites de matricula" on public.student_enrollment_invites as restrictive for delete to authenticated
  using (is_teacher_admin());

create policy "Professores podem visualizar convites de matricula" on public.student_enrollment_invites as restrictive for select to authenticated
  using (is_teacher_admin());

create policy "Professores podem visualizar matrículas" on public.student_enrollments as restrictive for select to authenticated
  using (( SELECT is_teacher_admin() AS is_teacher_admin));

create policy "Alunos podem ver sua própria frequência" on public.student_frequency as restrictive for select to authenticated
  using ((( SELECT auth.uid() AS uid) = user_id));

create policy "Professor pode visualizar frequencia dos alunos" on public.student_frequency as restrictive for select to authenticated
  using (( SELECT is_teacher_admin() AS is_teacher_admin));

create policy "Alunos e professores podem visualizar dados privados" on public.student_private_data as restrictive for select to authenticated
  using ((( SELECT is_teacher_admin() AS is_teacher_admin) OR (( SELECT auth.uid() AS uid) = user_id)));

create policy "Alunos podem atualizar seus próprios dados privados" on public.student_private_data as restrictive for update to authenticated
  using ((( SELECT auth.uid() AS uid) = user_id))
  with check ((( SELECT auth.uid() AS uid) = user_id));

create policy "Alunos podem inserir seus próprios dados privados" on public.student_private_data as restrictive for insert to authenticated
  with check ((( SELECT auth.uid() AS uid) = user_id));

create policy "Professores podem criar tags de alunos" on public.student_tags as restrictive for insert to authenticated
  with check (is_teacher_admin());

create policy "Professores podem excluir tags de alunos" on public.student_tags as restrictive for delete to authenticated
  using (is_teacher_admin());

create policy "Professores podem visualizar tags de alunos" on public.student_tags as restrictive for select to authenticated
  using (is_teacher_admin());

create policy "Alunos podem atualizar suas lições do roteiro" on public.study_roadmap_completion as restrictive for update to authenticated
  using ((( SELECT auth.uid() AS uid) = user_id))
  with check ((( SELECT auth.uid() AS uid) = user_id));

create policy "Alunos podem inserir suas lições do roteiro" on public.study_roadmap_completion as restrictive for insert to authenticated
  with check ((( SELECT auth.uid() AS uid) = user_id));

create policy "Alunos podem ver suas lições do roteiro" on public.study_roadmap_completion as restrictive for select to authenticated
  using ((( SELECT auth.uid() AS uid) = user_id));

create policy "Professor pode visualizar progresso do roteiro" on public.study_roadmap_completion as restrictive for select to authenticated
  using (( SELECT is_teacher_admin() AS is_teacher_admin));

create policy "Professor pode verificar suas próprias credenciais" on public.teacher_admins as restrictive for select to authenticated
  using ((lower(email) = lower((( SELECT auth.jwt() AS jwt) ->> 'email'::text))));

create policy "Alunos e professores podem visualizar turmas" on public.teacher_classes as restrictive for select to authenticated
  using ((( SELECT is_teacher_admin() AS is_teacher_admin) OR (EXISTS ( SELECT 1
   FROM class_students cs
  WHERE ((cs.class_number = teacher_classes.class_number) AND (cs.user_id = ( SELECT auth.uid() AS uid)))))));

create policy "Professores podem atualizar turmas" on public.teacher_classes as restrictive for update to authenticated
  using (( SELECT is_teacher_admin() AS is_teacher_admin))
  with check (( SELECT is_teacher_admin() AS is_teacher_admin));

create policy "Professores podem excluir turmas" on public.teacher_classes as restrictive for delete to authenticated
  using (( SELECT is_teacher_admin() AS is_teacher_admin));

create policy "Professores podem inserir turmas" on public.teacher_classes as restrictive for insert to authenticated
  with check (( SELECT is_teacher_admin() AS is_teacher_admin));

create policy "Alunos e professores podem visualizar exercícios" on public.teacher_exercises as restrictive for select to authenticated
  using ((( SELECT is_teacher_admin() AS is_teacher_admin) OR ((( SELECT auth.uid() AS uid) IS NOT NULL) AND (is_active = true) AND ((scheduled_publish_at IS NULL) OR (scheduled_publish_at <= now())))));

create policy "Professores podem atualizar exercícios" on public.teacher_exercises as restrictive for update to authenticated
  using (( SELECT is_teacher_admin() AS is_teacher_admin))
  with check (( SELECT is_teacher_admin() AS is_teacher_admin));

create policy "Professores podem excluir exercícios" on public.teacher_exercises as restrictive for delete to authenticated
  using (( SELECT is_teacher_admin() AS is_teacher_admin));

create policy "Professores podem inserir exercícios" on public.teacher_exercises as restrictive for insert to authenticated
  with check (( SELECT is_teacher_admin() AS is_teacher_admin));

create policy tuition_payment_attempts_no_direct_client_access on public.tuition_payment_attempts as restrictive for all to anon, authenticated
  using (false)
  with check (false);

create policy "Aluno ou professor ve plano semanal" on public.weekly_plan_snapshots as restrictive for select to authenticated
  using (((( SELECT auth.uid() AS uid) = user_id) OR ( SELECT is_teacher_admin() AS is_teacher_admin)));

create policy "Aluno ou professor ve tarefas semanais" on public.weekly_student_tasks as restrictive for select to authenticated
  using (((( SELECT auth.uid() AS uid) = user_id) OR ( SELECT is_teacher_admin() AS is_teacher_admin)));

create policy "Professor atualiza tarefas semanais" on public.weekly_student_tasks as restrictive for update to authenticated
  using (( SELECT is_teacher_admin() AS is_teacher_admin))
  with check (( SELECT is_teacher_admin() AS is_teacher_admin));

create policy "Professor cria tarefas semanais" on public.weekly_student_tasks as restrictive for insert to authenticated
  with check (( SELECT is_teacher_admin() AS is_teacher_admin));

create policy "Professor exclui tarefas semanais" on public.weekly_student_tasks as restrictive for delete to authenticated
  using (( SELECT is_teacher_admin() AS is_teacher_admin));


-- Application private schema
create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

CREATE OR REPLACE FUNCTION private.dispatch_enrollment_notification_webhook()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  webhook_secret text;
begin
  select ds.decrypted_secret
    into webhook_secret
  from vault.decrypted_secrets as ds
  where ds.name = 'teacherflavius_notification_webhook_secret'
  limit 1;

  if nullif(webhook_secret, '') is null then
    raise warning 'Enrollment notification webhook secret is unavailable';
    return new;
  end if;

  perform net.http_post(
    url := 'https://wnigzpvgsbpjdxvjzugt.supabase.co/functions/v1/notify-new-enrollment',
    body := pg_catalog.jsonb_build_object(
      'type', 'INSERT',
      'table', tg_table_name,
      'schema', tg_table_schema,
      'record', pg_catalog.to_jsonb(new),
      'old_record', null
    ),
    params := '{}'::jsonb,
    headers := pg_catalog.jsonb_build_object(
      'Content-Type', 'application/json',
      'x-webhook-secret', webhook_secret
    ),
    timeout_milliseconds := 5000
  );

  return new;
end;
$function$;


revoke all on function private.dispatch_enrollment_notification_webhook() from public, anon, authenticated, service_role;

-- Public triggers
CREATE TRIGGER activate_completed_google_student_profile_before_write BEFORE INSERT OR UPDATE OF profile_completed, enrolled, enrollment_code, email ON public.profiles FOR EACH ROW EXECUTE FUNCTION activate_completed_google_student_profile();
CREATE TRIGGER normalize_profile_enrollment_code_before_write BEFORE INSERT OR UPDATE OF enrollment_code ON public.profiles FOR EACH ROW EXECUTE FUNCTION normalize_profile_enrollment_code();
CREATE TRIGGER preserve_linked_student_enrollment_email_trigger BEFORE UPDATE OF email ON public.profiles FOR EACH ROW EXECUTE FUNCTION preserve_linked_student_enrollment_email();
CREATE TRIGGER profiles_prevent_new_duplicate_cpf BEFORE INSERT OR UPDATE OF cpf ON public.profiles FOR EACH ROW EXECUTE FUNCTION prevent_new_duplicate_profile_cpf();
CREATE TRIGGER protect_profile_security_fields_trigger BEFORE INSERT OR UPDATE ON public.profiles FOR EACH ROW EXECUTE FUNCTION protect_profile_security_fields();
CREATE TRIGGER queue_enrollment_email_notification_trigger AFTER INSERT OR UPDATE OF enrolled ON public.profiles FOR EACH ROW EXECUTE FUNCTION queue_enrollment_email_notification();
CREATE TRIGGER trg_set_exercise_schedule_start_date BEFORE INSERT OR UPDATE ON public.profiles FOR EACH ROW EXECUTE FUNCTION set_exercise_schedule_start_date();
CREATE TRIGGER set_student_frequency_updated_at BEFORE UPDATE ON public.student_frequency FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER set_daily_exercise_completion_actor BEFORE INSERT OR UPDATE ON public.daily_exercise_completion FOR EACH ROW EXECUTE FUNCTION set_daily_exercise_completion_actor();
CREATE TRIGGER set_daily_exercise_completion_updated_at BEFORE UPDATE ON public.daily_exercise_completion FOR EACH ROW EXECUTE FUNCTION set_daily_exercise_completion_updated_at();
CREATE TRIGGER enforce_class_students_capacity_trigger BEFORE INSERT OR UPDATE OF class_number, user_id, invite_id ON public.class_students FOR EACH ROW EXECUTE FUNCTION enforce_class_students_capacity();
CREATE TRIGGER set_study_roadmap_completion_updated_at BEFORE UPDATE ON public.study_roadmap_completion FOR EACH ROW EXECUTE FUNCTION set_study_roadmap_completion_updated_at();
CREATE TRIGGER set_class_resources_updated_at BEFORE UPDATE ON public.class_resources FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER set_teacher_exercises_updated_at BEFORE UPDATE ON public.teacher_exercises FOR EACH ROW EXECUTE FUNCTION set_teacher_exercises_updated_at();
CREATE TRIGGER set_teacher_classes_updated_at BEFORE UPDATE ON public.teacher_classes FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER set_class_lesson_records_updated_at BEFORE UPDATE ON public.class_lesson_records FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER set_student_private_data_updated_at BEFORE UPDATE ON public.student_private_data FOR EACH ROW EXECUTE FUNCTION set_student_private_data_updated_at();
CREATE TRIGGER migrate_invite_records_to_user_trigger AFTER UPDATE OF status, user_id ON public.student_enrollment_invites FOR EACH ROW EXECUTE FUNCTION migrate_invite_records_to_user();
CREATE TRIGGER migrate_invite_student_tags_to_user_trigger AFTER UPDATE OF status, user_id ON public.student_enrollment_invites FOR EACH ROW EXECUTE FUNCTION migrate_invite_student_tags_to_user();
CREATE TRIGGER "notify-new-enrollment" AFTER INSERT ON public.enrollment_email_notifications FOR EACH ROW EXECUTE FUNCTION private.dispatch_enrollment_notification_webhook();
CREATE TRIGGER set_makeup_class_slots_updated_at BEFORE UPDATE ON public.makeup_class_slots FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_enforce_makeup_slots_enabled BEFORE INSERT OR UPDATE OF class_number ON public.makeup_class_slots FOR EACH ROW EXECUTE FUNCTION enforce_makeup_slots_enabled();
CREATE TRIGGER "notify-makeup-booking" AFTER INSERT ON public.makeup_class_email_notifications FOR EACH ROW EXECUTE FUNCTION dispatch_makeup_notification_webhook();
CREATE TRIGGER trg_sync_student_portal_access_status AFTER INSERT ON public.student_access_logs FOR EACH ROW EXECUTE FUNCTION sync_student_portal_access_status();
CREATE TRIGGER set_flashcard_decks_updated_at BEFORE UPDATE ON public.flashcard_decks FOR EACH ROW EXECUTE FUNCTION set_flashcards_updated_at();
CREATE TRIGGER set_flashcards_updated_at BEFORE UPDATE ON public.flashcards FOR EACH ROW EXECUTE FUNCTION set_flashcards_updated_at();
CREATE TRIGGER tuition_payment_attempts_set_updated_at BEFORE UPDATE ON public.tuition_payment_attempts FOR EACH ROW EXECUTE FUNCTION set_tuition_payment_attempt_updated_at();
CREATE TRIGGER set_flashcard_srs_updated_at BEFORE UPDATE ON public.flashcard_srs FOR EACH ROW EXECUTE FUNCTION set_flashcards_updated_at();


-- Application-owned auth triggers
CREATE TRIGGER sync_enrolled_auth_user_profile_trigger AFTER INSERT OR UPDATE OF raw_user_meta_data, email ON auth.users FOR EACH ROW EXECUTE FUNCTION handle_enrolled_auth_user_profile();


-- Event triggers
create event trigger ensure_rls on ddl_command_end when tag in ('CREATE TABLE', 'CREATE TABLE AS', 'SELECT INTO') execute function public.rls_auto_enable();


-- Table grants
revoke all on table public.profiles from public, anon, authenticated, service_role;
revoke all on table public.activity_results from public, anon, authenticated, service_role;
revoke all on table public.student_frequency from public, anon, authenticated, service_role;
revoke all on table public.teacher_admins from public, anon, authenticated, service_role;
revoke all on table public.student_enrollments from public, anon, authenticated, service_role;
revoke all on table public.daily_exercise_completion from public, anon, authenticated, service_role;
revoke all on table public.class_students from public, anon, authenticated, service_role;
revoke all on table public.study_roadmap_completion from public, anon, authenticated, service_role;
revoke all on table public.class_resources from public, anon, authenticated, service_role;
revoke all on table public.teacher_exercises from public, anon, authenticated, service_role;
revoke all on table public.teacher_classes from public, anon, authenticated, service_role;
revoke all on table public.class_lesson_records from public, anon, authenticated, service_role;
revoke all on table public.student_private_data from public, anon, authenticated, service_role;
revoke all on table public.backup_profiles_20260501 from public, anon, authenticated, service_role;
revoke all on table public.backup_student_private_data_20260501 from public, anon, authenticated, service_role;
revoke all on table public.backup_auth_users_metadata_20260501 from public, anon, authenticated, service_role;
revoke all on table public.grammar_lessons from public, anon, authenticated, service_role;
revoke all on table public.grammar_lesson_completion from public, anon, authenticated, service_role;
revoke all on table public.student_enrollment_invites from public, anon, authenticated, service_role;
revoke all on table public.student_tags from public, anon, authenticated, service_role;
revoke all on table public.student_billing_settings from public, anon, authenticated, service_role;
revoke all on table public.monthly_tuition from public, anon, authenticated, service_role;
revoke all on table public.monthly_tuition_events from public, anon, authenticated, service_role;
revoke all on table public.enrollment_email_notifications from public, anon, authenticated, service_role;
revoke all on table public.makeup_class_slots from public, anon, authenticated, service_role;
revoke all on table public.makeup_class_bookings from public, anon, authenticated, service_role;
revoke all on table public.makeup_class_email_notifications from public, anon, authenticated, service_role;
revoke all on table public.student_access_logs from public, anon, authenticated, service_role;
revoke all on table public.flashcard_decks from public, anon, authenticated, service_role;
revoke all on table public.flashcards from public, anon, authenticated, service_role;
revoke all on table public.flashcard_practice_days from public, anon, authenticated, service_role;
revoke all on table public.exercise_sync_runs from public, anon, authenticated, service_role;
revoke all on table public.weekly_plan_snapshots from public, anon, authenticated, service_role;
revoke all on table public.weekly_student_tasks from public, anon, authenticated, service_role;
revoke all on table public.exercise_form_sources from public, anon, authenticated, service_role;
revoke all on table public.tuition_payment_attempts from public, anon, authenticated, service_role;
revoke all on table public.pronunciation_assignments from public, anon, authenticated, service_role;
revoke all on table public.pronunciation_attempts from public, anon, authenticated, service_role;
revoke all on table public.exercise_sync_events from public, anon, authenticated, service_role;
revoke all on table public.student_google_email_aliases from public, anon, authenticated, service_role;
revoke all on table public.student_google_account_links from public, anon, authenticated, service_role;
revoke all on table public.api_rate_limit_buckets from public, anon, authenticated, service_role;
revoke all on table public.flashcard_srs from public, anon, authenticated, service_role;
revoke all on table public.flashcard_review_history from public, anon, authenticated, service_role;
revoke all on table public.csp_violation_reports from public, anon, authenticated, service_role;
revoke all on table public.app_error_events from public, anon, authenticated, service_role;
grant DELETE on table public.profiles to anon;
grant INSERT on table public.profiles to anon;
grant MAINTAIN on table public.profiles to anon;
grant REFERENCES on table public.profiles to anon;
grant SELECT on table public.profiles to anon;
grant TRIGGER on table public.profiles to anon;
grant TRUNCATE on table public.profiles to anon;
grant UPDATE on table public.profiles to anon;
grant DELETE on table public.profiles to authenticated;
grant INSERT on table public.profiles to authenticated;
grant MAINTAIN on table public.profiles to authenticated;
grant REFERENCES on table public.profiles to authenticated;
grant SELECT on table public.profiles to authenticated;
grant TRIGGER on table public.profiles to authenticated;
grant TRUNCATE on table public.profiles to authenticated;
grant UPDATE on table public.profiles to authenticated;
grant DELETE on table public.profiles to service_role;
grant INSERT on table public.profiles to service_role;
grant MAINTAIN on table public.profiles to service_role;
grant REFERENCES on table public.profiles to service_role;
grant SELECT on table public.profiles to service_role;
grant TRIGGER on table public.profiles to service_role;
grant TRUNCATE on table public.profiles to service_role;
grant UPDATE on table public.profiles to service_role;
grant DELETE on table public.activity_results to anon;
grant INSERT on table public.activity_results to anon;
grant MAINTAIN on table public.activity_results to anon;
grant REFERENCES on table public.activity_results to anon;
grant SELECT on table public.activity_results to anon;
grant TRIGGER on table public.activity_results to anon;
grant TRUNCATE on table public.activity_results to anon;
grant UPDATE on table public.activity_results to anon;
grant DELETE on table public.activity_results to authenticated;
grant INSERT on table public.activity_results to authenticated;
grant MAINTAIN on table public.activity_results to authenticated;
grant REFERENCES on table public.activity_results to authenticated;
grant SELECT on table public.activity_results to authenticated;
grant TRIGGER on table public.activity_results to authenticated;
grant TRUNCATE on table public.activity_results to authenticated;
grant UPDATE on table public.activity_results to authenticated;
grant DELETE on table public.activity_results to service_role;
grant INSERT on table public.activity_results to service_role;
grant MAINTAIN on table public.activity_results to service_role;
grant REFERENCES on table public.activity_results to service_role;
grant SELECT on table public.activity_results to service_role;
grant TRIGGER on table public.activity_results to service_role;
grant TRUNCATE on table public.activity_results to service_role;
grant UPDATE on table public.activity_results to service_role;
grant DELETE on table public.student_frequency to anon;
grant INSERT on table public.student_frequency to anon;
grant MAINTAIN on table public.student_frequency to anon;
grant REFERENCES on table public.student_frequency to anon;
grant SELECT on table public.student_frequency to anon;
grant TRIGGER on table public.student_frequency to anon;
grant TRUNCATE on table public.student_frequency to anon;
grant UPDATE on table public.student_frequency to anon;
grant DELETE on table public.student_frequency to authenticated;
grant INSERT on table public.student_frequency to authenticated;
grant MAINTAIN on table public.student_frequency to authenticated;
grant REFERENCES on table public.student_frequency to authenticated;
grant SELECT on table public.student_frequency to authenticated;
grant TRIGGER on table public.student_frequency to authenticated;
grant TRUNCATE on table public.student_frequency to authenticated;
grant UPDATE on table public.student_frequency to authenticated;
grant DELETE on table public.student_frequency to service_role;
grant INSERT on table public.student_frequency to service_role;
grant MAINTAIN on table public.student_frequency to service_role;
grant REFERENCES on table public.student_frequency to service_role;
grant SELECT on table public.student_frequency to service_role;
grant TRIGGER on table public.student_frequency to service_role;
grant TRUNCATE on table public.student_frequency to service_role;
grant UPDATE on table public.student_frequency to service_role;
grant DELETE on table public.teacher_admins to anon;
grant INSERT on table public.teacher_admins to anon;
grant MAINTAIN on table public.teacher_admins to anon;
grant REFERENCES on table public.teacher_admins to anon;
grant SELECT on table public.teacher_admins to anon;
grant TRIGGER on table public.teacher_admins to anon;
grant TRUNCATE on table public.teacher_admins to anon;
grant UPDATE on table public.teacher_admins to anon;
grant DELETE on table public.teacher_admins to authenticated;
grant INSERT on table public.teacher_admins to authenticated;
grant MAINTAIN on table public.teacher_admins to authenticated;
grant REFERENCES on table public.teacher_admins to authenticated;
grant SELECT on table public.teacher_admins to authenticated;
grant TRIGGER on table public.teacher_admins to authenticated;
grant TRUNCATE on table public.teacher_admins to authenticated;
grant UPDATE on table public.teacher_admins to authenticated;
grant DELETE on table public.teacher_admins to service_role;
grant INSERT on table public.teacher_admins to service_role;
grant MAINTAIN on table public.teacher_admins to service_role;
grant REFERENCES on table public.teacher_admins to service_role;
grant SELECT on table public.teacher_admins to service_role;
grant TRIGGER on table public.teacher_admins to service_role;
grant TRUNCATE on table public.teacher_admins to service_role;
grant UPDATE on table public.teacher_admins to service_role;
grant DELETE on table public.student_enrollments to anon;
grant INSERT on table public.student_enrollments to anon;
grant MAINTAIN on table public.student_enrollments to anon;
grant REFERENCES on table public.student_enrollments to anon;
grant SELECT on table public.student_enrollments to anon;
grant TRIGGER on table public.student_enrollments to anon;
grant TRUNCATE on table public.student_enrollments to anon;
grant UPDATE on table public.student_enrollments to anon;
grant DELETE on table public.student_enrollments to authenticated;
grant INSERT on table public.student_enrollments to authenticated;
grant MAINTAIN on table public.student_enrollments to authenticated;
grant REFERENCES on table public.student_enrollments to authenticated;
grant SELECT on table public.student_enrollments to authenticated;
grant TRIGGER on table public.student_enrollments to authenticated;
grant TRUNCATE on table public.student_enrollments to authenticated;
grant UPDATE on table public.student_enrollments to authenticated;
grant DELETE on table public.student_enrollments to service_role;
grant INSERT on table public.student_enrollments to service_role;
grant MAINTAIN on table public.student_enrollments to service_role;
grant REFERENCES on table public.student_enrollments to service_role;
grant SELECT on table public.student_enrollments to service_role;
grant TRIGGER on table public.student_enrollments to service_role;
grant TRUNCATE on table public.student_enrollments to service_role;
grant UPDATE on table public.student_enrollments to service_role;
grant DELETE on table public.daily_exercise_completion to anon;
grant INSERT on table public.daily_exercise_completion to anon;
grant MAINTAIN on table public.daily_exercise_completion to anon;
grant REFERENCES on table public.daily_exercise_completion to anon;
grant SELECT on table public.daily_exercise_completion to anon;
grant TRIGGER on table public.daily_exercise_completion to anon;
grant TRUNCATE on table public.daily_exercise_completion to anon;
grant UPDATE on table public.daily_exercise_completion to anon;
grant DELETE on table public.daily_exercise_completion to authenticated;
grant INSERT on table public.daily_exercise_completion to authenticated;
grant MAINTAIN on table public.daily_exercise_completion to authenticated;
grant REFERENCES on table public.daily_exercise_completion to authenticated;
grant SELECT on table public.daily_exercise_completion to authenticated;
grant TRIGGER on table public.daily_exercise_completion to authenticated;
grant TRUNCATE on table public.daily_exercise_completion to authenticated;
grant UPDATE on table public.daily_exercise_completion to authenticated;
grant DELETE on table public.daily_exercise_completion to service_role;
grant INSERT on table public.daily_exercise_completion to service_role;
grant MAINTAIN on table public.daily_exercise_completion to service_role;
grant REFERENCES on table public.daily_exercise_completion to service_role;
grant SELECT on table public.daily_exercise_completion to service_role;
grant TRIGGER on table public.daily_exercise_completion to service_role;
grant TRUNCATE on table public.daily_exercise_completion to service_role;
grant UPDATE on table public.daily_exercise_completion to service_role;
grant DELETE on table public.class_students to anon;
grant INSERT on table public.class_students to anon;
grant MAINTAIN on table public.class_students to anon;
grant REFERENCES on table public.class_students to anon;
grant SELECT on table public.class_students to anon;
grant TRIGGER on table public.class_students to anon;
grant TRUNCATE on table public.class_students to anon;
grant UPDATE on table public.class_students to anon;
grant DELETE on table public.class_students to authenticated;
grant INSERT on table public.class_students to authenticated;
grant MAINTAIN on table public.class_students to authenticated;
grant REFERENCES on table public.class_students to authenticated;
grant SELECT on table public.class_students to authenticated;
grant TRIGGER on table public.class_students to authenticated;
grant TRUNCATE on table public.class_students to authenticated;
grant UPDATE on table public.class_students to authenticated;
grant DELETE on table public.class_students to service_role;
grant INSERT on table public.class_students to service_role;
grant MAINTAIN on table public.class_students to service_role;
grant REFERENCES on table public.class_students to service_role;
grant SELECT on table public.class_students to service_role;
grant TRIGGER on table public.class_students to service_role;
grant TRUNCATE on table public.class_students to service_role;
grant UPDATE on table public.class_students to service_role;
grant DELETE on table public.study_roadmap_completion to anon;
grant INSERT on table public.study_roadmap_completion to anon;
grant MAINTAIN on table public.study_roadmap_completion to anon;
grant REFERENCES on table public.study_roadmap_completion to anon;
grant SELECT on table public.study_roadmap_completion to anon;
grant TRIGGER on table public.study_roadmap_completion to anon;
grant TRUNCATE on table public.study_roadmap_completion to anon;
grant UPDATE on table public.study_roadmap_completion to anon;
grant DELETE on table public.study_roadmap_completion to authenticated;
grant INSERT on table public.study_roadmap_completion to authenticated;
grant MAINTAIN on table public.study_roadmap_completion to authenticated;
grant REFERENCES on table public.study_roadmap_completion to authenticated;
grant SELECT on table public.study_roadmap_completion to authenticated;
grant TRIGGER on table public.study_roadmap_completion to authenticated;
grant TRUNCATE on table public.study_roadmap_completion to authenticated;
grant UPDATE on table public.study_roadmap_completion to authenticated;
grant DELETE on table public.study_roadmap_completion to service_role;
grant INSERT on table public.study_roadmap_completion to service_role;
grant MAINTAIN on table public.study_roadmap_completion to service_role;
grant REFERENCES on table public.study_roadmap_completion to service_role;
grant SELECT on table public.study_roadmap_completion to service_role;
grant TRIGGER on table public.study_roadmap_completion to service_role;
grant TRUNCATE on table public.study_roadmap_completion to service_role;
grant UPDATE on table public.study_roadmap_completion to service_role;
grant DELETE on table public.class_resources to anon;
grant INSERT on table public.class_resources to anon;
grant MAINTAIN on table public.class_resources to anon;
grant REFERENCES on table public.class_resources to anon;
grant SELECT on table public.class_resources to anon;
grant TRIGGER on table public.class_resources to anon;
grant TRUNCATE on table public.class_resources to anon;
grant UPDATE on table public.class_resources to anon;
grant DELETE on table public.class_resources to authenticated;
grant INSERT on table public.class_resources to authenticated;
grant MAINTAIN on table public.class_resources to authenticated;
grant REFERENCES on table public.class_resources to authenticated;
grant SELECT on table public.class_resources to authenticated;
grant TRIGGER on table public.class_resources to authenticated;
grant TRUNCATE on table public.class_resources to authenticated;
grant UPDATE on table public.class_resources to authenticated;
grant DELETE on table public.class_resources to service_role;
grant INSERT on table public.class_resources to service_role;
grant MAINTAIN on table public.class_resources to service_role;
grant REFERENCES on table public.class_resources to service_role;
grant SELECT on table public.class_resources to service_role;
grant TRIGGER on table public.class_resources to service_role;
grant TRUNCATE on table public.class_resources to service_role;
grant UPDATE on table public.class_resources to service_role;
grant DELETE on table public.teacher_exercises to anon;
grant INSERT on table public.teacher_exercises to anon;
grant MAINTAIN on table public.teacher_exercises to anon;
grant REFERENCES on table public.teacher_exercises to anon;
grant SELECT on table public.teacher_exercises to anon;
grant TRIGGER on table public.teacher_exercises to anon;
grant TRUNCATE on table public.teacher_exercises to anon;
grant UPDATE on table public.teacher_exercises to anon;
grant DELETE on table public.teacher_exercises to authenticated;
grant INSERT on table public.teacher_exercises to authenticated;
grant MAINTAIN on table public.teacher_exercises to authenticated;
grant REFERENCES on table public.teacher_exercises to authenticated;
grant SELECT on table public.teacher_exercises to authenticated;
grant TRIGGER on table public.teacher_exercises to authenticated;
grant TRUNCATE on table public.teacher_exercises to authenticated;
grant UPDATE on table public.teacher_exercises to authenticated;
grant DELETE on table public.teacher_exercises to service_role;
grant INSERT on table public.teacher_exercises to service_role;
grant MAINTAIN on table public.teacher_exercises to service_role;
grant REFERENCES on table public.teacher_exercises to service_role;
grant SELECT on table public.teacher_exercises to service_role;
grant TRIGGER on table public.teacher_exercises to service_role;
grant TRUNCATE on table public.teacher_exercises to service_role;
grant UPDATE on table public.teacher_exercises to service_role;
grant DELETE on table public.teacher_classes to anon;
grant INSERT on table public.teacher_classes to anon;
grant MAINTAIN on table public.teacher_classes to anon;
grant REFERENCES on table public.teacher_classes to anon;
grant SELECT on table public.teacher_classes to anon;
grant TRIGGER on table public.teacher_classes to anon;
grant TRUNCATE on table public.teacher_classes to anon;
grant UPDATE on table public.teacher_classes to anon;
grant DELETE on table public.teacher_classes to authenticated;
grant INSERT on table public.teacher_classes to authenticated;
grant MAINTAIN on table public.teacher_classes to authenticated;
grant REFERENCES on table public.teacher_classes to authenticated;
grant SELECT on table public.teacher_classes to authenticated;
grant TRIGGER on table public.teacher_classes to authenticated;
grant TRUNCATE on table public.teacher_classes to authenticated;
grant UPDATE on table public.teacher_classes to authenticated;
grant DELETE on table public.teacher_classes to service_role;
grant INSERT on table public.teacher_classes to service_role;
grant MAINTAIN on table public.teacher_classes to service_role;
grant REFERENCES on table public.teacher_classes to service_role;
grant SELECT on table public.teacher_classes to service_role;
grant TRIGGER on table public.teacher_classes to service_role;
grant TRUNCATE on table public.teacher_classes to service_role;
grant UPDATE on table public.teacher_classes to service_role;
grant DELETE on table public.class_lesson_records to anon;
grant INSERT on table public.class_lesson_records to anon;
grant MAINTAIN on table public.class_lesson_records to anon;
grant REFERENCES on table public.class_lesson_records to anon;
grant SELECT on table public.class_lesson_records to anon;
grant TRIGGER on table public.class_lesson_records to anon;
grant TRUNCATE on table public.class_lesson_records to anon;
grant UPDATE on table public.class_lesson_records to anon;
grant DELETE on table public.class_lesson_records to authenticated;
grant INSERT on table public.class_lesson_records to authenticated;
grant MAINTAIN on table public.class_lesson_records to authenticated;
grant REFERENCES on table public.class_lesson_records to authenticated;
grant SELECT on table public.class_lesson_records to authenticated;
grant TRIGGER on table public.class_lesson_records to authenticated;
grant TRUNCATE on table public.class_lesson_records to authenticated;
grant UPDATE on table public.class_lesson_records to authenticated;
grant DELETE on table public.class_lesson_records to service_role;
grant INSERT on table public.class_lesson_records to service_role;
grant MAINTAIN on table public.class_lesson_records to service_role;
grant REFERENCES on table public.class_lesson_records to service_role;
grant SELECT on table public.class_lesson_records to service_role;
grant TRIGGER on table public.class_lesson_records to service_role;
grant TRUNCATE on table public.class_lesson_records to service_role;
grant UPDATE on table public.class_lesson_records to service_role;
grant DELETE on table public.student_private_data to anon;
grant INSERT on table public.student_private_data to anon;
grant MAINTAIN on table public.student_private_data to anon;
grant REFERENCES on table public.student_private_data to anon;
grant SELECT on table public.student_private_data to anon;
grant TRIGGER on table public.student_private_data to anon;
grant TRUNCATE on table public.student_private_data to anon;
grant UPDATE on table public.student_private_data to anon;
grant DELETE on table public.student_private_data to authenticated;
grant INSERT on table public.student_private_data to authenticated;
grant MAINTAIN on table public.student_private_data to authenticated;
grant REFERENCES on table public.student_private_data to authenticated;
grant SELECT on table public.student_private_data to authenticated;
grant TRIGGER on table public.student_private_data to authenticated;
grant TRUNCATE on table public.student_private_data to authenticated;
grant UPDATE on table public.student_private_data to authenticated;
grant DELETE on table public.student_private_data to service_role;
grant INSERT on table public.student_private_data to service_role;
grant MAINTAIN on table public.student_private_data to service_role;
grant REFERENCES on table public.student_private_data to service_role;
grant SELECT on table public.student_private_data to service_role;
grant TRIGGER on table public.student_private_data to service_role;
grant TRUNCATE on table public.student_private_data to service_role;
grant UPDATE on table public.student_private_data to service_role;
grant DELETE on table public.backup_profiles_20260501 to service_role;
grant INSERT on table public.backup_profiles_20260501 to service_role;
grant MAINTAIN on table public.backup_profiles_20260501 to service_role;
grant REFERENCES on table public.backup_profiles_20260501 to service_role;
grant SELECT on table public.backup_profiles_20260501 to service_role;
grant TRIGGER on table public.backup_profiles_20260501 to service_role;
grant TRUNCATE on table public.backup_profiles_20260501 to service_role;
grant UPDATE on table public.backup_profiles_20260501 to service_role;
grant DELETE on table public.backup_student_private_data_20260501 to service_role;
grant INSERT on table public.backup_student_private_data_20260501 to service_role;
grant MAINTAIN on table public.backup_student_private_data_20260501 to service_role;
grant REFERENCES on table public.backup_student_private_data_20260501 to service_role;
grant SELECT on table public.backup_student_private_data_20260501 to service_role;
grant TRIGGER on table public.backup_student_private_data_20260501 to service_role;
grant TRUNCATE on table public.backup_student_private_data_20260501 to service_role;
grant UPDATE on table public.backup_student_private_data_20260501 to service_role;
grant DELETE on table public.backup_auth_users_metadata_20260501 to service_role;
grant INSERT on table public.backup_auth_users_metadata_20260501 to service_role;
grant MAINTAIN on table public.backup_auth_users_metadata_20260501 to service_role;
grant REFERENCES on table public.backup_auth_users_metadata_20260501 to service_role;
grant SELECT on table public.backup_auth_users_metadata_20260501 to service_role;
grant TRIGGER on table public.backup_auth_users_metadata_20260501 to service_role;
grant TRUNCATE on table public.backup_auth_users_metadata_20260501 to service_role;
grant UPDATE on table public.backup_auth_users_metadata_20260501 to service_role;
grant DELETE on table public.grammar_lessons to anon;
grant INSERT on table public.grammar_lessons to anon;
grant MAINTAIN on table public.grammar_lessons to anon;
grant REFERENCES on table public.grammar_lessons to anon;
grant SELECT on table public.grammar_lessons to anon;
grant TRIGGER on table public.grammar_lessons to anon;
grant TRUNCATE on table public.grammar_lessons to anon;
grant UPDATE on table public.grammar_lessons to anon;
grant DELETE on table public.grammar_lessons to authenticated;
grant INSERT on table public.grammar_lessons to authenticated;
grant MAINTAIN on table public.grammar_lessons to authenticated;
grant REFERENCES on table public.grammar_lessons to authenticated;
grant SELECT on table public.grammar_lessons to authenticated;
grant TRIGGER on table public.grammar_lessons to authenticated;
grant TRUNCATE on table public.grammar_lessons to authenticated;
grant UPDATE on table public.grammar_lessons to authenticated;
grant DELETE on table public.grammar_lessons to service_role;
grant INSERT on table public.grammar_lessons to service_role;
grant MAINTAIN on table public.grammar_lessons to service_role;
grant REFERENCES on table public.grammar_lessons to service_role;
grant SELECT on table public.grammar_lessons to service_role;
grant TRIGGER on table public.grammar_lessons to service_role;
grant TRUNCATE on table public.grammar_lessons to service_role;
grant UPDATE on table public.grammar_lessons to service_role;
grant DELETE on table public.grammar_lesson_completion to anon;
grant INSERT on table public.grammar_lesson_completion to anon;
grant MAINTAIN on table public.grammar_lesson_completion to anon;
grant REFERENCES on table public.grammar_lesson_completion to anon;
grant SELECT on table public.grammar_lesson_completion to anon;
grant TRIGGER on table public.grammar_lesson_completion to anon;
grant TRUNCATE on table public.grammar_lesson_completion to anon;
grant UPDATE on table public.grammar_lesson_completion to anon;
grant DELETE on table public.grammar_lesson_completion to authenticated;
grant INSERT on table public.grammar_lesson_completion to authenticated;
grant MAINTAIN on table public.grammar_lesson_completion to authenticated;
grant REFERENCES on table public.grammar_lesson_completion to authenticated;
grant SELECT on table public.grammar_lesson_completion to authenticated;
grant TRIGGER on table public.grammar_lesson_completion to authenticated;
grant TRUNCATE on table public.grammar_lesson_completion to authenticated;
grant UPDATE on table public.grammar_lesson_completion to authenticated;
grant DELETE on table public.grammar_lesson_completion to service_role;
grant INSERT on table public.grammar_lesson_completion to service_role;
grant MAINTAIN on table public.grammar_lesson_completion to service_role;
grant REFERENCES on table public.grammar_lesson_completion to service_role;
grant SELECT on table public.grammar_lesson_completion to service_role;
grant TRIGGER on table public.grammar_lesson_completion to service_role;
grant TRUNCATE on table public.grammar_lesson_completion to service_role;
grant UPDATE on table public.grammar_lesson_completion to service_role;
grant DELETE on table public.student_enrollment_invites to anon;
grant INSERT on table public.student_enrollment_invites to anon;
grant MAINTAIN on table public.student_enrollment_invites to anon;
grant REFERENCES on table public.student_enrollment_invites to anon;
grant SELECT on table public.student_enrollment_invites to anon;
grant TRIGGER on table public.student_enrollment_invites to anon;
grant TRUNCATE on table public.student_enrollment_invites to anon;
grant UPDATE on table public.student_enrollment_invites to anon;
grant DELETE on table public.student_enrollment_invites to authenticated;
grant INSERT on table public.student_enrollment_invites to authenticated;
grant MAINTAIN on table public.student_enrollment_invites to authenticated;
grant REFERENCES on table public.student_enrollment_invites to authenticated;
grant SELECT on table public.student_enrollment_invites to authenticated;
grant TRIGGER on table public.student_enrollment_invites to authenticated;
grant TRUNCATE on table public.student_enrollment_invites to authenticated;
grant UPDATE on table public.student_enrollment_invites to authenticated;
grant DELETE on table public.student_enrollment_invites to service_role;
grant INSERT on table public.student_enrollment_invites to service_role;
grant MAINTAIN on table public.student_enrollment_invites to service_role;
grant REFERENCES on table public.student_enrollment_invites to service_role;
grant SELECT on table public.student_enrollment_invites to service_role;
grant TRIGGER on table public.student_enrollment_invites to service_role;
grant TRUNCATE on table public.student_enrollment_invites to service_role;
grant UPDATE on table public.student_enrollment_invites to service_role;
grant DELETE on table public.student_tags to anon;
grant INSERT on table public.student_tags to anon;
grant MAINTAIN on table public.student_tags to anon;
grant REFERENCES on table public.student_tags to anon;
grant SELECT on table public.student_tags to anon;
grant TRIGGER on table public.student_tags to anon;
grant TRUNCATE on table public.student_tags to anon;
grant UPDATE on table public.student_tags to anon;
grant DELETE on table public.student_tags to authenticated;
grant INSERT on table public.student_tags to authenticated;
grant MAINTAIN on table public.student_tags to authenticated;
grant REFERENCES on table public.student_tags to authenticated;
grant SELECT on table public.student_tags to authenticated;
grant TRIGGER on table public.student_tags to authenticated;
grant TRUNCATE on table public.student_tags to authenticated;
grant UPDATE on table public.student_tags to authenticated;
grant DELETE on table public.student_tags to service_role;
grant INSERT on table public.student_tags to service_role;
grant MAINTAIN on table public.student_tags to service_role;
grant REFERENCES on table public.student_tags to service_role;
grant SELECT on table public.student_tags to service_role;
grant TRIGGER on table public.student_tags to service_role;
grant TRUNCATE on table public.student_tags to service_role;
grant UPDATE on table public.student_tags to service_role;
grant DELETE on table public.student_billing_settings to authenticated;
grant INSERT on table public.student_billing_settings to authenticated;
grant MAINTAIN on table public.student_billing_settings to authenticated;
grant REFERENCES on table public.student_billing_settings to authenticated;
grant SELECT on table public.student_billing_settings to authenticated;
grant TRIGGER on table public.student_billing_settings to authenticated;
grant TRUNCATE on table public.student_billing_settings to authenticated;
grant UPDATE on table public.student_billing_settings to authenticated;
grant DELETE on table public.student_billing_settings to service_role;
grant INSERT on table public.student_billing_settings to service_role;
grant MAINTAIN on table public.student_billing_settings to service_role;
grant REFERENCES on table public.student_billing_settings to service_role;
grant SELECT on table public.student_billing_settings to service_role;
grant TRIGGER on table public.student_billing_settings to service_role;
grant TRUNCATE on table public.student_billing_settings to service_role;
grant UPDATE on table public.student_billing_settings to service_role;
grant DELETE on table public.monthly_tuition to authenticated;
grant INSERT on table public.monthly_tuition to authenticated;
grant MAINTAIN on table public.monthly_tuition to authenticated;
grant REFERENCES on table public.monthly_tuition to authenticated;
grant SELECT on table public.monthly_tuition to authenticated;
grant TRIGGER on table public.monthly_tuition to authenticated;
grant TRUNCATE on table public.monthly_tuition to authenticated;
grant UPDATE on table public.monthly_tuition to authenticated;
grant DELETE on table public.monthly_tuition to service_role;
grant INSERT on table public.monthly_tuition to service_role;
grant MAINTAIN on table public.monthly_tuition to service_role;
grant REFERENCES on table public.monthly_tuition to service_role;
grant SELECT on table public.monthly_tuition to service_role;
grant TRIGGER on table public.monthly_tuition to service_role;
grant TRUNCATE on table public.monthly_tuition to service_role;
grant UPDATE on table public.monthly_tuition to service_role;
grant DELETE on table public.monthly_tuition_events to authenticated;
grant INSERT on table public.monthly_tuition_events to authenticated;
grant MAINTAIN on table public.monthly_tuition_events to authenticated;
grant REFERENCES on table public.monthly_tuition_events to authenticated;
grant SELECT on table public.monthly_tuition_events to authenticated;
grant TRIGGER on table public.monthly_tuition_events to authenticated;
grant TRUNCATE on table public.monthly_tuition_events to authenticated;
grant UPDATE on table public.monthly_tuition_events to authenticated;
grant DELETE on table public.monthly_tuition_events to service_role;
grant INSERT on table public.monthly_tuition_events to service_role;
grant MAINTAIN on table public.monthly_tuition_events to service_role;
grant REFERENCES on table public.monthly_tuition_events to service_role;
grant SELECT on table public.monthly_tuition_events to service_role;
grant TRIGGER on table public.monthly_tuition_events to service_role;
grant TRUNCATE on table public.monthly_tuition_events to service_role;
grant UPDATE on table public.monthly_tuition_events to service_role;
grant SELECT on table public.enrollment_email_notifications to authenticated;
grant DELETE on table public.enrollment_email_notifications to service_role;
grant INSERT on table public.enrollment_email_notifications to service_role;
grant MAINTAIN on table public.enrollment_email_notifications to service_role;
grant REFERENCES on table public.enrollment_email_notifications to service_role;
grant SELECT on table public.enrollment_email_notifications to service_role;
grant TRIGGER on table public.enrollment_email_notifications to service_role;
grant TRUNCATE on table public.enrollment_email_notifications to service_role;
grant UPDATE on table public.enrollment_email_notifications to service_role;
grant DELETE on table public.makeup_class_slots to service_role;
grant INSERT on table public.makeup_class_slots to service_role;
grant MAINTAIN on table public.makeup_class_slots to service_role;
grant REFERENCES on table public.makeup_class_slots to service_role;
grant SELECT on table public.makeup_class_slots to service_role;
grant TRIGGER on table public.makeup_class_slots to service_role;
grant TRUNCATE on table public.makeup_class_slots to service_role;
grant UPDATE on table public.makeup_class_slots to service_role;
grant DELETE on table public.makeup_class_bookings to service_role;
grant INSERT on table public.makeup_class_bookings to service_role;
grant MAINTAIN on table public.makeup_class_bookings to service_role;
grant REFERENCES on table public.makeup_class_bookings to service_role;
grant SELECT on table public.makeup_class_bookings to service_role;
grant TRIGGER on table public.makeup_class_bookings to service_role;
grant TRUNCATE on table public.makeup_class_bookings to service_role;
grant UPDATE on table public.makeup_class_bookings to service_role;
grant SELECT on table public.makeup_class_email_notifications to authenticated;
grant DELETE on table public.makeup_class_email_notifications to service_role;
grant INSERT on table public.makeup_class_email_notifications to service_role;
grant MAINTAIN on table public.makeup_class_email_notifications to service_role;
grant REFERENCES on table public.makeup_class_email_notifications to service_role;
grant SELECT on table public.makeup_class_email_notifications to service_role;
grant TRIGGER on table public.makeup_class_email_notifications to service_role;
grant TRUNCATE on table public.makeup_class_email_notifications to service_role;
grant UPDATE on table public.makeup_class_email_notifications to service_role;
grant SELECT on table public.student_access_logs to authenticated;
grant DELETE on table public.student_access_logs to service_role;
grant INSERT on table public.student_access_logs to service_role;
grant MAINTAIN on table public.student_access_logs to service_role;
grant REFERENCES on table public.student_access_logs to service_role;
grant SELECT on table public.student_access_logs to service_role;
grant TRIGGER on table public.student_access_logs to service_role;
grant TRUNCATE on table public.student_access_logs to service_role;
grant UPDATE on table public.student_access_logs to service_role;
grant DELETE on table public.flashcard_decks to authenticated;
grant INSERT on table public.flashcard_decks to authenticated;
grant MAINTAIN on table public.flashcard_decks to authenticated;
grant REFERENCES on table public.flashcard_decks to authenticated;
grant SELECT on table public.flashcard_decks to authenticated;
grant TRIGGER on table public.flashcard_decks to authenticated;
grant TRUNCATE on table public.flashcard_decks to authenticated;
grant UPDATE on table public.flashcard_decks to authenticated;
grant DELETE on table public.flashcard_decks to service_role;
grant INSERT on table public.flashcard_decks to service_role;
grant MAINTAIN on table public.flashcard_decks to service_role;
grant REFERENCES on table public.flashcard_decks to service_role;
grant SELECT on table public.flashcard_decks to service_role;
grant TRIGGER on table public.flashcard_decks to service_role;
grant TRUNCATE on table public.flashcard_decks to service_role;
grant UPDATE on table public.flashcard_decks to service_role;
grant DELETE on table public.flashcards to authenticated;
grant INSERT on table public.flashcards to authenticated;
grant MAINTAIN on table public.flashcards to authenticated;
grant REFERENCES on table public.flashcards to authenticated;
grant SELECT on table public.flashcards to authenticated;
grant TRIGGER on table public.flashcards to authenticated;
grant TRUNCATE on table public.flashcards to authenticated;
grant UPDATE on table public.flashcards to authenticated;
grant DELETE on table public.flashcards to service_role;
grant INSERT on table public.flashcards to service_role;
grant MAINTAIN on table public.flashcards to service_role;
grant REFERENCES on table public.flashcards to service_role;
grant SELECT on table public.flashcards to service_role;
grant TRIGGER on table public.flashcards to service_role;
grant TRUNCATE on table public.flashcards to service_role;
grant UPDATE on table public.flashcards to service_role;
grant INSERT on table public.flashcard_practice_days to authenticated;
grant SELECT on table public.flashcard_practice_days to authenticated;
grant DELETE on table public.flashcard_practice_days to service_role;
grant INSERT on table public.flashcard_practice_days to service_role;
grant MAINTAIN on table public.flashcard_practice_days to service_role;
grant REFERENCES on table public.flashcard_practice_days to service_role;
grant SELECT on table public.flashcard_practice_days to service_role;
grant TRIGGER on table public.flashcard_practice_days to service_role;
grant TRUNCATE on table public.flashcard_practice_days to service_role;
grant UPDATE on table public.flashcard_practice_days to service_role;
grant SELECT on table public.exercise_sync_runs to authenticated;
grant DELETE on table public.exercise_sync_runs to service_role;
grant INSERT on table public.exercise_sync_runs to service_role;
grant MAINTAIN on table public.exercise_sync_runs to service_role;
grant REFERENCES on table public.exercise_sync_runs to service_role;
grant SELECT on table public.exercise_sync_runs to service_role;
grant TRIGGER on table public.exercise_sync_runs to service_role;
grant TRUNCATE on table public.exercise_sync_runs to service_role;
grant UPDATE on table public.exercise_sync_runs to service_role;
grant SELECT on table public.weekly_plan_snapshots to authenticated;
grant DELETE on table public.weekly_plan_snapshots to service_role;
grant INSERT on table public.weekly_plan_snapshots to service_role;
grant MAINTAIN on table public.weekly_plan_snapshots to service_role;
grant REFERENCES on table public.weekly_plan_snapshots to service_role;
grant SELECT on table public.weekly_plan_snapshots to service_role;
grant TRIGGER on table public.weekly_plan_snapshots to service_role;
grant TRUNCATE on table public.weekly_plan_snapshots to service_role;
grant UPDATE on table public.weekly_plan_snapshots to service_role;
grant DELETE on table public.weekly_student_tasks to authenticated;
grant INSERT on table public.weekly_student_tasks to authenticated;
grant SELECT on table public.weekly_student_tasks to authenticated;
grant UPDATE on table public.weekly_student_tasks to authenticated;
grant DELETE on table public.weekly_student_tasks to service_role;
grant INSERT on table public.weekly_student_tasks to service_role;
grant MAINTAIN on table public.weekly_student_tasks to service_role;
grant REFERENCES on table public.weekly_student_tasks to service_role;
grant SELECT on table public.weekly_student_tasks to service_role;
grant TRIGGER on table public.weekly_student_tasks to service_role;
grant TRUNCATE on table public.weekly_student_tasks to service_role;
grant UPDATE on table public.weekly_student_tasks to service_role;
grant DELETE on table public.exercise_form_sources to service_role;
grant INSERT on table public.exercise_form_sources to service_role;
grant MAINTAIN on table public.exercise_form_sources to service_role;
grant REFERENCES on table public.exercise_form_sources to service_role;
grant SELECT on table public.exercise_form_sources to service_role;
grant TRIGGER on table public.exercise_form_sources to service_role;
grant TRUNCATE on table public.exercise_form_sources to service_role;
grant UPDATE on table public.exercise_form_sources to service_role;
grant DELETE on table public.tuition_payment_attempts to service_role;
grant INSERT on table public.tuition_payment_attempts to service_role;
grant MAINTAIN on table public.tuition_payment_attempts to service_role;
grant REFERENCES on table public.tuition_payment_attempts to service_role;
grant SELECT on table public.tuition_payment_attempts to service_role;
grant TRIGGER on table public.tuition_payment_attempts to service_role;
grant TRUNCATE on table public.tuition_payment_attempts to service_role;
grant UPDATE on table public.tuition_payment_attempts to service_role;
grant DELETE on table public.pronunciation_assignments to anon;
grant INSERT on table public.pronunciation_assignments to anon;
grant MAINTAIN on table public.pronunciation_assignments to anon;
grant REFERENCES on table public.pronunciation_assignments to anon;
grant SELECT on table public.pronunciation_assignments to anon;
grant TRIGGER on table public.pronunciation_assignments to anon;
grant TRUNCATE on table public.pronunciation_assignments to anon;
grant UPDATE on table public.pronunciation_assignments to anon;
grant DELETE on table public.pronunciation_assignments to authenticated;
grant INSERT on table public.pronunciation_assignments to authenticated;
grant MAINTAIN on table public.pronunciation_assignments to authenticated;
grant REFERENCES on table public.pronunciation_assignments to authenticated;
grant SELECT on table public.pronunciation_assignments to authenticated;
grant TRIGGER on table public.pronunciation_assignments to authenticated;
grant TRUNCATE on table public.pronunciation_assignments to authenticated;
grant UPDATE on table public.pronunciation_assignments to authenticated;
grant DELETE on table public.pronunciation_assignments to service_role;
grant INSERT on table public.pronunciation_assignments to service_role;
grant MAINTAIN on table public.pronunciation_assignments to service_role;
grant REFERENCES on table public.pronunciation_assignments to service_role;
grant SELECT on table public.pronunciation_assignments to service_role;
grant TRIGGER on table public.pronunciation_assignments to service_role;
grant TRUNCATE on table public.pronunciation_assignments to service_role;
grant UPDATE on table public.pronunciation_assignments to service_role;
grant DELETE on table public.pronunciation_attempts to anon;
grant INSERT on table public.pronunciation_attempts to anon;
grant MAINTAIN on table public.pronunciation_attempts to anon;
grant REFERENCES on table public.pronunciation_attempts to anon;
grant SELECT on table public.pronunciation_attempts to anon;
grant TRIGGER on table public.pronunciation_attempts to anon;
grant TRUNCATE on table public.pronunciation_attempts to anon;
grant UPDATE on table public.pronunciation_attempts to anon;
grant DELETE on table public.pronunciation_attempts to authenticated;
grant INSERT on table public.pronunciation_attempts to authenticated;
grant MAINTAIN on table public.pronunciation_attempts to authenticated;
grant REFERENCES on table public.pronunciation_attempts to authenticated;
grant SELECT on table public.pronunciation_attempts to authenticated;
grant TRIGGER on table public.pronunciation_attempts to authenticated;
grant TRUNCATE on table public.pronunciation_attempts to authenticated;
grant UPDATE on table public.pronunciation_attempts to authenticated;
grant DELETE on table public.pronunciation_attempts to service_role;
grant INSERT on table public.pronunciation_attempts to service_role;
grant MAINTAIN on table public.pronunciation_attempts to service_role;
grant REFERENCES on table public.pronunciation_attempts to service_role;
grant SELECT on table public.pronunciation_attempts to service_role;
grant TRIGGER on table public.pronunciation_attempts to service_role;
grant TRUNCATE on table public.pronunciation_attempts to service_role;
grant UPDATE on table public.pronunciation_attempts to service_role;
grant MAINTAIN on table public.exercise_sync_events to authenticated;
grant REFERENCES on table public.exercise_sync_events to authenticated;
grant SELECT on table public.exercise_sync_events to authenticated;
grant TRIGGER on table public.exercise_sync_events to authenticated;
grant TRUNCATE on table public.exercise_sync_events to authenticated;
grant DELETE on table public.exercise_sync_events to service_role;
grant INSERT on table public.exercise_sync_events to service_role;
grant MAINTAIN on table public.exercise_sync_events to service_role;
grant REFERENCES on table public.exercise_sync_events to service_role;
grant SELECT on table public.exercise_sync_events to service_role;
grant TRIGGER on table public.exercise_sync_events to service_role;
grant TRUNCATE on table public.exercise_sync_events to service_role;
grant UPDATE on table public.exercise_sync_events to service_role;
grant DELETE on table public.student_google_email_aliases to service_role;
grant INSERT on table public.student_google_email_aliases to service_role;
grant MAINTAIN on table public.student_google_email_aliases to service_role;
grant REFERENCES on table public.student_google_email_aliases to service_role;
grant SELECT on table public.student_google_email_aliases to service_role;
grant TRIGGER on table public.student_google_email_aliases to service_role;
grant TRUNCATE on table public.student_google_email_aliases to service_role;
grant UPDATE on table public.student_google_email_aliases to service_role;
grant DELETE on table public.student_google_account_links to service_role;
grant INSERT on table public.student_google_account_links to service_role;
grant MAINTAIN on table public.student_google_account_links to service_role;
grant REFERENCES on table public.student_google_account_links to service_role;
grant SELECT on table public.student_google_account_links to service_role;
grant TRIGGER on table public.student_google_account_links to service_role;
grant TRUNCATE on table public.student_google_account_links to service_role;
grant UPDATE on table public.student_google_account_links to service_role;
grant DELETE on table public.api_rate_limit_buckets to service_role;
grant INSERT on table public.api_rate_limit_buckets to service_role;
grant MAINTAIN on table public.api_rate_limit_buckets to service_role;
grant REFERENCES on table public.api_rate_limit_buckets to service_role;
grant SELECT on table public.api_rate_limit_buckets to service_role;
grant TRIGGER on table public.api_rate_limit_buckets to service_role;
grant TRUNCATE on table public.api_rate_limit_buckets to service_role;
grant UPDATE on table public.api_rate_limit_buckets to service_role;
grant INSERT on table public.flashcard_srs to authenticated;
grant SELECT on table public.flashcard_srs to authenticated;
grant UPDATE on table public.flashcard_srs to authenticated;
grant DELETE on table public.flashcard_srs to service_role;
grant INSERT on table public.flashcard_srs to service_role;
grant MAINTAIN on table public.flashcard_srs to service_role;
grant REFERENCES on table public.flashcard_srs to service_role;
grant SELECT on table public.flashcard_srs to service_role;
grant TRIGGER on table public.flashcard_srs to service_role;
grant TRUNCATE on table public.flashcard_srs to service_role;
grant UPDATE on table public.flashcard_srs to service_role;
grant INSERT on table public.flashcard_review_history to authenticated;
grant SELECT on table public.flashcard_review_history to authenticated;
grant DELETE on table public.flashcard_review_history to service_role;
grant INSERT on table public.flashcard_review_history to service_role;
grant MAINTAIN on table public.flashcard_review_history to service_role;
grant REFERENCES on table public.flashcard_review_history to service_role;
grant SELECT on table public.flashcard_review_history to service_role;
grant TRIGGER on table public.flashcard_review_history to service_role;
grant TRUNCATE on table public.flashcard_review_history to service_role;
grant UPDATE on table public.flashcard_review_history to service_role;
grant DELETE on table public.csp_violation_reports to service_role;
grant INSERT on table public.csp_violation_reports to service_role;
grant MAINTAIN on table public.csp_violation_reports to service_role;
grant REFERENCES on table public.csp_violation_reports to service_role;
grant SELECT on table public.csp_violation_reports to service_role;
grant TRIGGER on table public.csp_violation_reports to service_role;
grant TRUNCATE on table public.csp_violation_reports to service_role;
grant UPDATE on table public.csp_violation_reports to service_role;
grant SELECT on table public.app_error_events to authenticated;
grant DELETE on table public.app_error_events to service_role;
grant INSERT on table public.app_error_events to service_role;
grant MAINTAIN on table public.app_error_events to service_role;
grant REFERENCES on table public.app_error_events to service_role;
grant SELECT on table public.app_error_events to service_role;
grant TRIGGER on table public.app_error_events to service_role;
grant TRUNCATE on table public.app_error_events to service_role;
grant UPDATE on table public.app_error_events to service_role;

-- Column grants
grant UPDATE (resolved_at) on table public.app_error_events to authenticated;


-- Function grants
revoke all on function public.rls_auto_enable() from public, anon, authenticated, service_role;
revoke all on function public.set_updated_at() from public, anon, authenticated, service_role;
revoke all on function public.delete_teacher_student(target_user_id uuid) from public, anon, authenticated, service_role;
revoke all on function public.get_teacher_student_frequency(target_user_id uuid) from public, anon, authenticated, service_role;
revoke all on function public.save_teacher_student_frequency(target_user_id uuid, target_class_date date, target_attendance_status text, target_class_notes text) from public, anon, authenticated, service_role;
revoke all on function public.is_teacher_admin() from public, anon, authenticated, service_role;
revoke all on function public.update_teacher_student_frequency(target_frequency_id uuid, target_class_date date, target_attendance_status text, target_class_notes text) from public, anon, authenticated, service_role;
revoke all on function public.delete_teacher_student_frequency(target_frequency_id uuid) from public, anon, authenticated, service_role;
revoke all on function public.set_daily_exercise_completion_updated_at() from public, anon, authenticated, service_role;
revoke all on function public.get_teacher_daily_exercise_completion() from public, anon, authenticated, service_role;
revoke all on function public.set_study_roadmap_completion_updated_at() from public, anon, authenticated, service_role;
revoke all on function public.set_class_resources_updated_at() from public, anon, authenticated, service_role;
revoke all on function public.set_teacher_exercises_updated_at() from public, anon, authenticated, service_role;
revoke all on function public.update_teacher_student_profile(target_user_id uuid, target_name text, target_email text, target_cpf text, target_whatsapp text, target_pix_key text, target_enrollment_code text, target_availability jsonb) from public, anon, authenticated, service_role;
revoke all on function public.save_teacher_class_lesson_record(target_class_number integer, target_user_id uuid, target_class_date date, target_lesson_code text) from public, anon, authenticated, service_role;
revoke all on function public.get_my_lesson_records() from public, anon, authenticated, service_role;
revoke all on function public.save_teacher_class_resources(target_class_number integer, target_video_lesson_url text, target_lesson_material_url text, target_recorded_lessons_url text, target_whatsapp_group_url text) from public, anon, authenticated, service_role;
revoke all on function public.set_student_private_data_updated_at() from public, anon, authenticated, service_role;
revoke all on function public.upsert_my_private_student_data(target_cpf text, target_whatsapp text, target_pix_key text, target_consent_lgpd boolean) from public, anon, authenticated, service_role;
revoke all on function public.get_my_private_student_data() from public, anon, authenticated, service_role;
revoke all on function public.get_teacher_private_student_data() from public, anon, authenticated, service_role;
revoke all on function public.assert_teacher_class_exists(target_class_number integer) from public, anon, authenticated, service_role;
revoke all on function public.get_teacher_classes() from public, anon, authenticated, service_role;
revoke all on function public.create_teacher_class(target_class_name text) from public, anon, authenticated, service_role;
revoke all on function public.delete_teacher_class(target_class_number integer) from public, anon, authenticated, service_role;
revoke all on function public.save_teacher_class_resources(target_class_number integer, target_video_lesson_url text, target_lesson_material_url text, target_whatsapp_group_url text) from public, anon, authenticated, service_role;
revoke all on function public.add_teacher_class_student(target_class_number integer, target_user_id uuid) from public, anon, authenticated, service_role;
revoke all on function public.remove_teacher_class_student(target_class_number integer, target_user_id uuid) from public, anon, authenticated, service_role;
revoke all on function public.save_teacher_class_attendance(target_class_number integer, target_class_date date, target_general_notes text, attendance_records jsonb) from public, anon, authenticated, service_role;
revoke all on function public.get_enrollment_invite_by_code(target_invite_code text) from public, anon, authenticated, service_role;
revoke all on function public.complete_enrollment_invite(target_invite_code text, target_name text, target_cpf text, target_whatsapp text, target_pix_key text, target_availability jsonb) from public, anon, authenticated, service_role;
revoke all on function public.get_teacher_class_students(target_class_number integer) from public, anon, authenticated, service_role;
revoke all on function public.add_teacher_class_student_by_ref(target_class_number integer, target_student_ref_id text, target_student_ref_type text) from public, anon, authenticated, service_role;
revoke all on function public.remove_teacher_class_student_by_ref(target_class_number integer, target_student_ref_id text, target_student_ref_type text) from public, anon, authenticated, service_role;
revoke all on function public.get_teacher_class_activity_history(target_class_number integer) from public, anon, authenticated, service_role;
revoke all on function public.save_teacher_class_attendance_by_ref(target_class_number integer, target_class_date date, target_general_notes text, attendance_records jsonb) from public, anon, authenticated, service_role;
revoke all on function public.migrate_invite_records_to_user() from public, anon, authenticated, service_role;
revoke all on function public.get_teacher_student_tags() from public, anon, authenticated, service_role;
revoke all on function public.toggle_teacher_student_tag(target_student_ref_id text, target_student_ref_type text, target_tag_name text) from public, anon, authenticated, service_role;
revoke all on function public.migrate_invite_student_tags_to_user() from public, anon, authenticated, service_role;
revoke all on function public.get_teacher_class_lesson_records(target_class_number integer) from public, anon, authenticated, service_role;
revoke all on function public.save_teacher_class_lesson_record_by_ref(target_class_number integer, target_student_ref_id text, target_student_ref_type text, target_class_date date, target_lesson_code text) from public, anon, authenticated, service_role;
revoke all on function public.get_teacher_class_resources(target_class_number integer) from public, anon, authenticated, service_role;
revoke all on function public.get_my_student_class() from public, anon, authenticated, service_role;
revoke all on function public.save_teacher_classes_order(classes_order jsonb) from public, anon, authenticated, service_role;
revoke all on function public.create_teacher_exercise(target_exercise_id text, target_exercise_title text, target_exercise_url text, target_scheduled_publish_at timestamp with time zone) from public, anon, authenticated, service_role;
revoke all on function public.get_teacher_created_exercises() from public, anon, authenticated, service_role;
revoke all on function public.delete_teacher_exercise(target_id uuid) from public, anon, authenticated, service_role;
revoke all on function public.get_public_teacher_exercises() from public, anon, authenticated, service_role;
revoke all on function public.get_teacher_students() from public, anon, authenticated, service_role;
revoke all on function public.get_teacher_billing_students() from public, anon, authenticated, service_role;
revoke all on function public.save_student_billing_settings(target_student_id uuid, target_monthly_fee numeric, target_due_day integer, target_billing_start_month date, target_active boolean, target_notes text) from public, anon, authenticated, service_role;
revoke all on function public.generate_monthly_tuition(target_reference_month date) from public, anon, authenticated, service_role;
revoke all on function public.get_teacher_monthly_tuition(target_reference_month date) from public, anon, authenticated, service_role;
revoke all on function public.get_teacher_student_tuition_history(target_student_id uuid) from public, anon, authenticated, service_role;
revoke all on function public.record_tuition_payment(target_tuition_id uuid, target_payment_date date, target_amount_paid numeric, target_payment_method text, target_payment_notes text) from public, anon, authenticated, service_role;
revoke all on function public.reverse_tuition_payment(target_tuition_id uuid, target_reason text) from public, anon, authenticated, service_role;
revoke all on function public.sync_enrolled_auth_profile(target_user_id uuid, target_email text, target_metadata jsonb) from public, anon, authenticated, service_role;
revoke all on function public.handle_enrolled_auth_user_profile() from public, anon, authenticated, service_role;
revoke all on function public.queue_enrollment_email_notification() from public, anon, authenticated, service_role;
revoke all on function public.book_makeup_class(target_slot_id uuid) from public, anon, authenticated, service_role;
revoke all on function public.get_my_makeup_bookings() from public, anon, authenticated, service_role;
revoke all on function public.get_teacher_makeup_bookings() from public, anon, authenticated, service_role;
revoke all on function public.cancel_makeup_class_slot(target_slot_id uuid) from public, anon, authenticated, service_role;
revoke all on function public.cancel_makeup_class_booking(target_booking_id uuid) from public, anon, authenticated, service_role;
revoke all on function public.get_teacher_makeup_classes() from public, anon, authenticated, service_role;
revoke all on function public.create_makeup_class_slot(target_class_number integer, target_date date, target_start_time time without time zone, target_end_time time without time zone, target_capacity integer, target_notes text) from public, anon, authenticated, service_role;
revoke all on function public.get_available_makeup_slots() from public, anon, authenticated, service_role;
revoke all on function public.cancel_my_makeup_class_booking(target_booking_id uuid) from public, anon, authenticated, service_role;
revoke all on function public.get_teacher_makeup_slots() from public, anon, authenticated, service_role;
revoke all on function public.log_student_page_access(target_page_path text, target_page_title text, target_timezone text) from public, anon, authenticated, service_role;
revoke all on function public.get_teacher_student_accesses(target_days integer, target_user_id uuid) from public, anon, authenticated, service_role;
revoke all on function public.set_flashcards_updated_at() from public, anon, authenticated, service_role;
revoke all on function public.save_flashcard_deck(p_deck_id uuid, p_title text, p_description text, p_is_shared boolean, p_cards jsonb) from public, anon, authenticated, service_role;
revoke all on function public.save_flashcard_deck(p_deck_id uuid, p_owner_id uuid, p_title text, p_description text, p_cards jsonb) from public, anon, authenticated, service_role;
revoke all on function public.record_flashcard_practice_day() from public, anon, authenticated, service_role;
revoke all on function public.get_teacher_weekly_exercise_status() from public, anon, authenticated, service_role;
revoke all on function public.set_daily_exercise_completion_actor() from public, anon, authenticated, service_role;
revoke all on function public.get_teacher_student_exercise_completion(target_user_id uuid) from public, anon, authenticated, service_role;
revoke all on function public.set_teacher_student_exercise_completion(target_user_id uuid, target_exercise_id text, target_completed boolean, target_completed_at timestamp with time zone) from public, anon, authenticated, service_role;
revoke all on function public.set_exercise_schedule_start_date() from public, anon, authenticated, service_role;
revoke all on function public.archive_teacher_student(target_user_id uuid) from public, anon, authenticated, service_role;
revoke all on function public.unarchive_teacher_student(target_user_id uuid) from public, anon, authenticated, service_role;
revoke all on function public.ensure_weekly_plan_snapshot(target_user_id uuid) from public, anon, authenticated, service_role;
revoke all on function public.set_my_weekly_task_completed(target_task_id uuid, target_completed boolean) from public, anon, authenticated, service_role;
revoke all on function public.get_teacher_classes_with_type() from public, anon, authenticated, service_role;
revoke all on function public.create_teacher_class_with_type(target_class_name text, target_class_type text) from public, anon, authenticated, service_role;
revoke all on function public.set_teacher_class_type(target_class_number integer, target_class_type text) from public, anon, authenticated, service_role;
revoke all on function public.get_group_classes_with_available_spots() from public, anon, authenticated, service_role;
revoke all on function public.get_available_group_classes_for_students() from public, anon, authenticated, service_role;
revoke all on function public.switch_my_group_class(target_class_number integer) from public, anon, authenticated, service_role;
revoke all on function public.enforce_class_students_capacity() from public, anon, authenticated, service_role;
revoke all on function public.sync_auto_makeup_slots_30_days() from public, anon, authenticated, service_role;
revoke all on function public.enforce_makeup_slots_enabled() from public, anon, authenticated, service_role;
revoke all on function public.get_google_form_integrations() from public, anon, authenticated, service_role;
revoke all on function public.upsert_google_form_integration(target_exercise_id text, target_spreadsheet_url text, target_import_existing boolean) from public, anon, authenticated, service_role;
revoke all on function public.retry_google_form_integration(target_id uuid) from public, anon, authenticated, service_role;
revoke all on function public.disconnect_google_form_integration(target_id uuid) from public, anon, authenticated, service_role;
revoke all on function public.set_tuition_payment_attempt_updated_at() from public, anon, authenticated, service_role;
revoke all on function public.get_my_pending_tuitions() from public, anon, authenticated, service_role;
revoke all on function public.process_mercado_pago_payment(target_attempt_id uuid, target_provider_payment_id text, target_status text, target_status_detail text, target_amount numeric, target_payment_method text, target_live_mode boolean, target_provider_created_at timestamp with time zone, target_provider_updated_at timestamp with time zone, target_approved_at timestamp with time zone) from public, anon, authenticated, service_role;
revoke all on function public.get_student_login_route_internal(target_email text) from public, anon, authenticated, service_role;
revoke all on function public.get_teacher_student_access_statuses() from public, anon, authenticated, service_role;
revoke all on function public.sync_student_portal_access_status() from public, anon, authenticated, service_role;
revoke all on function public.delete_teacher_class_lesson_record(target_record_id uuid) from public, anon, authenticated, service_role;
revoke all on function public.get_student_google_link_candidate_internal(target_google_user_id uuid, target_google_email text) from public, anon, authenticated, service_role;
revoke all on function public.confirm_or_migrate_student_google_link_internal(target_google_user_id uuid, target_legacy_user_id uuid, target_google_email text) from public, anon, authenticated, service_role;
revoke all on function public.preserve_linked_student_enrollment_email() from public, anon, authenticated, service_role;
revoke all on function public.normalize_profile_enrollment_code() from public, anon, authenticated, service_role;
revoke all on function public.activate_completed_google_student_profile() from public, anon, authenticated, service_role;
revoke all on function public.consume_api_rate_limit(target_bucket_key text, target_window_seconds integer, target_max_requests integer) from public, anon, authenticated, service_role;
revoke all on function public.protect_profile_security_fields() from public, anon, authenticated, service_role;
revoke all on function public.record_flashcard_review(p_card_id uuid, p_grade text) from public, anon, authenticated, service_role;
revoke all on function public.prevent_new_duplicate_profile_cpf() from public, anon, authenticated, service_role;
revoke all on function public.prune_app_error_events(target_days integer) from public, anon, authenticated, service_role;
revoke all on function public.dispatch_makeup_notification_webhook() from public, anon, authenticated, service_role;
grant execute on function public.rls_auto_enable() to service_role;
grant execute on function public.set_updated_at() to service_role;
grant execute on function public.delete_teacher_student(target_user_id uuid) to authenticated;
grant execute on function public.delete_teacher_student(target_user_id uuid) to service_role;
grant execute on function public.get_teacher_student_frequency(target_user_id uuid) to service_role;
grant execute on function public.save_teacher_student_frequency(target_user_id uuid, target_class_date date, target_attendance_status text, target_class_notes text) to service_role;
grant execute on function public.is_teacher_admin() to authenticated;
grant execute on function public.is_teacher_admin() to service_role;
grant execute on function public.update_teacher_student_frequency(target_frequency_id uuid, target_class_date date, target_attendance_status text, target_class_notes text) to service_role;
grant execute on function public.delete_teacher_student_frequency(target_frequency_id uuid) to service_role;
grant execute on function public.set_daily_exercise_completion_updated_at() to service_role;
grant execute on function public.get_teacher_daily_exercise_completion() to authenticated;
grant execute on function public.get_teacher_daily_exercise_completion() to service_role;
grant execute on function public.set_study_roadmap_completion_updated_at() to service_role;
grant execute on function public.set_class_resources_updated_at() to service_role;
grant execute on function public.set_teacher_exercises_updated_at() to service_role;
grant execute on function public.update_teacher_student_profile(target_user_id uuid, target_name text, target_email text, target_cpf text, target_whatsapp text, target_pix_key text, target_enrollment_code text, target_availability jsonb) to authenticated;
grant execute on function public.update_teacher_student_profile(target_user_id uuid, target_name text, target_email text, target_cpf text, target_whatsapp text, target_pix_key text, target_enrollment_code text, target_availability jsonb) to service_role;
grant execute on function public.save_teacher_class_lesson_record(target_class_number integer, target_user_id uuid, target_class_date date, target_lesson_code text) to service_role;
grant execute on function public.get_my_lesson_records() to authenticated;
grant execute on function public.get_my_lesson_records() to service_role;
grant execute on function public.save_teacher_class_resources(target_class_number integer, target_video_lesson_url text, target_lesson_material_url text, target_recorded_lessons_url text, target_whatsapp_group_url text) to authenticated;
grant execute on function public.save_teacher_class_resources(target_class_number integer, target_video_lesson_url text, target_lesson_material_url text, target_recorded_lessons_url text, target_whatsapp_group_url text) to service_role;
grant execute on function public.set_student_private_data_updated_at() to service_role;
grant execute on function public.upsert_my_private_student_data(target_cpf text, target_whatsapp text, target_pix_key text, target_consent_lgpd boolean) to authenticated;
grant execute on function public.upsert_my_private_student_data(target_cpf text, target_whatsapp text, target_pix_key text, target_consent_lgpd boolean) to service_role;
grant execute on function public.get_my_private_student_data() to authenticated;
grant execute on function public.get_my_private_student_data() to service_role;
grant execute on function public.get_teacher_private_student_data() to authenticated;
grant execute on function public.get_teacher_private_student_data() to service_role;
grant execute on function public.assert_teacher_class_exists(target_class_number integer) to service_role;
grant execute on function public.get_teacher_classes() to authenticated;
grant execute on function public.get_teacher_classes() to service_role;
grant execute on function public.create_teacher_class(target_class_name text) to authenticated;
grant execute on function public.create_teacher_class(target_class_name text) to service_role;
grant execute on function public.delete_teacher_class(target_class_number integer) to authenticated;
grant execute on function public.delete_teacher_class(target_class_number integer) to service_role;
grant execute on function public.save_teacher_class_resources(target_class_number integer, target_video_lesson_url text, target_lesson_material_url text, target_whatsapp_group_url text) to service_role;
grant execute on function public.add_teacher_class_student(target_class_number integer, target_user_id uuid) to service_role;
grant execute on function public.remove_teacher_class_student(target_class_number integer, target_user_id uuid) to service_role;
grant execute on function public.save_teacher_class_attendance(target_class_number integer, target_class_date date, target_general_notes text, attendance_records jsonb) to service_role;
grant execute on function public.get_enrollment_invite_by_code(target_invite_code text) to service_role;
grant execute on function public.complete_enrollment_invite(target_invite_code text, target_name text, target_cpf text, target_whatsapp text, target_pix_key text, target_availability jsonb) to service_role;
grant execute on function public.get_teacher_class_students(target_class_number integer) to authenticated;
grant execute on function public.get_teacher_class_students(target_class_number integer) to service_role;
grant execute on function public.add_teacher_class_student_by_ref(target_class_number integer, target_student_ref_id text, target_student_ref_type text) to authenticated;
grant execute on function public.add_teacher_class_student_by_ref(target_class_number integer, target_student_ref_id text, target_student_ref_type text) to service_role;
grant execute on function public.remove_teacher_class_student_by_ref(target_class_number integer, target_student_ref_id text, target_student_ref_type text) to authenticated;
grant execute on function public.remove_teacher_class_student_by_ref(target_class_number integer, target_student_ref_id text, target_student_ref_type text) to service_role;
grant execute on function public.get_teacher_class_activity_history(target_class_number integer) to authenticated;
grant execute on function public.get_teacher_class_activity_history(target_class_number integer) to service_role;
grant execute on function public.save_teacher_class_attendance_by_ref(target_class_number integer, target_class_date date, target_general_notes text, attendance_records jsonb) to authenticated;
grant execute on function public.save_teacher_class_attendance_by_ref(target_class_number integer, target_class_date date, target_general_notes text, attendance_records jsonb) to service_role;
grant execute on function public.migrate_invite_records_to_user() to service_role;
grant execute on function public.get_teacher_student_tags() to authenticated;
grant execute on function public.get_teacher_student_tags() to service_role;
grant execute on function public.toggle_teacher_student_tag(target_student_ref_id text, target_student_ref_type text, target_tag_name text) to authenticated;
grant execute on function public.toggle_teacher_student_tag(target_student_ref_id text, target_student_ref_type text, target_tag_name text) to service_role;
grant execute on function public.migrate_invite_student_tags_to_user() to service_role;
grant execute on function public.get_teacher_class_lesson_records(target_class_number integer) to authenticated;
grant execute on function public.get_teacher_class_lesson_records(target_class_number integer) to service_role;
grant execute on function public.save_teacher_class_lesson_record_by_ref(target_class_number integer, target_student_ref_id text, target_student_ref_type text, target_class_date date, target_lesson_code text) to authenticated;
grant execute on function public.save_teacher_class_lesson_record_by_ref(target_class_number integer, target_student_ref_id text, target_student_ref_type text, target_class_date date, target_lesson_code text) to service_role;
grant execute on function public.get_teacher_class_resources(target_class_number integer) to authenticated;
grant execute on function public.get_teacher_class_resources(target_class_number integer) to service_role;
grant execute on function public.get_my_student_class() to authenticated;
grant execute on function public.get_my_student_class() to service_role;
grant execute on function public.save_teacher_classes_order(classes_order jsonb) to service_role;
grant execute on function public.create_teacher_exercise(target_exercise_id text, target_exercise_title text, target_exercise_url text, target_scheduled_publish_at timestamp with time zone) to authenticated;
grant execute on function public.create_teacher_exercise(target_exercise_id text, target_exercise_title text, target_exercise_url text, target_scheduled_publish_at timestamp with time zone) to service_role;
grant execute on function public.get_teacher_created_exercises() to authenticated;
grant execute on function public.get_teacher_created_exercises() to service_role;
grant execute on function public.delete_teacher_exercise(target_id uuid) to authenticated;
grant execute on function public.delete_teacher_exercise(target_id uuid) to service_role;
grant execute on function public.get_public_teacher_exercises() to authenticated;
grant execute on function public.get_public_teacher_exercises() to service_role;
grant execute on function public.get_teacher_students() to authenticated;
grant execute on function public.get_teacher_students() to service_role;
grant execute on function public.get_teacher_billing_students() to authenticated;
grant execute on function public.get_teacher_billing_students() to service_role;
grant execute on function public.save_student_billing_settings(target_student_id uuid, target_monthly_fee numeric, target_due_day integer, target_billing_start_month date, target_active boolean, target_notes text) to authenticated;
grant execute on function public.save_student_billing_settings(target_student_id uuid, target_monthly_fee numeric, target_due_day integer, target_billing_start_month date, target_active boolean, target_notes text) to service_role;
grant execute on function public.generate_monthly_tuition(target_reference_month date) to authenticated;
grant execute on function public.generate_monthly_tuition(target_reference_month date) to service_role;
grant execute on function public.get_teacher_monthly_tuition(target_reference_month date) to authenticated;
grant execute on function public.get_teacher_monthly_tuition(target_reference_month date) to service_role;
grant execute on function public.get_teacher_student_tuition_history(target_student_id uuid) to authenticated;
grant execute on function public.get_teacher_student_tuition_history(target_student_id uuid) to service_role;
grant execute on function public.record_tuition_payment(target_tuition_id uuid, target_payment_date date, target_amount_paid numeric, target_payment_method text, target_payment_notes text) to authenticated;
grant execute on function public.record_tuition_payment(target_tuition_id uuid, target_payment_date date, target_amount_paid numeric, target_payment_method text, target_payment_notes text) to service_role;
grant execute on function public.reverse_tuition_payment(target_tuition_id uuid, target_reason text) to authenticated;
grant execute on function public.reverse_tuition_payment(target_tuition_id uuid, target_reason text) to service_role;
grant execute on function public.sync_enrolled_auth_profile(target_user_id uuid, target_email text, target_metadata jsonb) to service_role;
grant execute on function public.handle_enrolled_auth_user_profile() to service_role;
grant execute on function public.queue_enrollment_email_notification() to service_role;
grant execute on function public.book_makeup_class(target_slot_id uuid) to authenticated;
grant execute on function public.book_makeup_class(target_slot_id uuid) to service_role;
grant execute on function public.get_my_makeup_bookings() to authenticated;
grant execute on function public.get_my_makeup_bookings() to service_role;
grant execute on function public.get_teacher_makeup_bookings() to authenticated;
grant execute on function public.get_teacher_makeup_bookings() to service_role;
grant execute on function public.cancel_makeup_class_slot(target_slot_id uuid) to authenticated;
grant execute on function public.cancel_makeup_class_slot(target_slot_id uuid) to service_role;
grant execute on function public.cancel_makeup_class_booking(target_booking_id uuid) to authenticated;
grant execute on function public.cancel_makeup_class_booking(target_booking_id uuid) to service_role;
grant execute on function public.get_teacher_makeup_classes() to authenticated;
grant execute on function public.get_teacher_makeup_classes() to service_role;
grant execute on function public.create_makeup_class_slot(target_class_number integer, target_date date, target_start_time time without time zone, target_end_time time without time zone, target_capacity integer, target_notes text) to authenticated;
grant execute on function public.create_makeup_class_slot(target_class_number integer, target_date date, target_start_time time without time zone, target_end_time time without time zone, target_capacity integer, target_notes text) to service_role;
grant execute on function public.get_available_makeup_slots() to authenticated;
grant execute on function public.get_available_makeup_slots() to service_role;
grant execute on function public.cancel_my_makeup_class_booking(target_booking_id uuid) to authenticated;
grant execute on function public.cancel_my_makeup_class_booking(target_booking_id uuid) to service_role;
grant execute on function public.get_teacher_makeup_slots() to authenticated;
grant execute on function public.get_teacher_makeup_slots() to service_role;
grant execute on function public.log_student_page_access(target_page_path text, target_page_title text, target_timezone text) to authenticated;
grant execute on function public.log_student_page_access(target_page_path text, target_page_title text, target_timezone text) to service_role;
grant execute on function public.get_teacher_student_accesses(target_days integer, target_user_id uuid) to authenticated;
grant execute on function public.get_teacher_student_accesses(target_days integer, target_user_id uuid) to service_role;
grant execute on function public.set_flashcards_updated_at() to service_role;
grant execute on function public.save_flashcard_deck(p_deck_id uuid, p_title text, p_description text, p_is_shared boolean, p_cards jsonb) to service_role;
grant execute on function public.save_flashcard_deck(p_deck_id uuid, p_owner_id uuid, p_title text, p_description text, p_cards jsonb) to authenticated;
grant execute on function public.save_flashcard_deck(p_deck_id uuid, p_owner_id uuid, p_title text, p_description text, p_cards jsonb) to service_role;
grant execute on function public.record_flashcard_practice_day() to authenticated;
grant execute on function public.record_flashcard_practice_day() to service_role;
grant execute on function public.get_teacher_weekly_exercise_status() to authenticated;
grant execute on function public.get_teacher_weekly_exercise_status() to service_role;
grant execute on function public.set_daily_exercise_completion_actor() to service_role;
grant execute on function public.get_teacher_student_exercise_completion(target_user_id uuid) to authenticated;
grant execute on function public.get_teacher_student_exercise_completion(target_user_id uuid) to service_role;
grant execute on function public.set_teacher_student_exercise_completion(target_user_id uuid, target_exercise_id text, target_completed boolean, target_completed_at timestamp with time zone) to service_role;
grant execute on function public.set_exercise_schedule_start_date() to public;
grant execute on function public.set_exercise_schedule_start_date() to service_role;
grant execute on function public.archive_teacher_student(target_user_id uuid) to authenticated;
grant execute on function public.archive_teacher_student(target_user_id uuid) to service_role;
grant execute on function public.unarchive_teacher_student(target_user_id uuid) to authenticated;
grant execute on function public.unarchive_teacher_student(target_user_id uuid) to service_role;
grant execute on function public.ensure_weekly_plan_snapshot(target_user_id uuid) to authenticated;
grant execute on function public.ensure_weekly_plan_snapshot(target_user_id uuid) to service_role;
grant execute on function public.set_my_weekly_task_completed(target_task_id uuid, target_completed boolean) to authenticated;
grant execute on function public.set_my_weekly_task_completed(target_task_id uuid, target_completed boolean) to service_role;
grant execute on function public.get_teacher_classes_with_type() to authenticated;
grant execute on function public.get_teacher_classes_with_type() to service_role;
grant execute on function public.create_teacher_class_with_type(target_class_name text, target_class_type text) to authenticated;
grant execute on function public.create_teacher_class_with_type(target_class_name text, target_class_type text) to service_role;
grant execute on function public.set_teacher_class_type(target_class_number integer, target_class_type text) to authenticated;
grant execute on function public.set_teacher_class_type(target_class_number integer, target_class_type text) to service_role;
grant execute on function public.get_group_classes_with_available_spots() to authenticated;
grant execute on function public.get_group_classes_with_available_spots() to service_role;
grant execute on function public.get_available_group_classes_for_students() to authenticated;
grant execute on function public.get_available_group_classes_for_students() to service_role;
grant execute on function public.switch_my_group_class(target_class_number integer) to authenticated;
grant execute on function public.switch_my_group_class(target_class_number integer) to service_role;
grant execute on function public.enforce_class_students_capacity() to service_role;
grant execute on function public.sync_auto_makeup_slots_30_days() to service_role;
grant execute on function public.enforce_makeup_slots_enabled() to service_role;
grant execute on function public.get_google_form_integrations() to authenticated;
grant execute on function public.get_google_form_integrations() to service_role;
grant execute on function public.upsert_google_form_integration(target_exercise_id text, target_spreadsheet_url text, target_import_existing boolean) to authenticated;
grant execute on function public.upsert_google_form_integration(target_exercise_id text, target_spreadsheet_url text, target_import_existing boolean) to service_role;
grant execute on function public.retry_google_form_integration(target_id uuid) to authenticated;
grant execute on function public.retry_google_form_integration(target_id uuid) to service_role;
grant execute on function public.disconnect_google_form_integration(target_id uuid) to authenticated;
grant execute on function public.disconnect_google_form_integration(target_id uuid) to service_role;
grant execute on function public.set_tuition_payment_attempt_updated_at() to public;
grant execute on function public.set_tuition_payment_attempt_updated_at() to service_role;
grant execute on function public.get_my_pending_tuitions() to authenticated;
grant execute on function public.get_my_pending_tuitions() to service_role;
grant execute on function public.process_mercado_pago_payment(target_attempt_id uuid, target_provider_payment_id text, target_status text, target_status_detail text, target_amount numeric, target_payment_method text, target_live_mode boolean, target_provider_created_at timestamp with time zone, target_provider_updated_at timestamp with time zone, target_approved_at timestamp with time zone) to service_role;
grant execute on function public.get_student_login_route_internal(target_email text) to service_role;
grant execute on function public.get_teacher_student_access_statuses() to authenticated;
grant execute on function public.get_teacher_student_access_statuses() to service_role;
grant execute on function public.sync_student_portal_access_status() to service_role;
grant execute on function public.delete_teacher_class_lesson_record(target_record_id uuid) to authenticated;
grant execute on function public.delete_teacher_class_lesson_record(target_record_id uuid) to service_role;
grant execute on function public.get_student_google_link_candidate_internal(target_google_user_id uuid, target_google_email text) to service_role;
grant execute on function public.confirm_or_migrate_student_google_link_internal(target_google_user_id uuid, target_legacy_user_id uuid, target_google_email text) to service_role;
grant execute on function public.preserve_linked_student_enrollment_email() to service_role;
grant execute on function public.normalize_profile_enrollment_code() to public;
grant execute on function public.normalize_profile_enrollment_code() to service_role;
grant execute on function public.activate_completed_google_student_profile() to service_role;
grant execute on function public.consume_api_rate_limit(target_bucket_key text, target_window_seconds integer, target_max_requests integer) to service_role;
grant execute on function public.protect_profile_security_fields() to public;
grant execute on function public.protect_profile_security_fields() to service_role;
grant execute on function public.record_flashcard_review(p_card_id uuid, p_grade text) to authenticated;
grant execute on function public.record_flashcard_review(p_card_id uuid, p_grade text) to service_role;
grant execute on function public.prevent_new_duplicate_profile_cpf() to service_role;
grant execute on function public.prune_app_error_events(target_days integer) to service_role;

set check_function_bodies = true;
