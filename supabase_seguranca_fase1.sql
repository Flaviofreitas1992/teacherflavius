-- Segurança do Supabase — Fase 1
--
-- Objetivos:
--   1. impedir que o papel anon execute funções do schema public;
--   2. permitir ao papel authenticated somente as RPCs usadas pelo site;
--   3. manter o papel service_role apto a executar rotinas de servidor;
--   4. fixar o search_path das funções de trigger apontadas pelo Security Advisor.
--
-- Este script é idempotente e executado dentro de uma transação. As verificações
-- finais geram uma exceção e desfazem tudo se alguma regra crítica não for atendida.

begin;

-- Funções novas não devem voltar a herdar EXECUTE por meio de PUBLIC.
alter default privileges for role postgres in schema public
  revoke execute on functions from public, anon, authenticated;

alter default privileges for role postgres in schema public
  grant execute on functions to service_role;

-- Remove permissões herdadas e permissões diretas das funções existentes.
revoke execute on all functions in schema public from public, anon, authenticated;

-- service_role é usada apenas no servidor e nas Edge Functions confiáveis.
grant execute on all functions in schema public to service_role;

-- RPCs usadas por alunos e professores autenticados.
grant execute on function public.add_teacher_class_student_by_ref(integer, text, text) to authenticated;
grant execute on function public.book_makeup_class(uuid) to authenticated;
grant execute on function public.cancel_makeup_class_booking(uuid) to authenticated;
grant execute on function public.cancel_makeup_class_slot(uuid) to authenticated;
grant execute on function public.cancel_my_makeup_class_booking(uuid) to authenticated;
grant execute on function public.create_makeup_class_slot(integer, date, time without time zone, time without time zone, integer, text) to authenticated;
grant execute on function public.create_teacher_class(text) to authenticated;
grant execute on function public.create_teacher_exercise(text, text, text, timestamp with time zone) to authenticated;
grant execute on function public.delete_teacher_class(integer) to authenticated;
grant execute on function public.delete_teacher_exercise(uuid) to authenticated;
grant execute on function public.delete_teacher_student(uuid) to authenticated;
grant execute on function public.generate_monthly_tuition(date) to authenticated;
grant execute on function public.get_available_makeup_slots() to authenticated;
grant execute on function public.get_my_lesson_records() to authenticated;
grant execute on function public.get_my_makeup_bookings() to authenticated;
grant execute on function public.get_my_pending_tuitions() to authenticated;
grant execute on function public.get_my_private_student_data() to authenticated;
grant execute on function public.get_my_student_class() to authenticated;
grant execute on function public.get_public_teacher_exercises() to authenticated;
grant execute on function public.get_teacher_billing_students() to authenticated;
grant execute on function public.get_teacher_class_activity_history(integer) to authenticated;
grant execute on function public.get_teacher_class_lesson_records(integer) to authenticated;
grant execute on function public.get_teacher_class_resources(integer) to authenticated;
grant execute on function public.get_teacher_class_students(integer) to authenticated;
grant execute on function public.get_teacher_classes() to authenticated;
grant execute on function public.get_teacher_created_exercises() to authenticated;
grant execute on function public.get_teacher_daily_exercise_completion() to authenticated;
grant execute on function public.get_teacher_makeup_bookings() to authenticated;
grant execute on function public.get_teacher_makeup_classes() to authenticated;
grant execute on function public.get_teacher_makeup_slots() to authenticated;
grant execute on function public.get_teacher_monthly_tuition(date) to authenticated;
grant execute on function public.get_teacher_private_student_data() to authenticated;
grant execute on function public.get_teacher_student_accesses(integer, uuid) to authenticated;
grant execute on function public.get_teacher_student_tags() to authenticated;
grant execute on function public.get_teacher_student_tuition_history(uuid) to authenticated;
grant execute on function public.get_teacher_students() to authenticated;
grant execute on function public.is_teacher_admin() to authenticated;
grant execute on function public.log_student_page_access(text, text, text) to authenticated;
grant execute on function public.record_tuition_payment(uuid, date, numeric, text, text) to authenticated;
grant execute on function public.remove_teacher_class_student_by_ref(integer, text, text) to authenticated;
grant execute on function public.reverse_tuition_payment(uuid, text) to authenticated;
grant execute on function public.save_student_billing_settings(uuid, numeric, integer, date, boolean, text) to authenticated;
grant execute on function public.save_teacher_class_attendance_by_ref(integer, date, text, jsonb) to authenticated;
grant execute on function public.save_teacher_class_lesson_record_by_ref(integer, text, text, date, text) to authenticated;
grant execute on function public.save_teacher_class_resources(integer, text, text, text, text) to authenticated;
grant execute on function public.toggle_teacher_student_tag(text, text, text) to authenticated;
grant execute on function public.update_teacher_student_profile(uuid, text, text, text, text, text, text, jsonb) to authenticated;
grant execute on function public.upsert_my_private_student_data(text, text, text, boolean) to authenticated;

