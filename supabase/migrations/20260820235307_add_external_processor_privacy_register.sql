create table if not exists public.external_data_processors (
  processor_key text primary key,
  provider_name text not null,
  service_scope text not null,
  data_categories text[] not null default '{}'::text[],
  purpose text not null,
  provider_retention text not null,
  internal_control text not null,
  verification_status text not null default 'pending',
  last_verified_at timestamptz,
  next_review_at date not null,
  official_reference text,
  notes text,
  updated_at timestamptz not null default now(),
  constraint external_data_processors_status_check check (verification_status in ('pending','verified','action_required')),
  constraint external_data_processors_key_check check (processor_key ~ '^[a-z0-9_]+$'),
  constraint external_data_processors_notes_length_check check (notes is null or length(notes) <= 4000)
);

create table if not exists public.external_data_processor_reviews (
  id uuid primary key default gen_random_uuid(),
  processor_key text not null references public.external_data_processors(processor_key) on delete cascade,
  status text not null,
  note text not null,
  reviewed_at timestamptz not null default now(),
  reviewed_by uuid,
  constraint external_data_processor_reviews_status_check check (status in ('pending','verified','action_required')),
  constraint external_data_processor_reviews_note_length_check check (length(note) between 1 and 4000)
);

create index if not exists external_data_processor_reviews_key_date_idx
  on public.external_data_processor_reviews (processor_key, reviewed_at desc);
create index if not exists external_data_processors_review_due_idx
  on public.external_data_processors (verification_status, next_review_at);

alter table public.external_data_processors enable row level security;
alter table public.external_data_processor_reviews enable row level security;
revoke all on public.external_data_processors from anon, authenticated;
revoke all on public.external_data_processor_reviews from anon, authenticated;

insert into public.external_data_processors (
  processor_key, provider_name, service_scope, data_categories, purpose,
  provider_retention, internal_control, verification_status, last_verified_at,
  next_review_at, official_reference, notes
) values
  (
    'google_analytics', 'Google Analytics', 'Mensuração opcional do site',
    array['navegação','eventos','atributos técnicos'],
    'Mensuração de uso e conversão somente após consentimento.',
    'GA4 permite retenção configurável; para propriedades padrão, dados de usuário/evento podem ser configurados para 2 ou 14 meses.',
    'Carregar somente após consentimento; negar ad_storage/ad_user_data/ad_personalization; meta operacional: confirmar 2 meses e Reset on new activity desativado.',
    'pending', null, date '2026-08-27',
    'https://support.google.com/analytics/answer/7667196',
    'A configuração efetiva da propriedade deve ser confirmada no painel do Google Analytics antes de marcar como verificada.'
  ),
  (
    'supabase_platform', 'Supabase', 'Auth, banco, Storage, Edge Functions e logs da plataforma',
    array['conta','acadêmicos','financeiros','logs técnicos','arquivos'],
    'Infraestrutura principal do portal.',
    'Logs da plataforma possuem retenção dependente do plano; dados do banco/Storage seguem o ciclo de vida definido pelo controlador.',
    'Expurgo próprio no Postgres para logs selecionados; revisar período real dos logs de plataforma e evitar PII em console.error.',
    'pending', null, date '2026-08-27',
    'https://supabase.com/pricing',
    'Confirmar o plano ativo e a retenção efetiva dos logs de API, banco, Auth e Edge Functions.'
  ),
  (
    'resend', 'Resend', 'E-mails transacionais e administrativos',
    array['endereço de e-mail','conteúdo transacional'],
    'Envio de confirmações e notificações necessárias à operação.',
    'O provedor declara conservar dados somente pelo tempo necessário às finalidades e obrigações aplicáveis; não foi identificado prazo fixo público para o conteúdo de e-mails enviados.',
    'Minimizar conteúdo; não enviar CPF/PIX; retirar PII desnecessário de alertas administrativos; revisar histórico e controles da conta Resend.',
    'pending', null, date '2026-08-27',
    'https://resend.com/legal/privacy-policy',
    'E-mails destinados ao próprio aluno podem conter os dados estritamente necessários à mensagem transacional.'
  ),
  (
    'mercado_pago', 'Mercado Pago', 'Processamento e confirmação de pagamentos',
    array['e-mail','identificação do pagador quando necessária','valor','método','status de pagamento'],
    'Cobrança, Pix/cartão, conciliação, estorno e comprovação.',
    'O provedor conserva dados conforme necessidade operacional e obrigações legais; não há prazo único aplicável a todos os registros financeiros.',
    'Backend não armazena PAN/CVV; usa token de cartão e persiste localmente somente IDs/status/valor/método/timestamps necessários à conciliação.',
    'verified', now(), date '2027-02-20',
    'https://www.mercadopago.com.br/developers/pt/docs/resources/legal/terms-and-conditions',
    'Revisão técnica do payload local concluída em 20/08/2026. Retenção financeira continua sujeita a obrigação legal e exercício de direitos.'
  ),
  (
    'google_forms', 'Google Forms / Sheets', 'Coleta de conclusão de exercícios',
    array['e-mail','exercício','data de conclusão'],
    'Sincronizar respostas de exercícios com o progresso do aluno.',
    'Respostas e planilhas permanecem na conta Google até exclusão/limpeza conforme configuração do proprietário.',
    'Eventos copiados para o Postgres têm expurgo de 90 dias; aliases deixam de ficar hardcoded no repositório e passam a ser consultados no banco.',
    'pending', null, date '2026-08-27',
    'https://support.google.com/docs/answer/2839588',
    'Definir e confirmar rotina de limpeza das respostas brutas/planilhas que já tenham sido sincronizadas e não precisem permanecer no Google.'
  ),
  (
    'azure_speech', 'Microsoft Azure Speech', 'Avaliação de pronúncia em tempo real',
    array['áudio de voz','texto de referência'],
    'Gerar avaliação de pronúncia para atividades acadêmicas.',
    'A documentação da Microsoft informa que Pronunciation Assessment em tempo real não retém os dados enviados pelo cliente no serviço.',
    'Áudio e resultado que o portal decide manter são armazenados no Supabase e seguem o ciclo de vida da conta; o provedor Azure é usado apenas durante a requisição.',
    'verified', now(), date '2027-02-20',
    'https://learn.microsoft.com/azure/ai-services/speech-service/speech-data-privacy-security',
    'Revisão baseada no fluxo real da Edge Function pronunciation-assess e na documentação oficial do Azure Speech.'
  ),
  (
    'netlify', 'Netlify', 'Hospedagem e entrega do frontend público',
    array['dados técnicos de requisição','IP e logs de entrega quando gerados pela plataforma'],
    'Hospedar e entregar o site teacherflavius.com.',
    'Retenção de logs e dados de plataforma depende do produto/plano e dos controles do provedor.',
    'Frontend não deve enviar dados cadastrais sensíveis ao Netlify; confirmar controles de logs/analytics da conta e manter formulários Netlify desativados quando não utilizados.',
    'pending', null, date '2026-08-27',
    'https://www.netlify.com/privacy/',
    'O site está hospedado no Netlify; GitHub é usado como repositório de código e não deve conter PII operacional de alunos.'
  )
