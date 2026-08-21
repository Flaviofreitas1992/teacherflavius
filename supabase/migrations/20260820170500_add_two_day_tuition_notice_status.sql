-- Add precise due-date states for the logged-in student's tuition notice.
-- The frontend uses these states to start a yellow warning exactly two days
-- before the due date, then adapt the wording on the day before and due date.

create or replace function public.get_my_pending_tuitions()
returns table(
  tuition_id uuid,
  reference_month date,
  due_date date,
  amount_due numeric,
  payment_status text,
  attempt_id uuid,
  provider_payment_id text,
  attempt_status text,
  attempt_status_detail text
)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
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
$$;
