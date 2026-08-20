# Mapa de dados pessoais — Teacher Flávio

Versão: 2026-08-20

Este documento é um inventário operacional. Ele deve ser atualizado quando houver nova tabela, fornecedor, finalidade, formulário, evento analítico ou integração que trate dados pessoais.

## Princípios adotados

- coletar somente dados necessários para finalidades definidas;
- separar dados necessários à prestação do serviço de dados opcionais de Analytics;
- aplicar RLS, menor privilégio e funções de servidor para operações privilegiadas;
- não enviar CPF, WhatsApp, e-mail, chave PIX ou conteúdo de formulário para Analytics;
- eliminar ou anonimizar dados quando a finalidade terminar, ressalvadas hipóteses legais de conservação;
- manter uma forma simples de o titular acessar políticas, rever consentimento e solicitar direitos;
- separar tecnicamente o encerramento da conta da retenção seletiva de registros financeiros;
- evitar duplicar dados pessoais para atender solicitações de acesso: a exportação automática é gerada sob demanda e não é armazenada novamente no banco;
- automatizar apenas expurgos com finalidade operacional clara e prazo definido, mantendo dados financeiros, solicitações LGPD e registros acadêmicos/cadastrais fora de deleções automáticas por idade.

## Inventário principal

| Categoria | Exemplos | Local/fornecedor principal | Finalidade | Retenção operacional | Exclusão/observação |
| --- | --- | --- | --- | --- | --- |
| Conta e identidade | nome, e-mail, ID, metadados de autenticação | Supabase Auth / `profiles` | login, conta e identificação do aluno | durante a relação e pelo período justificável após o término | no encerramento concluído, Auth e perfil são eliminados |
| Matrícula | CPF, WhatsApp, código de matrícula | Supabase `profiles` e estruturas de matrícula | matrícula, identificação e contato | durante a relação e pelo período justificável | removidos no fluxo de encerramento; CPF exige cuidado reforçado por impacto em caso de vazamento |
| Reembolso | chave PIX | Supabase `profiles` / `student_private_data` | eventual devolução de valores | enquanto houver necessidade operacional/financeira | removida quando a conta é encerrada e não há finalidade operacional remanescente |
| Disponibilidade | dias e horários | Supabase `profiles` | formação/gestão de turmas | enquanto necessária à organização das aulas | removida com o perfil no encerramento |
| Acadêmicos | turma, frequência, lições, exercícios, progresso, reposições, flashcards | Supabase | prestação do serviço e acompanhamento pedagógico | enquanto necessário ao serviço e histórico justificável | o fluxo de encerramento remove os registros operacionais vinculados ao titular |
| Financeiros | mensalidades, valores, status, identificadores e eventos de pagamento | Supabase + Mercado Pago | cobrança, conciliação, estorno e comprovação | conforme obrigação legal/regulatória/contábil e exercício de direitos | `monthly_tuition` e `tuition_payment_attempts` usam `subject_ref` pseudônimo; não entram no expurgo automático |
| Cartão | dados necessários ao checkout | Mercado Pago | processar pagamento | segundo o provedor e obrigações aplicáveis | o banco acadêmico não deve armazenar número completo do cartão ou CVV |
| Acessos de alunos | user_id, data/hora, caminho, título, timezone | `student_access_logs` | acompanhamento operacional/acadêmico e segurança | máximo de 90 dias | expurgo diário por `pg_cron` e remoção no encerramento da conta |
| Erros da aplicação | tipo, severidade, mensagem técnica, caminho, fingerprint, metadados reduzidos | `app_error_events` | diagnóstico, segurança e correção de falhas | 90 dias | expurgo diário; falhas da própria manutenção também são registradas aqui |
| Relatórios CSP | diretiva, recurso bloqueado, origem, linha/coluna, referrer | `csp_violation_reports` | diagnosticar violações da Content Security Policy | 30 dias | expurgo diário por ser dado técnico de curto prazo |
| Eventos de sincronização | exercício, status, e-mail normalizado, usuário, erro e metadados | `exercise_sync_events` | diagnóstico da integração de exercícios | 90 dias | expurgo diário e remoção no encerramento da conta |
| E-mail transacional | endereço e conteúdo operacional | Resend + Edge Functions | confirmações necessárias | conforme necessidade transacional e configuração do provedor | notificações internas vinculadas ao aluno são removidas no encerramento; evitar conteúdo excessivo |
| Analytics | página, origem, eventos, conversão e atributos técnicos | Google Analytics + storage do navegador | mensuração e CRO | somente após consentimento; retenção conforme configuração da propriedade e necessidade | desligar após revogação; limpar estados locais próprios e cookies GA quando possível |
| Consentimento | versão, categorias, data e expiração | `localStorage` do navegador | provar e respeitar a preferência no dispositivo | 180 dias na versão atual | usuário pode alterar antes do prazo; nova versão relevante invalida preferência anterior |
| Solicitações de privacidade | tipo, detalhes, status, datas, referência do titular e resposta | `data_subject_requests` | registrar e demonstrar o atendimento ao titular | sem prazo automático nesta fase | nome/e-mail temporários são removidos quando o pedido é concluído; eliminação integral exige revisão de prestação de contas |
| Snapshots legados | cópias de maio/2026 de Auth, perfis e dados privados | tabelas `backup_*_20260501` | recuperação histórica | revisão manual | novas exclusões de Auth/perfil removem também a linha correspondente dos snapshots; revisão integral prevista para 28/10/2026 |

