# Backups, recuperação e rollback

Este documento define a estratégia operacional de recuperação do `teacherflavius.com`.

## Objetivos

- RPO operacional inicial: no máximo 24 horas para o banco de dados.
- Retenção inicial dos checkpoints independentes: 30 dias.
- Rollback de frontend: minutos, usando deploy anterior do Netlify ou commit conhecido do GitHub.
- Recuperação de banco: somente após identificar o ponto consistente anterior ao incidente.
- Nenhum backup contendo dados pessoais deve ser armazenado sem criptografia.

## Estado auditado em 2026-08-20

- Repositório principal: `Zoqvera/teacherflavius`.
- Branch de produção: `main`.
- Hospedagem: Netlify, projeto `teacherflavius`.
- Projeto Supabase: `wnigzpvgsbpjdxvjzugt`.
- Banco PostgreSQL: 17.x, aproximadamente 19 MB no momento da auditoria.
- O schema `public` possui dezenas de tabelas e o histórico de migrations do Supabase está ativo.
- Não existem buckets no Supabase Storage neste momento.
- O Netlify não possui variáveis de ambiente de projeto cadastradas neste momento.
- Migrations e Edge Functions relevantes estão versionadas em `supabase/migrations` e `supabase/functions`.
- A Edge Function de produção `bright-task` é uma versão legada/duplicada da rotina de notificação de matrícula. O trigger atual usa `notify-new-enrollment`; portanto, `bright-task` não é tratada como dependência de recuperação.

## 1. Backup do banco de dados

O workflow `.github/workflows/backup-recovery.yml` roda diariamente e também pode ser executado manualmente.

Ele:

1. valida os segredos necessários;
2. instala `pg_dump` compatível com PostgreSQL 17;
3. verifica se surgiram buckets no Supabase Storage;
4. cria um dump lógico completo do PostgreSQL em formato custom;
5. valida o dump com `pg_restore --list`;
6. cria um `git bundle` contendo o histórico completo do repositório;
7. gera um inventário dos nomes das variáveis exigidas pelas Edge Functions;
8. gera checksums;
9. criptografa o pacote com AES-256 e PBKDF2;
10. envia somente o pacote criptografado para um artifact do GitHub com retenção de 30 dias.

### Segredos obrigatórios no GitHub Actions

Criar no repositório, em Settings > Secrets and variables > Actions:

- `SUPABASE_DB_URL`: connection string PostgreSQL de produção. Preferir uma connection string compatível com IPv4/session pooler para runners externos.
- `BACKUP_ENCRYPTION_PASSPHRASE`: frase aleatória exclusiva, com pelo menos 24 caracteres. Não reutilizar senha pessoal, senha do banco ou chave de API.

A frase de criptografia não deve ficar no repositório, em documentação pública ou no próprio artifact.

## 2. Arquivos

Hoje os arquivos estáticos do site estão versionados no GitHub. O checkpoint inclui também um `repository.bundle`, permitindo reconstruir o histórico do repositório a partir do artifact criptografado.

O Supabase Storage não possui buckets atualmente. O workflow falha se detectar qualquer bucket no futuro, porque backups do banco preservam apenas metadados do Storage, não os objetos armazenados. Antes de voltar a considerar o backup saudável, será necessário adicionar uma rotina específica de cópia desses objetos.

## 3. Configurações

Configurações versionáveis devem permanecer no GitHub:

- `netlify.toml`;
- `_headers` e `_redirects` quando aplicáveis;
- scripts de build;
- `.github/workflows`;
- `supabase/migrations`;
- `supabase/functions`.

Segredos não devem ser copiados para o Git. O checkpoint guarda somente os nomes das variáveis exigidas pelas Edge Functions, nunca os valores.

Além do backup dos dados, manter fora do repositório um inventário seguro dos valores necessários para reconstrução, por exemplo chaves de e-mail, pagamentos, webhook secrets e demais secrets de Edge Functions.

## 4. Versões anteriores

Existem duas trilhas de versão:

### GitHub