on conflict (processor_key) do update set
  provider_name = excluded.provider_name,
  service_scope = excluded.service_scope,
  data_categories = excluded.data_categories,
  purpose = excluded.purpose,
  provider_retention = excluded.provider_retention,
  internal_control = excluded.internal_control,
  official_reference = excluded.official_reference,
  notes = excluded.notes,
  updated_at = now();

create or replace function public.get_external_data_processor_dashboard()
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  result jsonb;
begin
  if not coalesce(public.is_teacher_admin(), false) then
    raise exception 'Acesso negado: usuário não cadastrado como professor.' using errcode = '42501';
  end if;

  select jsonb_build_object(
    'generated_at', now(),
    'summary', jsonb_build_object(
      'total', count(*),
      'verified', count(*) filter (where verification_status = 'verified'),
      'pending', count(*) filter (where verification_status = 'pending'),
      'action_required', count(*) filter (where verification_status = 'action_required'),
      'overdue', count(*) filter (where next_review_at < current_date)
    ),
    'processors', coalesce(jsonb_agg(jsonb_build_object(
      'processor_key', processor_key,
      'provider_name', provider_name,
      'service_scope', service_scope,
      'data_categories', data_categories,
      'purpose', purpose,
      'provider_retention', provider_retention,
      'internal_control', internal_control,
      'verification_status', verification_status,
      'last_verified_at', last_verified_at,
      'next_review_at', next_review_at,
      'official_reference', official_reference,
      'notes', notes
    ) order by provider_name), '[]'::jsonb)
  ) into result
  from public.external_data_processors;

  return result;
end;
$$;

revoke all on function public.get_external_data_processor_dashboard() from public, anon;
grant execute on function public.get_external_data_processor_dashboard() to authenticated;

create or replace function public.review_external_data_processor(
  p_processor_key text,
  p_status text,
  p_note text
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  normalized_key text := lower(btrim(coalesce(p_processor_key, '')));
  normalized_status text := lower(btrim(coalesce(p_status, '')));
  normalized_note text := nullif(btrim(coalesce(p_note, '')), '');
  review_id uuid;
  next_review date;
begin
  if not coalesce(public.is_teacher_admin(), false) then
    raise exception 'Acesso negado: usuário não cadastrado como professor.' using errcode = '42501';
  end if;
  if normalized_status not in ('pending','verified','action_required') then
    raise exception 'Status de revisão inválido.' using errcode = '22023';
  end if;
  if normalized_note is null or length(normalized_note) > 4000 then
    raise exception 'Registre uma nota entre 1 e 4000 caracteres.' using errcode = '22023';
  end if;
  if not exists (select 1 from public.external_data_processors where processor_key = normalized_key) then
    raise exception 'Fornecedor não encontrado.' using errcode = 'P0002';
  end if;

  next_review := case when normalized_status = 'verified' then current_date + 180 else current_date + 30 end;

  insert into public.external_data_processor_reviews (processor_key, status, note, reviewed_by)
  values (normalized_key, normalized_status, normalized_note, auth.uid())
  returning id into review_id;

  update public.external_data_processors
     set verification_status = normalized_status,
         last_verified_at = now(),
         next_review_at = next_review,
         updated_at = now()
   where processor_key = normalized_key;

  return jsonb_build_object(
    'ok', true,
    'review_id', review_id,
    'processor_key', normalized_key,
    'status', normalized_status,
    'next_review_at', next_review
  );
end;
$$;

revoke all on function public.review_external_data_processor(text,text,text) from public, anon;
grant execute on function public.review_external_data_processor(text,text,text) to authenticated;