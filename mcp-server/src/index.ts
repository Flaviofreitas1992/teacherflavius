import { createServer } from 'node:http';
import { createClient } from '@supabase/supabase-js';
import { toNodeHandler } from '@modelcontextprotocol/node';
import { createMcpHandler, McpServer } from '@modelcontextprotocol/server';
import * as z from 'zod/v4';

const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;
const MCP_ACCESS_TOKEN = process.env.MCP_ACCESS_TOKEN;
const PORT = Number(process.env.PORT ?? 3000);

if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY || !MCP_ACCESS_TOKEN) {
  throw new Error('SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY and MCP_ACCESS_TOKEN are required.');
}

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
  auth: { persistSession: false, autoRefreshToken: false },
});

const textResult = (value: unknown) => ({
  content: [{ type: 'text' as const, text: JSON.stringify(value, null, 2) }],
  structuredContent: value as Record<string, unknown>,
});

function assertNoError(error: { message: string } | null): void {
  if (error) throw new Error(error.message);
}

async function getClassMap() {
  const { data, error } = await supabase
    .from('teacher_classes')
    .select('class_number,class_name,class_type,class_weekday,class_start_time,is_active,display_order')
    .order('display_order', { ascending: true });
  assertNoError(error);
  return new Map((data ?? []).map((row) => [row.class_number, row]));
}

function buildServer(): McpServer {
  const server = new McpServer(
    { name: 'teacherflavius', version: '0.1.0' },
    {
      instructions:
        'TeacherFlavius academic administration tools. Version 0.1 is read-only. Never infer or expose CPF, PIX keys, WhatsApp numbers, passwords, tokens, or other unnecessary private data.',
    },
  );

  server.registerTool(
    'list_students',
    {
      title: 'List students',
      description: 'List active TeacherFlavius students with basic academic and class information. Read-only.',
      inputSchema: z.object({
        search: z.string().trim().min(1).max(120).optional(),
        limit: z.number().int().min(1).max(100).default(50),
      }),
      annotations: { readOnlyHint: true, destructiveHint: false, idempotentHint: true, openWorldHint: false },
    },
    async ({ search, limit }) => {
      let query = supabase
        .from('profiles')
        .select('id,name,email,class_type,created_at')
        .eq('enrolled', true)
        .eq('archived', false)
        .order('name', { ascending: true })
        .limit(limit);
      if (search) query = query.or(`name.ilike.%${search}%,email.ilike.%${search}%`);

      const [{ data: profiles, error: profileError }, { data: memberships, error: membershipError }, classMap] =
        await Promise.all([
          query,
          supabase.from('class_students').select('user_id,class_number'),
          getClassMap(),
        ]);
      assertNoError(profileError);
      assertNoError(membershipError);

      const membershipMap = new Map((memberships ?? []).map((row) => [row.user_id, row.class_number]));
      const students = (profiles ?? []).map((profile) => {
        const classNumber = membershipMap.get(profile.id) ?? null;
        const klass = classNumber === null ? null : classMap.get(classNumber) ?? null;
        return {
          id: profile.id,
          name: profile.name,
          email: profile.email,
          class_type: profile.class_type,
          class: klass
            ? {
                class_number: klass.class_number,
                class_name: klass.class_name,
                weekday: klass.class_weekday,
                start_time: klass.class_start_time,
              }
            : null,
        };
      });

      return textResult({ count: students.length, students });
    },
  );

  server.registerTool(
    'get_student',
    {
      title: 'Get student',
      description: 'Get one student by UUID or exact email, returning only non-sensitive academic information. Read-only.',
      inputSchema: z.object({ identifier: z.string().trim().min(1).max(200) }),
      annotations: { readOnlyHint: true, destructiveHint: false, idempotentHint: true, openWorldHint: false },
    },
    async ({ identifier }) => {
      const byEmail = identifier.includes('@');
      let query = supabase
        .from('profiles')
        .select('id,name,email,class_type,created_at,enrolled,archived,exercise_schedule_start_date')
        .limit(1);
      query = byEmail ? query.eq('email', identifier.toLowerCase()) : query.eq('id', identifier);
      const { data, error } = await query.maybeSingle();
      assertNoError(error);
      if (!data) return textResult({ found: false });

      const [{ data: membership, error: membershipError }, classMap] = await Promise.all([
        supabase.from('class_students').select('class_number').eq('user_id', data.id).maybeSingle(),
        getClassMap(),
      ]);
      assertNoError(membershipError);
      const klass = membership ? classMap.get(membership.class_number) ?? null : null;

      return textResult({
        found: true,
        student: {
          id: data.id,
          name: data.name,
          email: data.email,
          class_type: data.class_type,
          enrolled: data.enrolled,
          archived: data.archived,
          exercise_schedule_start_date: data.exercise_schedule_start_date,
          class: klass,
        },
      });
    },
  );

  server.registerTool(
    'list_classes',
    {
      title: 'List classes',
      description: 'List TeacherFlavius classes and optionally enrolled students. Read-only.',
      inputSchema: z.object({
        active_only: z.boolean().default(true),
        include_students: z.boolean().default(true),
      }),
      annotations: { readOnlyHint: true, destructiveHint: false, idempotentHint: true, openWorldHint: false },
    },
    async ({ active_only, include_students }) => {
      let classQuery = supabase
        .from('teacher_classes')
        .select('class_number,class_name,class_type,class_weekday,class_start_time,is_active,display_order')
        .order('display_order', { ascending: true });
      if (active_only) classQuery = classQuery.eq('is_active', true);
      const { data: classes, error: classError } = await classQuery;
      assertNoError(classError);

      if (!include_students) return textResult({ classes: classes ?? [] });

      const [{ data: memberships, error: membershipError }, { data: profiles, error: profileError }] =
        await Promise.all([
          supabase.from('class_students').select('user_id,class_number'),
          supabase.from('profiles').select('id,name,email').eq('enrolled', true).eq('archived', false),
        ]);
      assertNoError(membershipError);
      assertNoError(profileError);
      const profileMap = new Map((profiles ?? []).map((row) => [row.id, row]));

      const result = (classes ?? []).map((klass) => ({
        ...klass,
        students: (memberships ?? [])
          .filter((membership) => membership.class_number === klass.class_number)
          .map((membership) => profileMap.get(membership.user_id))
          .filter(Boolean),
      }));
      return textResult({ classes: result });
    },
  );

  server.registerTool(
    'get_student_activity',
    {
      title: 'Get student activity',
      description: 'Return recent scored activity results for a student. Read-only.',
      inputSchema: z.object({
        student_id: z.string().uuid(),
        limit: z.number().int().min(1).max(100).default(20),
      }),
      annotations: { readOnlyHint: true, destructiveHint: false, idempotentHint: true, openWorldHint: false },
    },
    async ({ student_id, limit }) => {
      const { data, error } = await supabase
        .from('activity_results')
        .select('id,activity_type,activity_title,score,total,percentage,completed_at')
        .eq('user_id', student_id)
        .order('completed_at', { ascending: false })
        .limit(limit);
      assertNoError(error);
      return textResult({ student_id, results: data ?? [] });
    },
  );

  server.registerTool(
    'get_student_flashcards',
    {
      title: 'Get student flashcards',
      description: 'Return a student’s flashcard decks, cards and recent practice days. Read-only.',
      inputSchema: z.object({
        student_id: z.string().uuid(),
        include_cards: z.boolean().default(true),
        practice_days: z.number().int().min(1).max(90).default(20),
      }),
      annotations: { readOnlyHint: true, destructiveHint: false, idempotentHint: true, openWorldHint: false },
    },
    async ({ student_id, include_cards, practice_days }) => {
      const since = new Date(Date.now() - practice_days * 24 * 60 * 60 * 1000).toISOString().slice(0, 10);
      const [{ data: decks, error: deckError }, { data: practice, error: practiceError }] = await Promise.all([
        supabase
          .from('flashcard_decks')
          .select('id,title,description,created_at,updated_at')
          .eq('owner_id', student_id)
          .order('updated_at', { ascending: false }),
        supabase
          .from('flashcard_practice_days')
          .select('practice_date')
          .eq('user_id', student_id)
          .gte('practice_date', since)
          .order('practice_date', { ascending: false }),
      ]);
      assertNoError(deckError);
      assertNoError(practiceError);

      if (!include_cards || !decks?.length) {
        return textResult({ student_id, decks: decks ?? [], practice_days: practice ?? [] });
      }

      const deckIds = decks.map((deck) => deck.id);
      const { data: cards, error: cardError } = await supabase
        .from('flashcards')
        .select('id,deck_id,english_word,translation,position')
        .in('deck_id', deckIds)
        .order('position', { ascending: true });
      assertNoError(cardError);

      return textResult({
        student_id,
        decks: decks.map((deck) => ({ ...deck, cards: (cards ?? []).filter((card) => card.deck_id === deck.id) })),
        practice_days: practice ?? [],
      });
    },
  );

  server.registerTool(
    'get_pronunciation_results',
    {
      title: 'Get pronunciation results',
      description: 'Return recent pronunciation-assessment scores and teacher feedback without exposing raw provider payloads or audio storage paths. Read-only.',
      inputSchema: z.object({
        student_id: z.string().uuid(),
        limit: z.number().int().min(1).max(50).default(10),
      }),
      annotations: { readOnlyHint: true, destructiveHint: false, idempotentHint: true, openWorldHint: false },
    },
    async ({ student_id, limit }) => {
      const { data, error } = await supabase
        .from('pronunciation_attempts')
        .select(
          'id,assignment_id,reference_text,locale,duration_seconds,accuracy_score,fluency_score,completeness_score,pronunciation_score,prosody_score,words,teacher_feedback,status,error_message,created_at,reviewed_at',
        )
        .eq('user_id', student_id)
        .order('created_at', { ascending: false })
        .limit(limit);
      assertNoError(error);
      return textResult({ student_id, attempts: data ?? [] });
    },
  );

  return server;
}

