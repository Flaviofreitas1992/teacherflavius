# Configurar flashcards

O módulo permite que cada aluno crie conjuntos particulares. O professor visualiza os alunos individualmente e pode abrir, estudar, editar ou excluir qualquer conjunto, além de criar um novo conjunto para um aluno específico.

## Instalação

1. Abra o projeto Supabase usado pelo portal Teacher Flávio.
2. Acesse **SQL Editor**.
3. Execute o conteúdo de `supabase_flashcards.sql`.
4. Confirme que o relatório final mostra `rls_enabled = true` nas tabelas `flashcard_decks` e `flashcards`.
5. Publique os arquivos do site e acesse `/flashcards/`.

## Permissões

- alunos visualizam e administram somente os próprios conjuntos;
- o professor pode visualizar e administrar os conjuntos de qualquer aluno;
- o professor pode criar um conjunto escolhendo um aluno como proprietário;
- não existe compartilhamento geral de conjuntos entre alunos;
- usuários anônimos não têm acesso às tabelas nem à função de salvamento.

## Validação recomendada

1. Entre como aluno e crie, edite, estude e exclua um conjunto particular.
2. Entre com outro aluno e confirme que o primeiro conjunto não fica visível.
3. Entre como professor e localize o primeiro aluno pelo nome ou e-mail.
4. Abra o conjunto desse aluno, pratique, adicione uma palavra e exclua outra.
5. Crie um novo conjunto para um aluno específico e confirme que ele aparece na conta desse aluno.
6. Rode os Security e Performance Advisors do Supabase depois da instalação.
