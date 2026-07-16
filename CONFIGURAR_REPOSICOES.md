# Configurar a agenda de reposições

A funcionalidade possui quatro partes:

1. `supabase_reposicoes.sql` cria horários, reservas, permissões e a fila de e-mails.
2. `reposicoes_admin.html` permite que o professor publique horários e acompanhe as reservas.
3. `reposicoes.html` permite que alunos matriculados reservem e cancelem reposições futuras.
4. `supabase/functions/notify-makeup-booking/index.ts` envia confirmações de agendamento e cancelamento pelo Resend.

Ao publicar um horário, o professor escolhe uma turma. O sistema recupera o **Link da videoaula** dessa turma e salva uma cópia junto ao horário. Todos os alunos matriculados podem visualizar e reservar qualquer vaga disponível, mesmo quando ela está associada a outra turma. A reserva e o e-mail usam exatamente o link copiado no horário escolhido.

Se a turma não tiver um link `http://` ou `https://` válido, o botão de publicação fica desabilitado e o banco também rejeita a operação. Assim, nenhum horário novo é publicado sem o link que deverá chegar ao aluno.

## 1. Fazer o merge e executar o SQL

Primeiro faça o merge do Pull Request. Depois:

1. Abra o projeto no Supabase.
2. Entre em **SQL Editor**.
3. Crie uma nova consulta.
4. Copie todo o conteúdo de `supabase_reposicoes.sql`.
5. Clique em **Run**.

Execute o arquivo depois de `supabase_turmas.sql`, pois ele reutiliza as turmas, os vínculos dos alunos, `class_resources.video_lesson_url`, `is_teacher_admin()` e `set_updated_at()`.

O arquivo é compatível com a agenda já instalada. Ao executá-lo novamente, horários antigos que já possuem reservas de uma única turma são associados a essa turma. Horários antigos que ainda não permitem identificar uma turma e um link são desativados por segurança e devem ser publicados novamente.

## 2. Conferir os Secrets existentes

Não é necessário criar outra API Key no Resend. A nova função reutiliza os Secrets que já enviam o aviso de matrícula:

- `RESEND_API_KEY`
- `ENROLLMENT_FROM_EMAIL`
- `ENROLLMENT_WEBHOOK_SECRET`

O valor de `ENROLLMENT_WEBHOOK_SECRET` será usado novamente no cabeçalho privado do novo webhook. Não coloque esses valores em arquivos públicos do site.

## 3. Publicar a nova Edge Function

Pelo terminal, dentro do repositório já vinculado ao projeto Supabase, execute:

```bash
npx supabase functions deploy notify-makeup-booking --no-verify-jwt
```

Também é possível abrir **Edge Functions** no painel, escolher **Deploy a new function > Via Editor**, usar o nome `notify-makeup-booking` e colar o conteúdo de `supabase/functions/notify-makeup-booking/index.ts`.

A validação JWT fica desativada porque a chamada vem do Database Webhook. A função exige o cabeçalho `x-webhook-secret` e compara o valor com o Secret salvo no projeto.

Para habilitar o e-mail de cancelamento, **é necessário republicar a função `notify-makeup-booking`** com esta versão. A mesma função passa a escolher automaticamente o modelo de agendamento ou de cancelamento.

## 4. Criar o Database Webhook

No painel do Supabase, abra a área de **Database Webhooks** (em algumas versões do painel ela aparece em **Integrations > Webhooks**) e crie um webhook com:

- Nome: `notify-makeup-booking`
- Tabela: `public.makeup_class_email_notifications`
- Evento: somente **Insert**
- Método: `POST`
- URL: `https://SEU_PROJECT_REF.supabase.co/functions/v1/notify-makeup-booking`
- Cabeçalho `x-webhook-secret`: o mesmo valor de `ENROLLMENT_WEBHOOK_SECRET`
- Cabeçalho `Content-Type`: `application/json`

Database Webhooks do Supabase são executados depois da alteração na tabela e enviam o registro inserido para a URL configurada.

Se esse webhook já está funcionando, **não é necessário recriá-lo**.

## 5. Testar o fluxo completo

1. Na área do professor, abra **AGENDA DE REPOSIÇÕES**.
2. Escolha uma turma que possua **Link da videoaula**.
3. Confira o link recuperado na tela e publique um horário futuro com uma vaga.
4. Entre com o usuário do aluno e abra **REPOSIÇÕES DE AULA**.
5. Confirme que o aluno vê todos os horários disponíveis, inclusive os associados a outras turmas, e reserve um deles.
6. Confira o e-mail de agendamento do aluno.
7. Na seção **Minhas reposições**, cancele a reserva futura e confirme que ela passa ao estado **Cancelada**.
8. Confira o e-mail de cancelamento e verifique se a vaga voltou aos horários disponíveis.
9. Na área do professor, confirme que a reserva aparece como cancelada.

Para diagnosticar o envio no SQL Editor:

```sql
select
  n.notification_type,
  n.status,
  n.attempts,
  n.last_error,
  n.created_at,
  b.student_name,
  b.student_email,
  b.class_name,
  b.status as booking_status
from public.makeup_class_email_notifications n
join public.makeup_class_bookings b on b.id = n.booking_id
order by n.created_at desc
limit 20;
```

- `booking_confirmation`: e-mail enviado quando a reposição é agendada.
- `cancellation`: e-mail enviado quando o próprio aluno cancela uma reposição futura.
- `pending` e `attempts = 0`: o webhook ainda não chamou a função; revise o webhook.
- `failed`: consulte `last_error` e os logs de `notify-makeup-booking`.
- `sent`: o Resend aceitou o envio.

O envio usa uma chave de idempotência por tipo de notificação para reduzir o risco de mensagens duplicadas.

O cancelamento exige a execução da versão atualizada de `supabase_reposicoes.sql`. A função de banco confere se a reserva pertence ao usuário conectado, permite cancelar somente antes do início da aula, libera a vaga e cria a notificação de cancelamento na mesma transação.
