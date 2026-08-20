# Configurar flashcards

O módulo permite que cada aluno crie conjuntos particulares. O professor visualiza os alunos individualmente e pode abrir, estudar, editar ou excluir qualquer conjunto, além de criar um novo conjunto para um aluno específico. No painel de cada aluno, o professor também vê em quais dos últimos 20 dias houve prática.

O modo de estudo usa repetição espaçada (SRS). Depois de conferir a tradução, o aluno classifica o cartão como **Não lembrei**, **Difícil**, **Lembrei** ou **Fácil**. O sistema calcula a próxima data de revisão individualmente para cada cartão e mantém um histórico das avaliações.

## Instalação

1. Abra o projeto Supabase usado pelo portal Teacher Flávio.
2. Acesse **SQL Editor**.
3. Em uma instalação nova, execute primeiro o conteúdo de `supabase_flashcards.sql`.
4. Execute a migração `supabase/migrations/20260820180200_add_flashcard_spaced_repetition.sql`.
5. Confirme que o RLS está ativo nas tabelas `flashcard_decks`, `flashcards`, `flashcard_practice_days`, `flashcard_srs` e `flashcard_review_history`.
6. Publique os arquivos do site e acesse `/flashcards/`.

## Como funciona a repetição espaçada

- cartões novos e cartões cuja `due_date` chegou aparecem em **Revisar**;
- **Não lembrei** mantém o cartão devido no dia atual, reinicia a sequência e reduz o fator de facilidade;
- **Difícil** agenda um intervalo curto e reduz levemente o fator de facilidade;
- **Lembrei** amplia o intervalo de revisão progressivamente;
- **Fácil** amplia o intervalo de forma mais agressiva e aumenta o fator de facilidade;
- o aluno também pode usar **Estudar todos**, sem depender da fila do dia;
- o professor pode estudar os conjuntos como prévia, mas a avaliação feita pela conta do professor não altera a agenda SRS do aluno;
- ao editar um conjunto, os IDs dos cartões mantidos são preservados para que o progresso SRS não seja perdido;
- cartões removidos também removem o progresso e o histórico associados por cascata.

## Permissões

- alunos visualizam e administram somente os próprios conjuntos;
- o professor pode visualizar e administrar os conjuntos de qualquer aluno;
- o professor pode criar um conjunto escolhendo um aluno como proprietário;
- somente o aluno proprietário pode registrar avaliações que alteram a agenda SRS dos próprios cartões;
- o professor pode visualizar o progresso e o histórico SRS dos alunos, mas não alterá-los durante a prévia;
- ao conferir a tradução do primeiro cartão do dia, o sistema registra uma única prática diária para o aluno, usando o fuso `America/Sao_Paulo`;
- o professor visualiza os dias praticados por cada aluno nos últimos 20 dias;
- a prática feita pelo professor ao abrir um conjunto não é registrada como atividade do aluno;
- cada aluno visualiza somente os próprios registros de prática, enquanto o professor pode visualizar os registros de todos os alunos;
- não existe compartilhamento geral de conjuntos entre alunos;
- usuários anônimos não têm acesso às tabelas SRS nem às funções de salvamento e revisão.

## Validação recomendada

1. Entre como aluno e confirme que cartões novos aparecem como devidos hoje.
2. Abra um conjunto, confira a tradução e use cada uma das quatro avaliações SRS em cartões diferentes.
3. Confirme que a interface informa a próxima revisão e que a quantidade de cartões devidos é atualizada.
4. Saia e entre novamente para confirmar que a agenda foi persistida.
5. Edite uma palavra existente e confirme que o progresso SRS daquele cartão foi preservado.
6. Adicione uma palavra nova e confirme que ela aparece como devida hoje.
7. Exclua uma palavra e confirme que ela deixa de aparecer no progresso e no histórico.
8. Entre com outro aluno e confirme que o primeiro conjunto e o progresso não ficam visíveis.
9. Entre como professor, abra o conjunto de um aluno, faça uma prévia e confirme que a agenda SRS do aluno não muda.
10. Como aluno, confira ao menos uma tradução e confirme que o dia atual aparece no histórico de prática exibido ao professor.
11. Confira outras palavras no mesmo dia e confirme que o histórico diário continua contando somente um dia praticado.
12. Rode os Security e Performance Advisors do Supabase depois da migração.
