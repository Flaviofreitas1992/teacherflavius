-- Armazena a data de nascimento junto ao perfil do aluno.
-- A interface recebe/exibe DD/MM/AAAA e persiste como DATE (AAAA-MM-DD).

alter table public.profiles
  add column if not exists date_of_birth date;

comment on column public.profiles.date_of_birth is
  'Data de nascimento do aluno. Exibida no site como DD/MM/AAAA.';

alter table public.profiles
  drop constraint if exists profiles_date_of_birth_minimum_check;

alter table public.profiles
  add constraint profiles_date_of_birth_minimum_check
  check (date_of_birth is null or date_of_birth >= date '1900-01-01');