-- Essas funções usam apenas NEW, now() e RETURN. Um search_path vazio mantém
-- pg_catalog acessível implicitamente e elimina a resolução de objetos mutáveis.
alter function public.set_updated_at() set search_path = '';
alter function public.set_daily_exercise_completion_updated_at() set search_path = '';
alter function public.set_study_roadmap_completion_updated_at() set search_path = '';
alter function public.set_class_resources_updated_at() set search_path = '';
alter function public.set_teacher_exercises_updated_at() set search_path = '';
alter function public.set_student_private_data_updated_at() set search_path = '';

-- Falha fechada: qualquer problema abaixo cancela a transação completa.
do $security_checks$
declare
  required_signature text;
  function_oid regprocedure;
  required_functions constant text[] := array[
    'public.add_teacher_class_student_by_ref(integer,text,text)',
    'public.book_makeup_class(uuid)',
    'public.cancel_makeup_class_booking(uuid)',
    'public.cancel_makeup_class_slot(uuid)',
    'public.cancel_my_makeup_class_booking(uuid)',
    'public.create_makeup_class_slot(integer,date,time without time zone,time without time zone,integer,text)',
    'public.create_teacher_class(text)',
    'public.create_teacher_exercise(text,text,text,timestamp with time zone)',
    'public.delete_teacher_class(integer)',
    'public.delete_teacher_exercise(uuid)',
    'public.delete_teacher_student(uuid)',
    'public.generate_monthly_tuition(date)',
    'public.get_available_makeup_slots()',
    'public.get_my_lesson_records()',
    'public.get_my_makeup_bookings()',
    'public.get_my_pending_tuitions()',
    'public.get_my_private_student_data()',
    'public.get_my_student_class()',
    'public.get_public_teacher_exercises()',
    'public.get_teacher_billing_students()',
    'public.get_teacher_class_activity_history(integer)',
    'public.get_teacher_class_lesson_records(integer)',
    'public.get_teacher_class_resources(integer)',
    'public.get_teacher_class_students(integer)',
    'public.get_teacher_classes()',
    'public.get_teacher_created_exercises()',
    'public.get_teacher_daily_exercise_completion()',
    'public.get_teacher_makeup_bookings()',
    'public.get_teacher_makeup_classes()',
    'public.get_teacher_makeup_slots()',
    'public.get_teacher_monthly_tuition(date)',
    'public.get_teacher_private_student_data()',
    'public.get_teacher_student_accesses(integer,uuid)',
    'public.get_teacher_student_tags()',
    'public.get_teacher_student_tuition_history(uuid)',
    'public.get_teacher_students()',
    'public.is_teacher_admin()',
    'public.log_student_page_access(text,text,text)',
    'public.record_tuition_payment(uuid,date,numeric,text,text)',
    'public.remove_teacher_class_student_by_ref(integer,text,text)',
    'public.reverse_tuition_payment(uuid,text)',
    'public.save_student_billing_settings(uuid,numeric,integer,date,boolean,text)',
    'public.save_teacher_class_attendance_by_ref(integer,date,text,jsonb)',
    'public.save_teacher_class_lesson_record_by_ref(integer,text,text,date,text)',
    'public.save_teacher_class_resources(integer,text,text,text,text)',
    'public.toggle_teacher_student_tag(text,text,text)',
    'public.update_teacher_student_profile(uuid,text,text,text,text,text,text,jsonb)',
    'public.upsert_my_private_student_data(text,text,text,boolean)'
  ];
begin
  if exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.prosecdef
      and has_function_privilege('anon', p.oid, 'EXECUTE')
  ) then
    raise exception 'Segurança: ainda existe função SECURITY DEFINER executável por anon.';
  end if;

  foreach required_signature in array required_functions loop
    function_oid := to_regprocedure(required_signature);

    if function_oid is null then
      raise exception 'Segurança: função obrigatória não encontrada: %', required_signature;
    end if;

    if not has_function_privilege('authenticated', function_oid, 'EXECUTE') then
      raise exception 'Segurança: authenticated não pode executar: %', required_signature;
    end if;
  end loop;

  if exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname in (
        'set_updated_at',
        'set_daily_exercise_completion_updated_at',
        'set_study_roadmap_completion_updated_at',
        'set_class_resources_updated_at',
        'set_teacher_exercises_updated_at',
        'set_student_private_data_updated_at'
      )
      and not exists (
        select 1
        from unnest(coalesce(p.proconfig, array[]::text[])) as setting
        where setting like 'search_path=%'
      )
  ) then
    raise exception 'Segurança: ainda existe função de trigger com search_path mutável.';
  end if;
end;
$security_checks$;

commit;

-- Relatório esperado após a execução:
--   anon_security_definer_executable = 0
--   mutable_search_path_targets = 0
select
  count(*) filter (
    where p.prosecdef
      and has_function_privilege('anon', p.oid, 'EXECUTE')
  ) as anon_security_definer_executable,
  count(*) filter (
    where p.proname in (
      'set_updated_at',
      'set_daily_exercise_completion_updated_at',
      'set_study_roadmap_completion_updated_at',
      'set_class_resources_updated_at',
      'set_teacher_exercises_updated_at',
      'set_student_private_data_updated_at'
    )
    and not exists (
      select 1
      from unnest(coalesce(p.proconfig, array[]::text[])) as setting
      where setting like 'search_path=%'
    )
  ) as mutable_search_path_targets
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public';