## Política automatizada de retenção

A tabela `data_retention_policies` é a fonte operacional dos prazos. Ela separa conjuntos com **expurgo automático** daqueles que exigem **revisão manual**.

Conjuntos atualmente automatizados:

| Conjunto | Prazo | Coluna de corte | Execução |
| --- | ---: | --- | --- |
| `student_access_logs` | 90 dias | `accessed_at` | diária |
| `app_error_events` | 90 dias | `created_at` | diária |
| `csp_violation_reports` | 30 dias | `created_at` | diária |
| `exercise_sync_events` | 90 dias | `received_at` | diária |

O job `daily-data-retention-maintenance` roda via `pg_cron` todos os dias às **05:35 UTC (02:35 no horário de Brasília)**. A função interna `perform_data_retention_maintenance()` não possui `EXECUTE` para `anon` nem `authenticated`. A execução manual disponível na Área do Professor passa por `run_data_retention_maintenance_now()`, que exige `is_teacher_admin()`.

Cada execução grava em `data_retention_runs`:

- origem (`cron` ou manual);
- início e conclusão;
- status;
- quantidade removida por conjunto;
- mensagem de erro, quando houver.

O histórico técnico de execuções da própria retenção é limitado a 365 dias. Uma trava consultiva impede duas execuções simultâneas.

### Conjuntos deliberadamente fora do expurgo automático

- `data_subject_requests`: permanece em registro mínimo pseudonimizado; prazo integral depende de revisão jurídica e de accountability;
- registros financeiros: conservação depende de obrigação legal/regulatória/contábil e exercício de direitos;
- dados acadêmicos e cadastrais: seguem o ciclo de prestação do serviço e o fluxo de encerramento da conta;
- snapshots legados: ficam em revisão manual até confirmação de que não há mais necessidade de recuperação.

O painel **Área do Professor → Retenção de dados** mostra políticas, contagens, registros atualmente elegíveis, próxima revisão, cron e última execução.

## Limpeza de dados em backups legados

Foram adicionados gatilhos `BEFORE DELETE` em `auth.users` e `profiles`. Quando uma conta/perfil é removido, a mesma UUID é removida, quando presente, de:

- `backup_profiles_20260501`;
- `backup_auth_users_metadata_20260501`;
- `backup_student_private_data_20260501`.

Isso evita que uma solicitação de exclusão concluída deixe uma cópia residual de CPF, e-mail, WhatsApp, PIX ou metadados nos snapshots antigos.

## Central de direitos do titular

A área **Perfil → Privacidade e meus dados** concentra os seguintes recursos:

1. **Cópia automática dos dados**: a RPC `get_my_data_export()` usa exclusivamente `auth.uid()` e gera um JSON com os principais dados diretamente associados à sessão autenticada. O navegador cria o arquivo localmente; o portal não grava uma segunda cópia do conteúdo exportado.
2. **Correções simples**: nome, CPF, WhatsApp, chave PIX e disponibilidade continuam editáveis diretamente no perfil.
3. **Acesso adicional**: o titular pode registrar pedido formal quando a cópia automática não for suficiente ou quando precisar de esclarecimento sobre outros dados.
4. **Correção formal**: para dados que não podem ser alterados diretamente pelo aluno, o pedido registra o item incorreto e a correção solicitada.
5. **Anonimização ou bloqueio**: o titular pode indicar quais dados considera inadequados, excessivos ou desnecessários para análise administrativa.
6. **Informações sobre compartilhamentos**: o titular pode pedir esclarecimentos sobre fornecedores, integrações ou categorias de compartilhamento.
7. **Encerramento da conta**: permanece separado por ser a única operação destrutiva do fluxo.

Os pedidos não destrutivos usam `create_data_subject_request`, `mark_data_subject_request_in_review` e `complete_data_subject_request`. A conclusão exige que o professor registre uma resposta ao titular. O aluno pode cancelar pedidos ainda em status `open`.

## Escopo da cópia automática

