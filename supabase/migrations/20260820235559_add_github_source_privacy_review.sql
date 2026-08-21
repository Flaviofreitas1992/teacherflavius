insert into public.external_data_processors (
  processor_key, provider_name, service_scope, data_categories, purpose,
  provider_retention, internal_control, verification_status, last_verified_at,
  next_review_at, official_reference, notes
) values (
  'github', 'GitHub', 'Versionamento e histórico do código-fonte',
  array['código-fonte','histórico de commits'],
  'Hospedar e versionar o código do site; não deve ser usado como armazenamento de dados pessoais operacionais de alunos.',
  'O histórico Git preserva versões anteriores até que o histórico seja reescrito ou o conteúdo seja removido pelos mecanismos apropriados da plataforma.',
  'Remover PII do código corrente; manter dados de alunos em tabelas protegidas/segredos. Revisar o histórico antigo antes de decidir por reescrita, pois force-push afeta clones, branches e referências.',
  'action_required', now(), date '2026-08-27',
  'https://docs.github.com/authentication/keeping-your-account-and-data-secure/removing-sensitive-data-from-a-repository',
  'Foram identificadas aliases de e-mail de alunos codificadas historicamente em uma Edge Function. O código corrente está sendo corrigido; a exposição histórica deve ser tratada em procedimento separado e controlado.'
)
on conflict (processor_key) do update set
  provider_name = excluded.provider_name,
  service_scope = excluded.service_scope,
  data_categories = excluded.data_categories,
  purpose = excluded.purpose,
  provider_retention = excluded.provider_retention,
  internal_control = excluded.internal_control,
  verification_status = excluded.verification_status,
  last_verified_at = excluded.last_verified_at,
  next_review_at = excluded.next_review_at,
  official_reference = excluded.official_reference,
  notes = excluded.notes,
  updated_at = now();