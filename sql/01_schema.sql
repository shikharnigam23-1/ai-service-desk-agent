-- 01_schema.sql — tables for the AI Service Desk Agent (SRS §5).
-- Run first, in the Supabase SQL Editor. Safe to re-run: every statement uses IF NOT EXISTS.
-- Note: IF NOT EXISTS skips a table that already exists, so it does not apply later column changes.

-- ---------------------------------------------------------------------------
-- category_routing: category -> resolver group (FR-11, NFR-11). Filled in Sprint 2.
-- It is also the single list of valid categories (D-60).
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS category_routing (
    category        text PRIMARY KEY,
    resolver_group  text NOT NULL
);

-- ---------------------------------------------------------------------------
-- tickets: one row per submitted ticket, saved before any AI call (FR-02).
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tickets (
    id               bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,           -- D-57
    created_at       timestamptz NOT NULL DEFAULT now(),
    requester_name   text NOT NULL,                                             -- synthetic only (NFR-05)
    requester_email  text NOT NULL,                                             -- synthetic only (NFR-05)
    department       text NOT NULL,                                             -- pick-list values not defined in the SRS yet
    subject          text NOT NULL CHECK (char_length(subject) <= 120),         -- FR-01
    description      text NOT NULL CHECK (char_length(description) <= 2000),    -- FR-01
    status           text NOT NULL DEFAULT 'new'
                     CHECK (status IN ('new', 'triaged', 'in_review', 'auto_resolved', 'resolved', 'closed')),  -- D-58
    final_category   text REFERENCES category_routing (category),               -- D-60; empty until triage
    final_priority   text CHECK (final_priority IN ('P1', 'P2', 'P3', 'P4')),
    resolver_group   text,                                                      -- copied from category_routing (FR-11)
    parent_id        bigint REFERENCES tickets (id) CHECK (parent_id <> id),    -- duplicate of this ticket (FR-12)
    reply_status     text CHECK (reply_status IN ('draft', 'sent')),            -- FR-10; empty until a draft exists
    reply_draft      text,                                                      -- D-59 (FR-09)
    kb_article_ids   bigint[],                                                  -- D-59: KB articles used in the draft (FR-09)
    resolved_at      timestamptz
);

-- ---------------------------------------------------------------------------
-- agent_runs: audit log, one row per AI call (FR-14, NFR-09).
-- category and priority are what the AI said, so they have no CHECK: a wrong answer is still logged.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS agent_runs (
    id              bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    ticket_id       bigint NOT NULL REFERENCES tickets (id),
    model           text NOT NULL,
    prompt_version  text NOT NULL,
    raw_output      text,                                                       -- kept as text: it may not be valid JSON (FR-04)
    category        text,
    priority        text,
    summary         text,
    confidence      numeric(4,3) CHECK (confidence BETWEEN 0 AND 1),
    outcome         text NOT NULL CHECK (outcome IN ('ok', 'retry', 'fallback', 'failed')),
    latency_ms      integer CHECK (latency_ms >= 0),
    created_at      timestamptz NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- review_queue: tickets waiting for a human, and what the human decided (FR-07, FR-08).
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS review_queue (
    id           bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    ticket_id    bigint NOT NULL REFERENCES tickets (id),
    reason       text NOT NULL
                 CHECK (reason IN ('low_confidence', 'invalid_output', 'ai_unavailable', 'edge_case')),  -- FR-04 to FR-07
    status       text NOT NULL DEFAULT 'pending'
                 CHECK (status IN ('pending', 'approved', 'corrected')),
    old_values   jsonb,                                                         -- e.g. {"priority": "P3"}
    new_values   jsonb,                                                         -- e.g. {"priority": "P1"}
    reviewer     text,
    reviewed_at  timestamptz,
    created_at   timestamptz NOT NULL DEFAULT now()                             -- not in SRS §5; needed to measure waiting time
);

-- ---------------------------------------------------------------------------
-- kb_articles: approved knowledge-base articles for draft replies (FR-09). About 15 rows, Sprint 2.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS kb_articles (
    id               bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    title            text NOT NULL,
    category         text REFERENCES category_routing (category),               -- D-60
    steps            text NOT NULL,
    is_auto_resolve  boolean NOT NULL DEFAULT false,                            -- FR-13
    updated_at       timestamptz NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- sla_predictions: one current breach-risk row per ticket (FR-17). Re-scoring overwrites the row.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS sla_predictions (
    ticket_id      bigint PRIMARY KEY REFERENCES tickets (id),
    risk_score     numeric(5,4) NOT NULL CHECK (risk_score BETWEEN 0 AND 1),
    risk_band      text NOT NULL CHECK (risk_band IN ('High', 'Medium', 'Low')),
    model_version  text NOT NULL,
    scored_at      timestamptz NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- settings: editable config as key/value rows (NFR-11, D-62). Not in SRS §5; rows are in 03_seed.sql.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS settings (
    key          text PRIMARY KEY,
    value        text,                                                          -- empty = not decided yet
    description  text,
    updated_at   timestamptz NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- Indexes
-- ---------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_tickets_status_created ON tickets (status, created_at);  -- open tickets in the last 2 hours (FR-12)
CREATE INDEX IF NOT EXISTS idx_tickets_parent         ON tickets (parent_id);
CREATE INDEX IF NOT EXISTS idx_agent_runs_ticket      ON agent_runs (ticket_id);
CREATE INDEX IF NOT EXISTS idx_review_queue_ticket    ON review_queue (ticket_id);
CREATE INDEX IF NOT EXISTS idx_review_queue_status    ON review_queue (status);         -- pending items first
