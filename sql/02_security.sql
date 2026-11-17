-- 02_security.sql — row-level security (NFR-04, D-61). Run second. Safe to re-run.
--
-- What this does: with RLS on and no policies, the public (anon) key can read and write nothing.
-- Who still gets in:
--   - n8n and Python using the service key (it skips RLS), and
--   - the database login in SUPABASE_DB_URL (table owner): Supabase table editor, Power BI, Python.
-- No policies are created on purpose. Add them here if a web console is ever built (P-06).

ALTER TABLE category_routing ENABLE ROW LEVEL SECURITY;
ALTER TABLE tickets          ENABLE ROW LEVEL SECURITY;
ALTER TABLE agent_runs       ENABLE ROW LEVEL SECURITY;
ALTER TABLE review_queue     ENABLE ROW LEVEL SECURITY;
ALTER TABLE kb_articles      ENABLE ROW LEVEL SECURITY;
ALTER TABLE sla_predictions  ENABLE ROW LEVEL SECURITY;
ALTER TABLE settings         ENABLE ROW LEVEL SECURITY;
