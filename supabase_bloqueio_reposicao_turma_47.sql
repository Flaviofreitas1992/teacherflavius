-- Bloqueia permanentemente horários de reposição para a TURMA 8 - MON 20H (class_number 47).

alter table public.teacher_classes
  add column if not exists makeup_slots_enabled boolean not null default true;

update public.teacher_classes
set makeup_slots_enabled = false,
    updated_at = now()
where class_number = 47;

-- Remove horários futuros ainda sem reserva da turma bloqueada.
delete from public.makeup_class_slots s
where s.class_number = 47
  and s.starts_at > now()
  and not exists (
    select 1
    from public.makeup_class_bookings b
    where b.slot_id = s.id
      and b.status = 'confirmed'
  );

create or replace function public.enforce_makeup_slots_enabled()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
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
$$;

drop trigger if exists trg_enforce_makeup_slots_enabled on public.makeup_class_slots;
create trigger trg_enforce_makeup_slots_enabled
before insert or update of class_number
on public.makeup_class_slots
for each row
execute function public.enforce_makeup_slots_enabled();

-- A função sync_auto_makeup_slots_30_days deve filtrar:
-- and coalesce(tc.makeup_slots_enabled, true) = true
-- para excluir automaticamente qualquer turma com reposições desativadas.
