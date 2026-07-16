-- Controle administrativo de mensalidades.
-- Execute este arquivo no Supabase SQL Editor depois de:
-- 1) supabase_professor_admin.sql
-- 2) supabase_add_profile_enrollment_columns.sql

-- Vincula o administrador ao UUID da conta quando o e-mail já está cadastrado.
update public.teacher_admins ta
set user_id = u.id
from auth.users u
where ta.user_id is null
  and lower(ta.email) = lower(u.email);

create unique index if not exists teacher_admins_user_id_unique_idx
  on public.teacher_admins (user_id)
  where user_id is not null;

-- Mantém compatibilidade com instalações antigas que ainda têm apenas o e-mail,
-- mas prioriza o UUID imutável da conta do administrador.
create or replace function public.is_teacher_admin()
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1
    from public.teacher_admins ta
    where ta.user_id = auth.uid()
       or (
         ta.user_id is null
         and lower(ta.email) = lower(auth.jwt() ->> 'email')
       )
  );
$$;

grant execute on function public.is_teacher_admin() to authenticated;

-- Garante que todo usuário realmente matriculado também exista em public.profiles.
-- A matrícula direta é criada primeiro em auth.users. Quando a confirmação de
-- e-mail está ativa, o navegador ainda não possui uma sessão e o upsert feito
-- pelo frontend pode ser bloqueado pelo RLS. Esta função faz a sincronização no
-- banco, preservando dados já preenchidos no perfil.
create or replace function public.sync_enrolled_auth_profile(
  target_user_id uuid,
  target_email text,
  target_metadata jsonb
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  normalized_metadata jsonb := coalesce(target_metadata, '{}'::jsonb);
  normalized_availability jsonb := '{}'::jsonb;
  normalized_enrollment_code text;
begin
  if target_user_id is null then
    return false;
  end if;

  if lower(coalesce(normalized_metadata ->> 'enrolled', 'false'))
     not in ('true', '1', 'yes') then
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

  if jsonb_typeof(normalized_metadata -> 'availability') = 'object' then
    normalized_availability := normalized_metadata -> 'availability';
  end if;

  normalized_enrollment_code := nullif(
    trim(coalesce(normalized_metadata ->> 'enrollment_code', '')),
    ''
  );

  -- Evita que um código antigo duplicado interrompa toda a recuperação.
  if normalized_enrollment_code is not null and exists (
    select 1
    from public.profiles p
    where p.enrollment_code = normalized_enrollment_code
      and p.id <> target_user_id
  ) then
    normalized_enrollment_code := null;
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
    enrolled
  ) values (
    target_user_id,
    nullif(trim(coalesce(normalized_metadata ->> 'name', '')), ''),
    nullif(trim(coalesce(target_email, '')), ''),
    nullif(trim(coalesce(normalized_metadata ->> 'cpf', '')), ''),
    nullif(trim(coalesce(normalized_metadata ->> 'whatsapp', '')), ''),
    nullif(trim(coalesce(normalized_metadata ->> 'pix_key', '')), ''),
    normalized_availability,
    normalized_enrollment_code,
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
$$;

revoke all on function public.sync_enrolled_auth_profile(uuid, text, jsonb) from public;

-- Sincroniza automaticamente matrículas futuras, inclusive quando o usuário
-- ainda precisa confirmar o e-mail e não possui uma sessão no navegador.
create or replace function public.handle_enrolled_auth_user_profile()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.sync_enrolled_auth_profile(
    new.id,
    new.email,
    new.raw_user_meta_data
  );
  return new;
end;
$$;

revoke all on function public.handle_enrolled_auth_user_profile() from public;

drop trigger if exists sync_enrolled_auth_user_profile_trigger on auth.users;
create trigger sync_enrolled_auth_user_profile_trigger
  after insert or update of raw_user_meta_data, email on auth.users
  for each row
  execute function public.handle_enrolled_auth_user_profile();

-- Recupera imediatamente alunos antigos que estão em auth.users com
-- enrolled=true, mas ainda não possuem um perfil financeiro utilizável.
do $$
declare
  auth_user record;
begin
  for auth_user in
    select u.id, u.email, u.raw_user_meta_data
    from auth.users u
  loop
    perform public.sync_enrolled_auth_profile(
      auth_user.id,
      auth_user.email,
      auth_user.raw_user_meta_data
    );
  end loop;
end;
$$;

create table if not exists public.student_billing_settings (
  student_id uuid primary key references public.profiles(id) on delete cascade,
  monthly_fee numeric(10,2) not null check (monthly_fee > 0),
  due_day smallint not null check (due_day between 1 and 31),
  billing_start_month date not null,
  active boolean not null default true,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users(id) on delete set null,
  constraint student_billing_start_month_first_day
    check (billing_start_month = date_trunc('month', billing_start_month)::date)
);

create table if not exists public.monthly_tuition (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references public.profiles(id) on delete cascade,
  reference_month date not null,
  due_date date not null,
  amount_due numeric(10,2) not null check (amount_due > 0),
  payment_date date,
  amount_paid numeric(10,2) check (amount_paid is null or amount_paid > 0),
  payment_method text check (
    payment_method is null
    or payment_method in ('pix', 'cash', 'bank_transfer', 'card', 'other')
  ),
  payment_notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid references auth.users(id) on delete set null,
  updated_by uuid references auth.users(id) on delete set null,
  constraint monthly_tuition_reference_first_day
    check (reference_month = date_trunc('month', reference_month)::date),
  constraint monthly_tuition_payment_consistency
    check (
      (payment_date is null and amount_paid is null and payment_method is null)
      or
      (payment_date is not null and amount_paid is not null and payment_method is not null)
    ),
  unique (student_id, reference_month)
);

create table if not exists public.monthly_tuition_events (
  id uuid primary key default gen_random_uuid(),
  tuition_id uuid not null references public.monthly_tuition(id) on delete cascade,
  action text not null check (action in ('payment_recorded', 'payment_reversed')),
  actor_id uuid references auth.users(id) on delete set null,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists monthly_tuition_reference_month_idx
  on public.monthly_tuition (reference_month);

create index if not exists monthly_tuition_due_date_idx
  on public.monthly_tuition (due_date);

create index if not exists monthly_tuition_student_id_idx
  on public.monthly_tuition (student_id);

create index if not exists monthly_tuition_events_tuition_id_idx
  on public.monthly_tuition_events (tuition_id, created_at desc);

alter table public.student_billing_settings enable row level security;
alter table public.monthly_tuition enable row level security;
alter table public.monthly_tuition_events enable row level security;

drop policy if exists "Administradores gerenciam configurações financeiras" on public.student_billing_settings;
create policy "Administradores gerenciam configurações financeiras"
  on public.student_billing_settings
  for all
  to authenticated
  using (public.is_teacher_admin())
  with check (public.is_teacher_admin());

drop policy if exists "Administradores gerenciam mensalidades" on public.monthly_tuition;
create policy "Administradores gerenciam mensalidades"
  on public.monthly_tuition
  for all
  to authenticated
  using (public.is_teacher_admin())
  with check (public.is_teacher_admin());

drop policy if exists "Administradores visualizam eventos financeiros" on public.monthly_tuition_events;
create policy "Administradores visualizam eventos financeiros"
  on public.monthly_tuition_events
  for select
  to authenticated
  using (public.is_teacher_admin());

grant select, insert, update, delete on public.student_billing_settings to authenticated;
grant select, insert, update, delete on public.monthly_tuition to authenticated;
grant select on public.monthly_tuition_events to authenticated;

create or replace function public.get_teacher_billing_students()
returns table (
  student_id uuid,
  name text,
  email text,
  monthly_fee numeric,
  due_day smallint,
  billing_start_month date,
  billing_active boolean,
  billing_notes text
)
language plpgsql
security definer
set search_path = public
stable
as $$
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
    and not exists (
      select 1
      from public.teacher_admins ta
      where ta.user_id = p.id
         or lower(ta.email) = lower(coalesce(p.email, ''))
    )
  order by p.name asc nulls last, p.email asc nulls last;
end;
$$;

grant execute on function public.get_teacher_billing_students() to authenticated;

create or replace function public.save_student_billing_settings(
  target_student_id uuid,
  target_monthly_fee numeric,
  target_due_day integer,
  target_billing_start_month date,
  target_active boolean,
  target_notes text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
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
$$;

grant execute on function public.save_student_billing_settings(uuid, numeric, integer, date, boolean, text) to authenticated;

create or replace function public.generate_monthly_tuition(target_reference_month date)
returns integer
language plpgsql
security definer
set search_path = public
as $$
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
$$;

grant execute on function public.generate_monthly_tuition(date) to authenticated;

create or replace function public.get_teacher_monthly_tuition(target_reference_month date)
returns table (
  tuition_id uuid,
  student_id uuid,
  student_name text,
  student_email text,
  reference_month date,
  due_date date,
  amount_due numeric,
  payment_date date,
  amount_paid numeric,
  payment_method text,
  payment_notes text,
  payment_status text
)
language plpgsql
security definer
set search_path = public
stable
as $$
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
$$;

grant execute on function public.get_teacher_monthly_tuition(date) to authenticated;

create or replace function public.get_teacher_student_tuition_history(target_student_id uuid)
returns table (
  tuition_id uuid,
  reference_month date,
  due_date date,
  amount_due numeric,
  payment_date date,
  amount_paid numeric,
  payment_method text,
  payment_notes text,
  payment_status text
)
language plpgsql
security definer
set search_path = public
stable
as $$
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
$$;

grant execute on function public.get_teacher_student_tuition_history(uuid) to authenticated;

create or replace function public.record_tuition_payment(
  target_tuition_id uuid,
  target_payment_date date,
  target_amount_paid numeric,
  target_payment_method text,
  target_payment_notes text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
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
$$;

grant execute on function public.record_tuition_payment(uuid, date, numeric, text, text) to authenticated;

create or replace function public.reverse_tuition_payment(
  target_tuition_id uuid,
  target_reason text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
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
    'payment_notes', mt.payment_notes
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
$$;

grant execute on function public.reverse_tuition_payment(uuid, text) to authenticated;

-- Garante que usuários anônimos não tenham acesso às informações financeiras.
revoke all on public.student_billing_settings from anon;
revoke all on public.monthly_tuition from anon;
revoke all on public.monthly_tuition_events from anon;