Cada alteração de código tem commit próprio. O SHA do commit é registrado no `manifest.txt` de cada checkpoint.

### Netlify

Cada deploy bem-sucedido é atômico e pode ser republicado como a versão de produção. Isso permite rollback rápido do frontend sem recompilar o site.

Importante: republicar um deploy antigo no Netlify não reverte automaticamente o banco de dados.

## 5. Estratégia de rollback

### Cenário A — problema apenas no frontend

1. identificar o último deploy comprovadamente saudável;
2. republicar esse deploy no Netlify;
3. não restaurar o banco;
4. corrigir a causa no GitHub e publicar uma nova versão depois.

### Cenário B — código novo incompatível com schema atual

Preferir um forward fix ou uma migration corretiva quando os dados atuais precisam ser preservados. Restaurar o banco pode apagar gravações legítimas feitas depois do ponto restaurado.

### Cenário C — migration destrutiva ou corrupção de dados

1. interromper gravações que possam ampliar o dano;
2. registrar o SHA do frontend em produção e o horário exato do incidente;
3. escolher o checkpoint ou backup Supabase imediatamente anterior ao incidente;
4. restaurar primeiro em ambiente isolado quando possível;
5. validar tabelas críticas, autenticação, pagamentos e matrículas;
6. restaurar produção somente depois da validação;
7. alinhar a versão do frontend com o schema restaurado.

### Cenário D — perda do repositório

1. descriptografar o checkpoint;
2. verificar `SHA256SUMS`;
3. recriar o repositório a partir de `repository.bundle`;
4. restaurar configurações versionadas;
5. redeploy no Netlify.

### Cenário E — perda do projeto Supabase

Um backup de banco não reconstrói sozinho toda a plataforma. Depois de restaurar o PostgreSQL, também é necessário revisar/recriar:

- Edge Functions;
- secrets das Edge Functions;
- configurações de Auth/OAuth;
- webhooks;
- Realtime;
- extensões e configurações específicas do projeto;
- API keys novas e referências atualizadas no frontend.

## 6. Como descriptografar um checkpoint

```bash
sha256sum -c teacherflavius-*.tar.gz.enc.sha256
openssl enc -d -aes-256-cbc -pbkdf2 -iter 250000 \
  -in teacherflavius-YYYYMMDDTHHMMSSZ-SHA.tar.gz.enc \
  -out checkpoint.tar.gz \
  -pass env:BACKUP_ENCRYPTION_PASSPHRASE

tar -xzf checkpoint.tar.gz
```

Depois de extrair, validar os checksums internos antes de usar qualquer arquivo.

## 7. Como restaurar o dump em um banco de teste

Nunca testar restauração diretamente na produção como primeira opção.

```bash
pg_restore \
  --clean \
  --if-exists \
  --no-owner \
  --no-acl \
  --dbname="$TARGET_DATABASE_URL" \
  database.dump
```

Após a restauração, verificar no mínimo:

- login com conta normal e Google;
- tabela `profiles` e vínculos de identidade;
- mensalidades/pagamentos;
- flashcards;
- notificações e logs;
- migrations registradas;
- funções e triggers usados pelo fluxo de matrícula e pagamento.

## 8. Checkpoint antes de alterações de alto risco

Executar manualmente o workflow de backup antes de:

- migrations destrutivas;
- alterações de autenticação;
- mudanças na lógica de pagamento;
- exclusões em massa;
- alterações de constraints que modifiquem dados;
- limpeza de usuários ou perfis;
- grandes refatorações das Edge Functions.

Não iniciar a mudança de alto risco se o checkpoint manual falhar.

## 9. Limitações e próxima evolução

O artifact criptografado no GitHub melhora muito a recuperação operacional, mas ainda está no mesmo provedor do código. Para uma estratégia de disaster recovery mais forte, manter também uma cópia criptografada periódica em um segundo provedor/conta independente.

Se o volume de transações crescer e perder até 24 horas de dados deixar de ser aceitável, avaliar Point-in-Time Recovery (PITR) no Supabase para reduzir o RPO.
