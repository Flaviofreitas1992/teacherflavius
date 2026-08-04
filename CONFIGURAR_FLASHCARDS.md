# Configurar flashcards

O módulo permite que cada aluno crie conjuntos particulares. O professor visualiza os alunos individualmente e pode abrir, estudar, editar ou excluir qualquer conjunto, além de criar um novo conjunto para um aluno específico. No painel de cada aluno, o professor também vê em quais dos últimos 20 dias houve prática.

## Instalação

1. Abra o projeto Supabase usado pelo portal Teacher Flávio.
2. Acesse **SQL Editor**.
3. Execute o conteúdo de `supabase_flashcards.sql`.
4. Confirme que o relatório final mostra `rls_enabled = true` nas tabelas `flashcard_decks`, `flashcards` e `flashcard_practice_days`.
5. Publique os arquivos do site e acesse `/flashcards/`.

## Permissões

- alunos visualizam e administram somente os próprios conjuntos;
- o professor pode visualizar e administrar os conjuntos de qualquer aluno;
- o professor pode criar um conjunto escolhendo um aluno como proprietário;
- ao conferir a tradução do primeiro cartão do dia, o sistema registra uma única prática diária para o aluno, usando o fuso `America/Sao_Paulo`;
- o professor visualiza os dias praticados por cada aluno nos últimos 20 dias;
- a prática feita pelo professor ao abrir um conjunto não é registrada como atividade do aluno;
- cada aluno visualiza somente os próprios registros de prática, enquanto o professor pode visualizar os registros de todos os alunos;
- não existe compartilhamento geral de conjuntos entre alunos;
- usuários anônimos não têm acesso às tabelas nem à função de salvamento.

## Validação recomendada

1. Entre como aluno e crie, edite, estude e exclua um conjunto particular.
2. Entre com outro aluno e confirme que o primeiro conjunto não fica visível.
3. Entre como professor e localize o primeiro aluno pelo nome ou e-mail.
4. Abra o conjunto desse aluno, pratique, adicione uma palavra e exclua outra.
5. Crie um novo conjunto para um aluno específico e confirme que ele aparece na conta desse aluno.
6. Como aluno, confira ao menos uma tradução e confirme que o dia atual aparece no histórico exibido ao professor.
7. Confira outras palavras no mesmo dia e confirme que o histórico continua contando somente um dia praticado.
8. Pratique o conjunto usando a conta do professor e confirme que isso não cria atividade para o aluno.
9. Rode os Security e Performance Advisors do Supabase depois da instalação.
