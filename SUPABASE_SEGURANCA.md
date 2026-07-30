# Segurança do Supabase

## Fase 1 — permissões de funções

O arquivo `supabase_seguranca_fase1.sql` fecha duas classes de alertas do
Security Advisor sem alterar tabelas nem dados:

- remove de `anon` a execução das funções do schema `public`;
- concede a `authenticated` somente as RPCs usadas pelo site;
- mantém `service_role` disponível para Edge Functions e rotinas confiáveis;
- define um `search_path` seguro nas seis funções de trigger sinalizadas;
- altera os privilégios padrão para que funções novas não nasçam públicas;
- valida os invariantes antes do `commit`.

O script não altera RLS, usuários, matrículas, turmas, lições, exercícios,
reposições ou mensalidades.

## Como aplicar

1. Faça o merge da PR que contém estes arquivos.
2. No painel do Supabase, abra **SQL Editor** e crie uma consulta nova.
3. Copie todo o conteúdo de `supabase_seguranca_fase1.sql`.
4. Execute uma única vez.
5. Confirme que o resultado final mostra:
   - `anon_security_definer_executable = 0`
   - `mutable_search_path_targets = 0`

Se qualquer função necessária estiver ausente, a verificação gera um erro e a
transação é desfeita por inteiro.

## Teste rápido depois da aplicação

Teste em uma janela anônima para evitar uma sessão antiga:

1. Aluno:
   - entrar no portal;
   - abrir o roteiro de estudos e o portal de exercícios;
   - consultar e agendar uma reposição;
   - cancelar uma reposição permitida;
   - abrir o próprio perfil.
2. Professor:
   - abrir turmas e uma turma;
   - consultar alunos, lições e acessos;
   - abrir reposições, questionários e mensalidades;
   - salvar uma alteração simples e reversível.
3. Sair da conta e confirmar que as páginas protegidas continuam exigindo login.

## Rollback emergencial

Se uma área autenticada retornar `permission denied for function ...`, execute
`supabase_seguranca_fase1_rollback.sql`. Ele restaura temporariamente a execução
das funções para `authenticated`, sem reabrir o acesso de `anon`.

Depois, registre o nome exato da função no erro para adicioná-la à lista
explícita da Fase 1 antes de reaplicar o script principal.

## Próximas fases

- revisar as políticas RLS duplicadas e limitar políticas que ainda usam o papel
  `public`;
- ativar proteção contra senhas comprometidas no Supabase Auth;
- revisar as Edge Functions públicas e desativar funções antigas após confirmar
  que não recebem mais eventos;
- corrigir índices ausentes e consultas apontadas pelo Performance Advisor.