const handler = createMcpHandler(buildServer, { responseMode: 'json' });
const nodeHandler = toNodeHandler(handler);
const allowedHosts = new Set((process.env.MCP_ALLOWED_HOSTS ?? '').split(',').map((v) => v.trim()).filter(Boolean));
const allowedOrigins = new Set((process.env.MCP_ALLOWED_ORIGINS ?? '').split(',').map((v) => v.trim()).filter(Boolean));

createServer((req, res) => {
  if (req.url !== '/mcp') {
    res.writeHead(404).end('Not found');
    return;
  }

  const authorization = req.headers.authorization ?? '';
  if (authorization !== `Bearer ${MCP_ACCESS_TOKEN}`) {
    res.writeHead(401, { 'content-type': 'application/json' }).end(JSON.stringify({ error: 'Unauthorized' }));
    return;
  }

  const host = req.headers.host ?? '';
  if (allowedHosts.size > 0 && !allowedHosts.has(host)) {
    res.writeHead(403).end('Forbidden host');
    return;
  }

  const origin = req.headers.origin;
  if (origin && allowedOrigins.size > 0 && !allowedOrigins.has(origin)) {
    res.writeHead(403).end('Forbidden origin');
    return;
  }

  void nodeHandler(req, res);
}).listen(PORT, '0.0.0.0', () => {
  console.error(`[teacherflavius-mcp] listening on port ${PORT} at /mcp`);
});
