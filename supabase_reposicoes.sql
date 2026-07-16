-- Agenda de reposicoes de aula.
-- Execute no Supabase SQL Editor depois de supabase_turmas.sql.
-- Datas e horarios sao armazenados em UTC e exibidos no fuso America/Sao_Paulo.

create table if not exists public.makeup_class_slots (
  id uuid primary key default gen_random_uuid(),
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  capacity integer not null default 1 check (capacity between 1 and 50),
  notes text,
  is_active boolean not null default true,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint makeup_class_slots_time_check check (ends_at > starts_at)
);

create table if not exists public.makeup_class_bookings (
  id uuid primary key default gen_random_uuid(),
  slot_id uuid not null references public.makeup_class_slots(id) on delete restrict,
  student_id uuid not null references auth.users(id) on delete cascade,
  class_number integer not null,
  class_name text not null,
  student_name text not null,
  student_email text not null,
  meeting_url text not null,
  status text not null default 'confirmed'
    check (status in ('confirmed', 'cancelled')),
  booked_at timestamptz not null default now(),
  cancelled_at timestamptz
);

create unique index if not exists makeup_class_bookings_confirmed_unique
  on public.makeup_class_bookings (slot_id, student_id)
  where status = 'confirmed';

create table if not exists public.makeup_class_email_notifications (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null unique references public.makeup_class_bookings(id) on delete cascade,
  status text not null default 'pending'
    check (status in ('pending', 'sent', 'failed')),
  attempts integer not null default 0 check (attempts >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  last_attempt_at timestamptz,
  sent_at timestamptz,
  last_error text
);

create index if not exists makeup_class_slots_starts_at_idx
  on public.makeup_class_slots (starts_at, is_active);
create index if not exists makeup_class_bookings_slot_idx
  on public.makeup_class_bookings (slot_id, status);
create index if not exists makeup_class_bookings_student_idx
  on public.makeup_class_bookings (student_id, booked_at desc);
create index if not exists makeup_class_email_status_idx
  on public.makeup_class_email_notifications (status, created_at);

alter table public.makeup_class_slots enable row level security;
alter table public.makeup_class_bookings enable row level security;
alter table public.makeup_class_email_notifications enable row level security;

-- O navegador acessa os dados somente pelas funcoes abaixo. Isso evita que um
-- aluno consulte reservas, e-mails ou links de aula de outros alunos.
revoke all on public.makeup_class_slots from anon, authenticated;
revoke all on public.makeup_class_bookings from anon, authenticated;
revoke all on public.makeup_class_email_notifications from anon, authenticated;

grant select, insert, update, delete on public.makeup_class_slots to service_role;
grant select, insert, update, delete on public.makeup_class_bookings to service_role;
grant select, insert, update, delete on public.makeup_class_email_notifications to service_role;

drop policy if exists "Administrador visualiza notificacoes de reposicao"
  on public.makeup_class_email_notifications;
create policy "Administrador visualiza notificacoes de reposicao"
  on public.makeup_class_email_notifications
  for select
  to authenticated
  using (public.is_teacher_admin());
grant select on public.makeup_class_email_notifications to authenticated;

drop trigger if exists set_makeup_class_slots_updated_at on public.makeup_class_slots;
create trigger set_makeup_class_slots_updated_at
before update on public.makeup_class_slots
for each row
execute function public.set_updated_at();

create or replace function public.create_makeup_class_slot(
  target_date date,
  target_start_time time without time zone,
  target_end_time time without time zone,
  target_capacity integer default 1,
  target_notes text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  target_starts_at timestamptz;
  target_ends_at timestamptz;
  inserted_id uuid;
begin
  if not public.is_teacher_admin() then
    raise exception 'Acesso negado: usuario nao cadastrado como professor.';
  end if;

  if target_date is null or target_start_time is null or target_end_time is null then
    raise exception 'Informe a data, o inicio e o termino.';
  end if;

  if target_end_time <= target_start_time then
    raise exception 'O termino precisa ser depois do inicio.';
  end if;

  if target_capacity is null or target_capacity < 1 or target_capacity > 50 then
    raise exception 'A quantidade de vagas deve estar entre 1 e 50.';
  end if;

  target_starts_at := (target_date + target_start_time) at time zone 'America/Sao_Paulo';
  target_ends_at := (target_date + target_end_time) at time zone 'America/Sao_Paulo';

  if target_starts_at <= now() then
    raise exception 'Publique somente horarios futuros.';
  end if;

  insert into public.makeup_class_slots (
    starts_at,
    ends_at,
    capacity,
    notes,
    created_by
  )
  values (
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
    'starts_at', target_starts_at,
    'ends_at', target_ends_at
  );
end;
$$;

revoke all on function public.create_makeup_class_slot(date, time without time zone, time without time zone, integer, text) from public;
grant execute on function public.create_makeup_class_slot(date, time without time zone, time without time zone, integer, text) to authenticated;

create or replace function public.get_available_makeup_slots()
returns table (
  id text,
  starts_at timestamptz,
  ends_at timestamptz,
  remaining_spots integer,
  notes text
)
language plpgsql
security definer
set search_path = public
as $$
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
  group by s.id, s.starts_at, s.ends_at, s.capacity, s.notes
  having count(b.id) < s.capacity
  order by s.starts_at asc;
end;
$$;

revoke all on function public.get_available_makeup_slots() from public;
grant execute on function public.get_available_makeup_slots() to authenticated;

create or replace function public.book_makeup_class(target_slot_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
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

  if not target_slot.is_active or target_slot.starts_at <= now() then
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
    return jsonb_build_object('ok', true, 'booking_id', existing_booking_id, 'already_booked', true);
  end if;

  select
    cs.class_number,
    coalesce(nullif(trim(tc.class_name), ''), 'Turma ' || cs.class_number),
    coalesce(nullif(trim(cr.video_lesson_url), ''), '')
  into target_class_number, target_class_name, target_meeting_url
  from public.class_students cs
  join public.teacher_classes tc
    on tc.class_number = cs.class_number
   and tc.is_active = true
  left join public.class_resources cr
    on cr.class_number = cs.class_number
  where cs.user_id = auth.uid()
  order by cs.created_at desc
  limit 1;

  if target_class_number is null then
    raise exception 'Voce ainda nao foi inscrito em uma turma pelo professor.';
  end if;

  if target_meeting_url = '' then
    raise exception 'O professor ainda nao cadastrou o link da videoaula da sua turma.';
  end if;

  if target_meeting_url !~* '^https?://' then
    raise exception 'O link da videoaula da sua turma e invalido. Avise o professor.';
  end if;

  select
    coalesce(
      nullif(trim(p.name), ''),
      nullif(trim(u.raw_user_meta_data ->> 'name'), ''),
      u.email,
      'Aluno'
    ),
    coalesce(nullif(trim(p.email), ''), u.email, '')
  into target_student_name, target_student_email
  from auth.users u
  left join public.profiles p on p.id = u.id
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

  insert into public.makeup_class_email_notifications (booking_id)
  values (inserted_booking_id);

  return jsonb_build_object(
    'ok', true,
    'booking_id', inserted_booking_id,
    'email_queued', true
  );
end;
$$;

revoke all on function public.book_makeup_class(uuid) from public;
grant execute on function public.book_makeup_class(uuid) to authenticated;

create or replace function public.get_my_makeup_bookings()
returns table (
  id text,
  slot_id text,
  starts_at timestamptz,
  ends_at timestamptz,
  status text,
  class_number integer,
  class_name text,
  meeting_url text,
  email_status text,
  booked_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
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
    coalesce(n.status, 'pending')::text as email_status,
    b.booked_at
  from public.makeup_class_bookings b
  join public.makeup_class_slots s on s.id = b.slot_id
  left join public.makeup_class_email_notifications n on n.booking_id = b.id
  where b.student_id = auth.uid()
  order by
    case when s.starts_at >= now() and b.status = 'confirmed' then 0 else 1 end,
    case when s.starts_at >= now() then s.starts_at end asc,
    s.starts_at desc;
end;
$$;

revoke all on function public.get_my_makeup_bookings() from public;
grant execute on function public.get_my_makeup_bookings() to authenticated;

create or replace function public.get_teacher_makeup_slots()
returns table (
  id text,
  starts_at timestamptz,
  ends_at timestamptz,
  capacity integer,
  notes text,
  is_active boolean,
  confirmed_bookings integer,
  created_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_teacher_admin() then
    raise exception 'Acesso negado: usuario nao cadastrado como professor.';
  end if;

  return query
  select
    s.id::text,
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
  group by s.id, s.starts_at, s.ends_at, s.capacity, s.notes, s.is_active, s.created_at
  order by
    case when s.starts_at >= now() and s.is_active then 0 else 1 end,
    case when s.starts_at >= now() and s.is_active then s.starts_at end asc,
    s.starts_at desc;
end;
$$;

revoke all on function public.get_teacher_makeup_slots() from public;
grant execute on function public.get_teacher_makeup_slots() to authenticated;

create or replace function public.get_teacher_makeup_bookings()
returns table (
  id text,
  slot_id text,
  student_id text,
  student_name text,
  student_email text,
  class_number integer,
  class_name text,
  status text,
  email_status text,
  email_error text,
  booked_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
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
  left join public.makeup_class_email_notifications n on n.booking_id = b.id
  order by b.booked_at desc;
end;
$$;

revoke all on function public.get_teacher_makeup_bookings() from public;
grant execute on function public.get_teacher_makeup_bookings() to authenticated;

create or replace function public.cancel_makeup_class_slot(target_slot_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
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
  set status = 'cancelled', cancelled_at = now()
  where slot_id = target_slot_id
    and status = 'confirmed';

  get diagnostics cancelled_count = row_count;

  return jsonb_build_object('ok', true, 'cancelled_bookings', cancelled_count);
end;
$$;

revoke all on function public.cancel_makeup_class_slot(uuid) from public;
grant execute on function public.cancel_makeup_class_slot(uuid) to authenticated;

create or replace function public.cancel_makeup_class_booking(target_booking_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_teacher_admin() then
    raise exception 'Acesso negado: usuario nao cadastrado como professor.';
  end if;

  update public.makeup_class_bookings
  set status = 'cancelled', cancelled_at = now()
  where id = target_booking_id
    and status = 'confirmed';

  if not found then
    raise exception 'Reserva confirmada nao encontrada.';
  end if;

  return jsonb_build_object('ok', true);
end;
$$;

revoke all on function public.cancel_makeup_class_booking(uuid) from public;
grant execute on function public.cancel_makeup_class_booking(uuid) to authenticated;

-- O registro nesta fila dispara o webhook da Edge Function.
-- Nao crie notificacoes diretamente pelo navegador.
