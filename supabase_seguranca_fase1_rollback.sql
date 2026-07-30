-- Rollback emergencial da Segurança do Supabase — Fase 1
--
-- Use somente se, depois da aplicação, alguma área autenticada do site acusar
-- "permission denied for function ...". Este rollback restaura EXECUTE para
-- authenticated, mas mantém anon bloqueado e preserva os search_path seguros.

begin;

grant execute on all functions in schema public to authenticated;

commit;