A exportação automática inclui, quando existentes: conta e identidades de autenticação, perfil, dados privados, matrícula, vínculo com turma, frequência, resultados e progresso acadêmico, planos semanais, flashcards e histórico de prática, reposições, tentativas de pronúncia em formato reduzido, logs próprios de acesso, tags, eventos de sincronização relevantes, configurações de cobrança, mensalidades, tentativas de pagamento e metadados dos arquivos pertencentes ao usuário no Storage.

Por segurança e minimização, o arquivo automático não inclui segredos operacionais, `idempotency_key`, identificadores administrativos de quem realizou alterações, nem o payload bruto e potencialmente volumoso do provedor de pronúncia. O titular pode pedir acesso adicional formalmente quando necessário.

## Ciclo operacional de encerramento da conta

O fluxo implementado usa `data_subject_requests` e RPCs com controle de acesso.

1. O aluno solicita o encerramento em **Perfil → Privacidade e meus dados**.
2. Enquanto o pedido estiver `open`, o próprio titular pode cancelá-lo.
3. O professor visualiza a fila em **Área do Professor → Solicitações de Privacidade** e pode marcar o pedido como `in_review`.
4. Na conclusão, a rotina identifica também contas Google/legadas vinculadas ao mesmo aluno.
5. Dados acadêmicos, de acesso, matrícula, disponibilidade, flashcards, cobrança futura, dados privados e aliases de e-mail são eliminados.
6. `auth.users` e `profiles` são excluídos. O `ON DELETE SET NULL` nos registros financeiros impede que o histórico necessário seja apagado em cascata.
7. Quando existe histórico financeiro, `subject_ref` conserva apenas o UUID pseudônimo que existia antes do encerramento; o relacionamento direto `student_id` é removido.
8. `payment_notes` e o campo equivalente em eventos são eliminados para reduzir conteúdo livre desnecessário.
9. A solicitação é marcada como `completed`; nome e e-mail são removidos do registro da solicitação e fica somente o mínimo necessário para auditoria.
10. A exclusão da conta/perfil também remove eventual cópia correspondente nos três snapshots legados de maio/2026.
11. Se o aluno possuir objetos próprios no Supabase Storage, o encerramento é bloqueado até que os arquivos sejam removidos ou tenham a propriedade transferida.

## Terceiros e transferências

Fornecedores atualmente identificados no projeto: Supabase, Mercado Pago, Resend, Google, GitHub Pages e WhatsApp/Meta. Antes de adicionar novos terceiros, revisar:

1. finalidade e dados compartilhados;
2. necessidade do compartilhamento;
3. termos/DPA do fornecedor;
4. localização do tratamento e eventual transferência internacional;
5. prazo de retenção;
6. mecanismo de exclusão/exportação;
7. segurança e resposta a incidentes.

## Direitos dos titulares

Canais operacionais atuais:

- **Perfil → Privacidade e meus dados**, para cópia automática, acesso adicional, correção, anonimização/bloqueio, informações sobre compartilhamentos e pedido de encerramento da conta;
- WhatsApp indicado na Política de Privacidade, para suporte complementar e situações em que o portal não seja suficiente.

Fluxo operacional para cada solicitação:

1. registrar data, titular, tipo e descrição necessária da solicitação sem coletar documentação excessiva;
2. verificar identidade de forma proporcional ao risco — para pedidos feitos dentro do portal, a sessão autenticada funciona como primeira camada de verificação;
3. localizar dados em Auth, banco, pagamentos e fornecedores aplicáveis;
4. avaliar obrigação de conservação antes de anonimização, bloqueio ou exclusão;
5. executar correção, exportação, bloqueio, anonimização ou exclusão conforme o caso;
6. registrar a resposta administrativa no pedido e disponibilizá-la ao titular pelo portal;
7. guardar somente o registro mínimo necessário para demonstrar o atendimento.

## Pontos que exigem revisão periódica

- conferir se a retenção da propriedade do Google Analytics está configurada de acordo com a política publicada;
- revisar periodicamente os registros financeiros pseudonimizados e eliminá-los quando terminar o fundamento de conservação;
- revisar os snapshots legados em 28/10/2026 e eliminar integralmente o que não tiver necessidade de recuperação remanescente;
- revisar logs das Edge Functions e provedores para evitar retenção desnecessária de payloads;
- testar semestralmente a recusa e a revogação de Analytics;
- revisar semestralmente os prazos de `data_retention_policies` e o estado do job `daily-data-retention-maintenance`;
- testar periodicamente os dois cenários de encerramento: sem histórico financeiro e com retenção financeira;
- testar periodicamente a exportação com usuários que possuam diferentes conjuntos de dados, garantindo que o resultado permaneça limitado a `auth.uid()`;
- revisar a política sempre que houver novo fornecedor, nova finalidade ou nova categoria de dado;
- manter as migrations como fonte de verdade da rotina de encerramento e não restaurar versões antigas de `delete_teacher_student`.
