-- CMS do site Teacher Flávio
--
-- Execute este arquivo uma vez no SQL Editor do projeto Supabase usado pelo site.
-- Ele cria o conteúdo editável, as políticas RLS e o bucket público de imagens.
-- Requer public.is_teacher_admin(), criada por supabase_professor_admin.sql.

begin;

create table if not exists public.site_content (
  key text primary key,
  page_slug text not null,
  section_slug text not null default 'main',
  label text not null,
  content_type text not null default 'text',
  value text not null default '',
  sort_order smallint not null default 0,
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users(id) on delete set null,
  constraint site_content_key_format check (
    key ~ '^[a-z0-9]+([._-][a-z0-9]+)*$'
  ),
  constraint site_content_page_slug_format check (
    page_slug ~ '^[a-z0-9]+([_-][a-z0-9]+)*$'
  ),
  constraint site_content_section_slug_format check (
    section_slug ~ '^[a-z0-9]+([_-][a-z0-9]+)*$'
  ),
  constraint site_content_type_allowed check (
    content_type in ('text', 'textarea', 'url', 'image')
  ),
  constraint site_content_label_length check (
    char_length(label) between 1 and 120
  ),
  constraint site_content_value_length check (
    char_length(value) <= 8000
  )
);

create index if not exists site_content_page_order_idx
  on public.site_content (page_slug, section_slug, sort_order, key);

alter table public.site_content enable row level security;

revoke all on table public.site_content from anon, authenticated;
grant select on table public.site_content to anon, authenticated;
grant insert, update, delete on table public.site_content to authenticated;

drop policy if exists "Conteúdo publicado é público" on public.site_content;
create policy "Conteúdo publicado é público"
  on public.site_content
  for select
  to anon, authenticated
  using (true);

drop policy if exists "Professores podem criar conteúdo" on public.site_content;
create policy "Professores podem criar conteúdo"
  on public.site_content
  for insert
  to authenticated
  with check (
    (select public.is_teacher_admin())
    and updated_by = (select auth.uid())
  );

drop policy if exists "Professores podem atualizar conteúdo" on public.site_content;
create policy "Professores podem atualizar conteúdo"
  on public.site_content
  for update
  to authenticated
  using ((select public.is_teacher_admin()))
  with check (
    (select public.is_teacher_admin())
    and updated_by = (select auth.uid())
  );

drop policy if exists "Professores podem excluir conteúdo" on public.site_content;
create policy "Professores podem excluir conteúdo"
  on public.site_content
  for delete
  to authenticated
  using ((select public.is_teacher_admin()));

insert into public.site_content
  (key, page_slug, section_slug, label, content_type, value, sort_order)
values
  ('home.title', 'home', 'cabecalho', 'Título principal', 'text', 'Teacher Flávio', 10),
  ('home.subtitle', 'home', 'cabecalho', 'Texto de apresentação', 'textarea', 'Escolha uma opção para acessar sua área ou conhecer melhor as aulas de inglês.', 20),
  ('home.hero_image', 'home', 'cabecalho', 'Imagem de destaque (opcional)', 'image', '', 30),
  ('home.student_title', 'home', 'card_aluno', 'Título do card do aluno', 'text', 'JÁ SOU ALUNO', 40),
  ('home.student_description', 'home', 'card_aluno', 'Descrição do card do aluno', 'textarea', 'Acesse matrícula, área do estudante, links das aulas e conteúdos do curso.', 50),
  ('home.student_url', 'home', 'card_aluno', 'Destino do card do aluno', 'url', '/aluno.html', 60),
  ('home.visitor_title', 'home', 'card_visitante', 'Título do card de visitante', 'text', 'QUERO CONHECER', 70),
  ('home.visitor_description', 'home', 'card_visitante', 'Descrição do card de visitante', 'textarea', 'Veja as opções para começar seus estudos de inglês com o Teacher Flávio.', 80),
  ('home.visitor_url', 'home', 'card_visitante', 'Destino do card de visitante', 'url', '/quero_conhecer.html', 90)
on conflict (key) do nothing;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'cms-media',
  'cms-media',
  true,
  5242880,
  array['image/jpeg', 'image/png', 'image/webp', 'image/gif']
)
on conflict (id) do update
set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Professores podem enviar imagens do CMS" on storage.objects;
create policy "Professores podem enviar imagens do CMS"
  on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id = 'cms-media'
    and (select public.is_teacher_admin())
  );

drop policy if exists "Professores podem atualizar imagens do CMS" on storage.objects;
create policy "Professores podem atualizar imagens do CMS"
  on storage.objects
  for update
  to authenticated
  using (
    bucket_id = 'cms-media'
    and (select public.is_teacher_admin())
  )
  with check (
    bucket_id = 'cms-media'
    and (select public.is_teacher_admin())
  );

drop policy if exists "Professores podem excluir imagens do CMS" on storage.objects;
create policy "Professores podem excluir imagens do CMS"
  on storage.objects
  for delete
  to authenticated
  using (
    bucket_id = 'cms-media'
    and (select public.is_teacher_admin())
  );

commit;
