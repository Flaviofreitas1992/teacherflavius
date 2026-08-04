# Configurar flashcards

O módulo permite que cada aluno crie conjuntos particulares e que o professor publique conjuntos para todos os alunos autenticados.

## Instalação

1. Abra o projeto Supabase usado pelo portal Teacher Flávio.
2. Acesse **SQL Editor**.
3. Execute o conteúdo de `supabase_flashcards.sql`.
4. Confirme que o relatório final mostra `rls_enabled = true` nas tabelas `flashcard_decks` e `flashcards`.
5. Publique os arquivos do site e acesse `/flashcards/`.

## Permissões

- alunos leem conjuntos compartilhados e administram apenas os próprios conjuntos;
- conjuntos criados por alunos são sempre particulares;
- somente uma conta reconhecida por `is_teacher_admin()` pode marcar um conjunto como compartilhado;
- cartões compartilhados são somente leitura para os alunos;
- usuários anônimos não têm acesso às tabelas nem à função de salvamento.

## Validação recomendada

1. Entre como aluno e crie, edite, estude e exclua um conjunto particular.
2. Confirme que a opção de compartilhar não aparece para o aluno.
3. Entre como professor, crie um conjunto compartilhado e adicione palavras com traduções.
4. Entre novamente como aluno e confirme que o conjunto aparece em **Criados pelo professor** sem botões de edição ou exclusão.
5. Rode os Security e Performance Advisors do Supabase depois da instalação.
