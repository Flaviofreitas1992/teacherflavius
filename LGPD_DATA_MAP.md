# Mapa de dados pessoais — Teacher Flávio

Versão inicial: 2026-08-20

Este documento é um inventário operacional. Ele deve ser atualizado quando houver nova tabela, fornecedor, finalidade, formulário, evento analítico ou integração que trate dados pessoais.

## Princípios adotados

- coletar somente dados necessários para finalidades definidas;
- separar dados necessários à prestação do serviço de dados opcionais de Analytics;
- aplicar RLS, menor privilégio e funções de servidor para operações privilegiadas;
- não enviar CPF, WhatsApp, e-mail, chave PIX ou conteúdo de formulário para Analytics;
- eliminar ou anonimizar dados quando a finalidade terminar, ressalvadas hipóteses legais de conservação;
- manter uma forma simples de o titular acessar políticas, rever consentimento e solicitar direitos.

## Inventário principal

| Categoria | Exemplos | Local/fornecedor principal | Finalidade | Retenção operacional | Exclusão/observação |
| --- | --- | --- | --- | --- | --- |
| Conta e identidade | nome, e-mail, ID, metadados de autenticação | Supabase Auth / `profiles` | login, conta e identificação do aluno | durante a relação e pelo período justificável após o término | excluir/anonymizar quando não houver fundamento de conservação |
| Matrícula | CPF, WhatsApp, código de matrícula | Supabase `profiles` e estruturas de matrícula | matrícula, identificação e contato | durante a relação e pelo período justificável | CPF exige cuidado reforçado por impacto em caso de vazamento |
| Reembolso | chave PIX | Supabase `profiles` | eventual devolução de valores | enquanto houver necessidade operacional/financeira | avaliar exclusão após término da relação quando não houver pendência |
| Disponibilidade | dias e horários | Supabase `profiles` | formação/gestão de turmas | enquanto necessária à organização das aulas | atualizar e excluir quando não necessária |
| Acadêmicos | turma, frequência, lições, exercícios, progresso, reposições | Supabase | prestação do serviço e acompanhamento pedagógico | enquanto necessário ao serviço e histórico justificável | definir política de arquivamento/anonymização para ex-alunos |
| Financeiros | mensalidades, valores, status, identificadores e eventos de pagamento | Supabase + Mercado Pago | cobrança, conciliação, estorno e comprovação | conforme obrigação legal/regulatória/contábil e exercício de direitos | não excluir registros cuja conservação tenha fundamento legal válido |
| Cartão | dados necessários ao checkout | Mercado Pago | processar pagamento | segundo o provedor e obrigações aplicáveis | o banco acadêmico não deve armazenar número completo do cartão ou CVV |
| Acessos de alunos | user_id, data/hora, caminho, título, timezone | `student_access_logs` | acompanhamento operacional/acadêmico e segurança | máximo de 90 dias | limpeza automática no SQL atual; `user_id` possui `ON DELETE CASCADE` |
| E-mail transacional | endereço e conteúdo operacional | Resend + Edge Functions | confirmações necessárias | conforme necessidade transacional e configuração do provedor | evitar conteúdo excessivo ou dados desnecessários no corpo dos e-mails |
| Analytics | página, origem, eventos, conversão e atributos técnicos | Google Analytics + storage do navegador | mensuração e CRO | somente após consentimento; retenção conforme configuração da propriedade e necessidade | desligar após revogação; limpar estados locais próprios e cookies GA quando possível |
| Consentimento | versão, categorias, data e expiração | `localStorage` do navegador | provar e respeitar a preferência no dispositivo | 180 dias na versão atual | usuário pode alterar antes do prazo; nova versão relevante invalida preferência anterior |

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

Canal público inicial: WhatsApp indicado na Política de Privacidade.

Fluxo operacional recomendado para cada solicitação:

1. registrar data, titular e tipo da solicitação sem coletar documentação excessiva;
2. verificar identidade de forma proporcional ao risco;
3. localizar dados em Auth, banco, pagamentos e fornecedores aplicáveis;
4. avaliar obrigação de conservação antes da exclusão;
5. executar correção, exportação, bloqueio, anonimização ou exclusão conforme o caso;
6. confirmar ao titular o resultado e eventuais dados mantidos com a justificativa correspondente;
7. guardar somente o registro mínimo necessário para demonstrar o atendimento.

## Pontos que exigem revisão periódica

- conferir se a retenção da propriedade do Google Analytics está configurada de acordo com a política publicada;
- revisar dados de ex-alunos e definir rotina automatizada de arquivamento/anonymização;
- revisar logs das Edge Functions e provedores para evitar retenção desnecessária de payloads;
- testar semestralmente a recusa e a revogação de Analytics;
- revisar a política sempre que houver novo fornecedor ou nova finalidade de tratamento;
- avaliar automação segura do encerramento da conta após mapear todas as dependências financeiras e acadêmicas.
