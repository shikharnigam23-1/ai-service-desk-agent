-- 03_seed.sql — config rows only (NFR-11). Run third. Safe to re-run:
-- ON CONFLICT DO NOTHING keeps any value you have already edited in the table editor.

INSERT INTO settings (key, value, description) VALUES
    ('prompt_version',         'v1', 'Version label of the triage prompt; logged in agent_runs.prompt_version (FR-14)'),
    ('review_threshold',       NULL, 'Confidence below this goes to human review (FR-07). Not decided yet: P-03, Sprint 2'),
    ('auto_resolve_threshold', NULL, 'Confidence at or above this allows auto-resolve (FR-13). Not decided yet: P-04, Sprint 2')
ON CONFLICT (key) DO NOTHING;

-- TODO (Sprint 2): category_routing.
-- The 8 Kaggle category names are not verified yet (SRS §6.2), so no rows are added here.
-- After the dataset is downloaded, copy the exact names and add one row per category, like:
--   INSERT INTO category_routing (category, resolver_group) VALUES
--       ('exact Kaggle category name', 'resolver group name')
--   ON CONFLICT (category) DO NOTHING;
-- Until then, tickets.final_category and kb_articles.category must stay empty (D-60).
