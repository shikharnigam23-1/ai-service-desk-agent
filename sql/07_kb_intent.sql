-- 07_kb_intent.sql — link the two auto-resolve KB articles to an intent (FR-13, D-84, D-90). Run seventh.
-- Run after 05_seed_kb_articles.sql. The n8n workflow picks the auto-resolve article by intent + category,
-- not by its title. Nullable: the 13 draft-only articles have no intent.
-- Safe to re-run.

ALTER TABLE kb_articles ADD COLUMN IF NOT EXISTS intent text
    CHECK (intent IN ('password_reset', 'account_unlock'));

UPDATE kb_articles SET intent = 'password_reset', updated_at = now()
WHERE is_auto_resolve AND title = 'Reset your password (self-service)' AND intent IS DISTINCT FROM 'password_reset';

UPDATE kb_articles SET intent = 'account_unlock', updated_at = now()
WHERE is_auto_resolve AND title = 'Unlock your account after failed sign-ins' AND intent IS DISTINCT FROM 'account_unlock';

-- Check: expect 2 rows, one per intent, both is_auto_resolve = true and category Access.
-- SELECT id, title, category, is_auto_resolve, intent FROM kb_articles WHERE intent IS NOT NULL;
