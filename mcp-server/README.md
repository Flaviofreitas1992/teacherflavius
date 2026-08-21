# TeacherFlavius MCP

Servidor MCP read-only para consultar dados acadêmicos do portal TeacherFlavius.

## V1

Ferramentas disponíveis:

- `list_students`
- `get_student`
- `list_classes`
- `get_student_activity`
- `get_student_flashcards`
- `get_pronunciation_results`

A V1 não cria, edita nem exclui dados.

## Privacidade

As ferramentas retornam apenas dados acadêmicos necessários. CPF, WhatsApp, chave PIX, credenciais, `azure_result` bruto e caminhos internos de áudio não são expostos.

O acesso ao Supabase é server-side. Nunca coloque `SUPABASE_SERVICE_ROLE_KEY` no frontend ou em arquivos versionados.

## Desenvolvimento local

Requer Node.js 22 ou superior.

```bash
cd mcp-server
npm install
cp .env.example .env
```

Defina em `.env`:

```env
SUPABASE_URL=https://SEU_PROJETO.supabase.co
SUPABASE_SERVICE_ROLE_KEY=SEGREDO_SERVER_SIDE
MCP_ACCESS_TOKEN=TOKEN_LONGO_E_ALEATORIO
PORT=3000
MCP_ALLOWED_HOSTS=localhost:3000,127.0.0.1:3000
MCP_ALLOWED_ORIGINS=
```

Depois:

```bash
npm run typecheck
npm run dev
```

Endpoint MCP:

```text
http://localhost:3000/mcp
```

O servidor exige:

```text
Authorization: Bearer <MCP_ACCESS_TOKEN>
```

## Produção

A autenticação por token desta V1 é apenas um bootstrap privado para desenvolvimento. Antes de registrar o servidor como app/plugin do ChatGPT, implementar OAuth 2.1 e validar a identidade/autorização do professor por requisição.

O servidor deve ser hospedado em runtime server-side HTTPS; o GitHub Pages continua somente como frontend do portal.
