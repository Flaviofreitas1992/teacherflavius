# Configurar o sistema de questionários

O módulo permite criar questionários internos inspirados no Google Forms, com:

- blocos de texto;
- vídeos incorporados por URL;
- perguntas de múltipla escolha;
- uma resposta correta por pergunta;
- pontuação configurável;
- publicação ou rascunho;
- correção automática no Supabase;
- histórico de tentativas e resultados dos alunos.

## 1. Fazer o merge do Pull Request

Depois do merge, confirme que estes endereços estão disponíveis:

- Professor: `/questionarios-admin/`
- Aluno: `/questionario/?id=ID_DO_QUESTIONARIO`
- Portal: `/exercicios-diarios/`

## 2. Criar as tabelas e funções

No painel do Supabase:

1. Abra **SQL Editor**.
2. Crie uma nova consulta.
3. Copie todo o conteúdo de `supabase_questionarios.sql`.
4. Clique em **Run**.

Execute esse arquivo depois da configuração básica do site e de `supabase_professor_admin.sql`, pois ele utiliza:

- `profiles`;
- `teacher_admins`;
- `is_teacher_admin()`;
- usuários autenticados do Supabase Auth.

O script pode ser executado novamente com segurança.

## 3. Segurança

As tabelas `quizzes` e `quiz_attempts` não são acessadas diretamente pelo navegador.

O aluno recebe somente a versão pública do questionário. A propriedade `correct` das alternativas é removida pelo banco antes de enviar o conteúdo ao navegador.

Quando o aluno envia as respostas, a função `submit_quiz_attempt`:

1. valida a matrícula;
2. carrega o gabarito protegido;
3. confere se cada alternativa pertence à pergunta;
4. calcula os pontos;
5. registra a tentativa;
6. devolve somente a pontuação e o percentual.

## 4. Criar um questionário

1. Entre na **ÁREA DO PROFESSOR**.
2. Abra **CRIAR QUESTIONÁRIOS**.
3. Informe o título e, opcionalmente, uma descrição.
4. Use os botões:
   - **+ TEXTO**;
   - **+ VÍDEO**;
   - **+ MÚLTIPLA ESCOLHA**.
5. Em cada pergunta, informe os pontos e marque uma alternativa correta.
6. Marque **Publicar imediatamente** ou salve como rascunho.
7. Clique em **SALVAR QUESTIONÁRIO**.

Os blocos podem ser movidos para cima ou para baixo. Questionários salvos podem ser editados, publicados, despublicados ou arquivados.

## 5. Vídeos

O sistema oferece tratamento específico para:

- YouTube;
- Vimeo;
- Google Drive;
- arquivos diretos `.mp4`, `.webm` e `.ogg`.

Outras URLs HTTP ou HTTPS são abertas em um quadro incorporado, mas o serviço de origem pode impedir a exibição por suas próprias regras de segurança.

## 6. Experiência do aluno

Questionários publicados aparecem automaticamente no **PORTAL DE EXERCÍCIOS**.

O cartão informa:

- quantidade de perguntas;
- total de pontos;
- melhor percentual do aluno;
- quantidade de tentativas.

Depois de responder, o aluno vê imediatamente:

- pontos obtidos;
- total de pontos;
- percentual;
- opção de tentar novamente.

## 7. Resultados do professor

Na parte inferior de **CRIAR QUESTIONÁRIOS**, a seção **RESULTADOS DOS ALUNOS** mostra:

- nome;
- e-mail;
- questionário;
- pontos;
- percentual;
- data e horário do envio.

## 8. Teste recomendado

1. Crie um questionário com um texto, um vídeo e duas perguntas.
2. Salve como rascunho e confirme que ele não aparece no portal.
3. Publique o questionário.
4. Entre com uma conta de aluno matriculado.
5. Abra o PORTAL DE EXERCÍCIOS.
6. Responda ao questionário.
7. Confira a pontuação.
8. Volte à área do professor e confirme que o resultado foi registrado.
