# Convenções de URLs públicas

O Teacherflavius.com usa URLs públicas sem extensão de arquivo.

## Regra para páginas novas

Toda nova página deve ser criada como um diretório contendo `index.html`.

Exemplo correto:

```text
curso-ingles-aviacao/index.html
```

URL pública correspondente:

```text
https://teacherflavius.com/curso-ingles-aviacao/
```

Não criar novas páginas no formato:

```text
curso-ingles-aviacao.html
```

## Links internos

Links internos devem apontar diretamente para a rota limpa:

```html
<a href="/curso-ingles-aviacao/">Curso de inglês para aviação</a>
```

Não usar `.html` em `href`, `src`, `action`, canonical, Open Graph ou outras URLs públicas.

## SEO

Para uma página em `/curso-ingles-aviacao/`, usar:

```html
<link rel="canonical" href="https://teacherflavius.com/curso-ingles-aviacao/">
<meta property="og:url" content="https://teacherflavius.com/curso-ingles-aviacao/">
```

O `sitemap.xml` também deve conter somente a URL limpa.

## Páginas antigas

O repositório ainda contém arquivos `.html` legados por compatibilidade. Eles podem continuar existindo enquanto forem necessários, mas não devem servir de modelo para páginas novas.

O arquivo `clean_urls.js` mantém o redirecionamento/normalização de várias rotas antigas. Novas páginas não devem depender dessa camada: devem nascer diretamente no padrão `rota/index.html`.

## Validação automática

O workflow `.github/workflows/clean-urls.yml` executa `scripts/validate_clean_urls.py` em pull requests e em pushes para `main`.

A validação reprova alterações que:

1. adicionem uma nova página HTML fora do padrão `*/index.html`;
2. adicionem novas referências públicas terminadas em `.html` em HTML, JavaScript ou XML;
3. adicionem URLs `.html` ao sitemap, canonical, Open Graph ou links internos.

Os arquivos de compatibilidade legada `clean_urls.js` e `clean_route_loader.js` são preservados para que as URLs antigas continuem funcionando durante a migração.
