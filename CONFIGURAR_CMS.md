# Configurar o CMS

O CMS permite editar textos, links e imagens do site por `/cms/`, usando a mesma
conta administrativa da Área do Professor.

## Instalação

1. Confirme que `supabase_professor_admin.sql` já foi aplicado e que a função
   `public.is_teacher_admin()` existe.
2. No SQL Editor do Supabase do site Teacher Flávio, execute
   `supabase_cms.sql`.
3. Abra `/cms/` e entre com uma conta cadastrada em `teacher_admins`.
4. Edite um campo e clique em **Salvar e publicar**.
5. Abra a HOME em uma nova aba e atualize a página.

O script é idempotente: pode ser executado novamente. Os valores já editados não
são sobrescritos pelos dados iniciais.

## O que a primeira versão gerencia

- título e apresentação da HOME;
- títulos, descrições e destinos dos dois cards;
- imagem de destaque opcional;
- upload de JPG, PNG, WebP e GIF com até 5 MB.

As imagens são enviadas ao bucket público `cms-media`. Somente administradores
autenticados podem enviar, substituir ou excluir arquivos.

## Segurança

- a leitura do conteúdo publicado é pública;
- criar, editar ou excluir conteúdo exige autenticação e
  `is_teacher_admin() = true`;
- o navegador recebe somente a chave pública do Supabase;
- HTML não é aceito como conteúdo, reduzindo o risco de XSS;
- URLs com protocolos perigosos não são aplicadas às páginas;
- a HOME mantém o texto padrão caso o CMS ou o Supabase esteja indisponível.

Depois de aplicar o SQL, execute os Advisors de Security e Performance do
Supabase e confirme que a tabela `site_content` está com RLS ativo.

## Adicionar outra página ao CMS

1. Cadastre os novos campos em `site_content` com um novo `page_slug`.
2. Na página pública, adicione `data-cms-page="slug"` ao `body`.
3. Marque os elementos com `data-cms-key="chave.do.campo"`.
4. Para links ou imagens, use também `data-cms-attr="href"`, `src` ou
   `background-image`.
5. Carregue `@supabase/supabase-js`, `supabase_config.js` e `cms_public.js`.

Não use `data-cms-attr` para atributos diferentes dos três suportados.
