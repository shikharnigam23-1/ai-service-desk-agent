-- 06_add_intent.sql — store the AI's intent on each run (FR-13, FR-06, D-84, D-85). Run sixth.
-- intent drives auto-resolve (password_reset / account_unlock) and edge cases ('unclear' = non-English
-- or gibberish). Nullable: rows from failed runs, or from before this change, have no intent.
-- Safe to re-run.

ALTER TABLE agent_runs ADD COLUMN IF NOT EXISTS intent text
    CHECK (intent IN ('password_reset', 'account_unlock', 'unclear', 'other'));
