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
- separar tecnicamente o encerramento da conta da retenção seletiva de registros financeiros.

## Inventário principal

| Categoria | Exemplos | Local/fornecedor principal | Finalidade | Retenção operacional | Exclusão/observação |
| --- | --- | --- | --- | --- | --- |
| Conta e identidade | nome, e-mail, ID, metadados de autenticação | Supabase Auth / `profiles` | login, conta e identificação do aluno | durante a relação e pelo período justificável após o término | no encerramento concluído, Auth e perfil são eliminados |
| Matrícula | CPF, WhatsApp, código de matrícula | Supabase `profiles` e estruturas de matrícula | matrícula, identificação e contato | durante a relação e pelo período justificável | removidos no fluxo de encerramento; CPF exige cuidado reforçado por impacto em caso de vazamento |
| Reembolso | chave PIX | Supabase `profiles` / `student_private_data` | eventual devolução de valores | enquanto houver necessidade operacional/financeira | removida quando a conta é encerrada e não há finalidade operacional remanescente |
| Disponibilidade | dias e horários | Supabase `profiles` | formação/gestão de turmas | enquanto necessária à organização das aulas | removida com o perfil no encerramento |
| Acadêmicos | turma, frequência, lições, exercícios, progresso, reposições, flashcards | Supabase | prestação do serviço e acompanhamento pedagógico | enquanto necessário ao serviço e histórico justificável | o fluxo de encerramento remove os registros operacionais vinculados ao titular |
| Financeiros | mensalidades, valores, status, identificadores e eventos de pagamento | Supabase + Mercado Pago | cobrança, conciliação, estorno e comprovação | conforme obrigação legal/regulatória/contábil e exercício de direitos | `monthly_tuition` e `tuition_payment_attempts` usam `subject_ref` pseudônimo; `student_id` passa a `NULL` quando o perfil é excluído; notas livres de pagamento são removidas |
| Cartão | dados necessários ao checkout | Mercado Pago | processar pagamento | segundo o provedor e obrigações aplicáveis | o banco acadêmico não deve armazenar número completo do cartão ou CVV |
| Acessos de alunos | user_id, data/hora, caminho, título, timezone | `student_access_logs` | acompanhamento operacional/acadêmico e segurança | máximo de 90 dias | removidos no encerramento e também sujeitos à limpeza de retenção |
| E-mail transacional | endereço e conteúdo operacional | Resend + Edge Functions | confirmações necessárias | conforme necessidade transacional e configuração do provedor | notificações internas vinculadas ao aluno são removidas no encerramento; evitar conteúdo excessivo |
| Analytics | página, origem, eventos, conversão e atributos técnicos | Google Analytics + storage do navegador | mensuração e CRO | somente após consentimento; retenção conforme configuração da propriedade e necessidade | desligar após revogação; limpar estados locais próprios e cookies GA quando possível |
| Consentimento | versão, categorias, data e expiração | `localStorage` do navegador | provar e respeitar a preferência no dispositivo | 180 dias na versão atual | usuário pode alterar antes do prazo; nova versão relevante invalida preferência anterior |
| Solicitações de privacidade | tipo, status, datas, referência do titular e resolução | `data_subject_requests` | registrar e demonstrar o atendimento ao titular | somente pelo período necessário à prestação de contas e defesa de direitos | nome/e-mail temporários são removidos quando o pedido é concluído; fica somente referência pseudônima e registro mínimo do atendimento |

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
10. Se o aluno possuir objetos próprios no Supabase Storage, o encerramento é bloqueado até que os arquivos sejam removidos ou tenham a propriedade transferida.

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

- **Perfil → Privacidade e meus dados**, para pedido de encerramento da conta;
- WhatsApp indicado na Política de Privacidade, para demais solicitações e suporte.

Fluxo operacional para cada solicitação:

1. registrar data, titular e tipo da solicitação sem coletar documentação excessiva;
2. verificar identidade de forma proporcional ao risco;
3. localizar dados em Auth, banco, pagamentos e fornecedores aplicáveis;
4. avaliar obrigação de conservação antes da exclusão;
5. executar correção, exportação, bloqueio, anonimização ou exclusão conforme o caso;
6. confirmar ao titular o resultado e eventuais dados mantidos com a justificativa correspondente;
7. guardar somente o registro mínimo necessário para demonstrar o atendimento.

## Pontos que exigem revisão periódica

- conferir se a retenção da propriedade do Google Analytics está configurada de acordo com a política publicada;
- revisar periodicamente os registros financeiros pseudonimizados e eliminá-los quando terminar o fundamento de conservação;
- revisar logs das Edge Functions e provedores para evitar retenção desnecessária de payloads;
- testar semestralmente a recusa e a revogação de Analytics;
- testar periodicamente os dois cenários de encerramento: sem histórico financeiro e com retenção financeira;
- revisar a política sempre que houver novo fornecedor, nova finalidade ou nova categoria de dado;
- manter as migrations como fonte de verdade da rotina de encerramento e não restaurar versões antigas de `delete_teacher_student`.
