-- Database integrity hardening: index foreign keys and prevent duplicate active makeup slots.

create index if not exists activity_results_user_id_idx
  on public.activity_results (user_id);

create index if not exists daily_exercise_completion_completed_by_idx
  on public.daily_exercise_completion (completed_by);

create index if not exists exercise_form_sources_created_by_idx
  on public.exercise_form_sources (created_by);

create index if not exists grammar_lessons_created_by_idx
  on public.grammar_lessons (created_by);

create index if not exists makeup_class_slots_created_by_idx
  on public.makeup_class_slots (created_by);

create index if not exists monthly_tuition_created_by_idx
  on public.monthly_tuition (created_by);

create index if not exists monthly_tuition_updated_by_idx
  on public.monthly_tuition (updated_by);

create index if not exists monthly_tuition_events_actor_id_idx
  on public.monthly_tuition_events (actor_id);

create index if not exists pronunciation_assignments_created_by_idx
  on public.pronunciation_assignments (created_by);

create index if not exists student_billing_settings_updated_by_idx
  on public.student_billing_settings (updated_by);

create index if not exists student_enrollment_invites_created_by_idx
  on public.student_enrollment_invites (created_by);

create index if not exists student_enrollment_invites_user_id_idx
  on public.student_enrollment_invites (user_id);

create index if not exists student_enrollments_user_id_idx
  on public.student_enrollments (user_id);

create index if not exists student_tags_created_by_idx
  on public.student_tags (created_by);

create index if not exists teacher_exercises_created_by_idx
  on public.teacher_exercises (created_by);

create unique index if not exists makeup_class_slots_active_class_start_uidx
  on public.makeup_class_slots (class_number, starts_at)
  where is_active = true and class_number is not null;
