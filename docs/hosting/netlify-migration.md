# Migração do TeacherFlavius.com para Netlify

## Arquitetura alvo

- Canva: gestão atual do domínio/DNS de `teacherflavius.com`.
- GitHub: repositório e fluxo de desenvolvimento.
- Netlify: build, CDN, TLS e headers HTTP do frontend estático.
- Supabase: Auth, banco de dados, Storage e Edge Functions.
- Mercado Pago: pagamentos.

A migração não exige transferência do domínio para Netlify.

## Build

O arquivo `netlify.toml` executa:

```text
python3 scripts/build_netlify_site.py
```

O resultado é publicado a partir de `_site/`.

O build usa somente arquivos rastreados pelo Git e copia apenas extensões públicas necessárias ao frontend. São excluídos explicitamente `.github/`, `supabase/`, `scripts/`, `docs/`, `netlify/`, `_site/` e arquivos operacionais como `CNAME` e `.nojekyll`.

## Headers de segurança

`netlify/_headers` é copiado para `_site/_headers` durante o build e aplica inicialmente:

- `Strict-Transport-Security: max-age=31536000`, sem `includeSubDomains` e sem preload;
- `X-Content-Type-Options: nosniff`;
- `Referrer-Policy: strict-origin-when-cross-origin`;
- `X-Frame-Options: SAMEORIGIN`;
- `Permissions-Policy` conservadora, preservando microfone same-origin para os exercícios de pronúncia;
- `Content-Security-Policy-Report-Only`.

A CSP começa em Report-Only para que autenticação, Mercado Pago, vídeos, analytics e recursos educacionais sejam validados antes de qualquer bloqueio. Os relatórios são enviados à Edge Function Supabase `csp-report`.

## Sequência de migração

1. Importar o repositório `Zoqvera/teacherflavius` no Netlify usando GitHub.
2. Manter `main` como branch de produção.
3. Deixar o Netlify usar o `netlify.toml` versionado; não alterar manualmente build command ou publish directory salvo necessidade comprovada.
4. Abrir primeiro o domínio temporário `*.netlify.app` e executar smoke tests.
5. Verificar no deploy temporário:
   - página inicial e 404;
   - URLs limpas;
   - login Google e retorno para o site;
   - área do aluno e área administrativa;
   - exercícios e flashcards;
   - gravação/avaliação de pronúncia;
   - criação e reconciliação de pagamentos Mercado Pago;
   - Google Forms, quando aplicável;
   - Google Analytics;
   - Open Graph, sitemap e robots.txt.
6. Confirmar via resposta HTTP que todos os headers de segurança estão presentes.
7. Adicionar `teacherflavius.com` como domínio personalizado no projeto Netlify, mantendo DNS externo.
8. Somente depois de o Netlify informar os registros DNS necessários, alterar no Canva os registros que hoje apontam para GitHub Pages.
9. Aguardar emissão/validação do certificado TLS do domínio no Netlify e repetir os smoke tests no domínio real.
10. Manter o GitHub Pages sem mudanças destrutivas até confirmar estabilidade do novo host; isso preserva uma rota simples de rollback de DNS.

## Critério para CSP efetiva

Não trocar `Content-Security-Policy-Report-Only` por `Content-Security-Policy` imediatamente. Primeiro analisar `public.csp_violation_reports` no Supabase com tráfego representativo, corrigir origens legítimas e reduzir gradualmente `'unsafe-inline'` e `'unsafe-eval'` quando tecnicamente possível.

## Rollback

Se a validação pós-DNS falhar, restaurar no Canva os registros DNS anteriores que apontavam para GitHub Pages. Nenhuma migração de banco, Auth ou pagamentos é necessária para esse rollback, porque esses serviços continuam no Supabase/Mercado Pago.
