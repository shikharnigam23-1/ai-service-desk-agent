# sql/ — Supabase database (SRS §5)

Run the seven SQL files in order in the Supabase SQL Editor. All are safe to re-run.

| Order | File | What it does |
|---|---|---|
| 1 | `01_schema.sql` | Creates the 7 tables, their links, value rules (CHECK) and indexes |
| 2 | `02_security.sql` | Turns on row-level security for every table (NFR-04) |
| 3 | `03_seed.sql` | Adds config rows to `settings` (NFR-11) |
| 4 | `04_seed_category_routing.sql` | Adds the 8 Kaggle categories and their 7 resolver groups (FR-11, D-75) |
| 5 | `05_seed_kb_articles.sql` | Adds the 15 approved KB articles; 2 are auto-resolve (FR-09, FR-13, D-83) |
| 6 | `06_add_intent.sql` | Adds `agent_runs.intent` for auto-resolve and edge cases (FR-13, FR-06, D-84) |
| 7 | `07_kb_intent.sql` | Adds `kb_articles.intent` and sets it on the 2 auto-resolve articles; the workflow matches on intent + category (FR-13, D-90) |
| — | `check_connection.py` | Lists every table with its row count and RLS status |

Check from your machine (needs `SUPABASE_DB_URL` in `.env`):

```bash
.venv/bin/python sql/check_connection.py
```

## Tables

```mermaid
erDiagram
    tickets ||--o{ agent_runs : "has AI calls"
    tickets ||--o{ review_queue : "has reviews"
    tickets ||--o| sla_predictions : "has one risk score"
    tickets ||--o{ tickets : "parent of duplicates"
    category_routing ||--o{ tickets : "final_category"
    category_routing ||--o{ kb_articles : "category"

    tickets {
        bigint id PK
        timestamptz created_at
        text requester_name
        text requester_email
        text department
        text subject
        text description
        text status
        text final_category FK
        text final_priority
        text resolver_group
        bigint parent_id FK
        text reply_status
        text reply_draft
        bigint_array kb_article_ids
        timestamptz resolved_at
    }
    agent_runs {
        bigint id PK
        bigint ticket_id FK
        text model
        text prompt_version
        text raw_output
        text category
        text priority
        text summary
        numeric confidence
        text outcome
        integer latency_ms
        text intent
        timestamptz created_at
    }
    review_queue {
        bigint id PK
        bigint ticket_id FK
        text reason
        text status
        jsonb old_values
        jsonb new_values
        text reviewer
        timestamptz reviewed_at
        timestamptz created_at
    }
    kb_articles {
        bigint id PK
        text title
        text category FK
        text steps
        boolean is_auto_resolve
        text intent
        timestamptz updated_at
    }
    category_routing {
        text category PK
        text resolver_group
    }
    sla_predictions {
        bigint ticket_id PK
        numeric risk_score
        text risk_band
        text model_version
        timestamptz scored_at
    }
    settings {
        text key PK
        text value
        text description
        timestamptz updated_at
    }
```

## Allowed values

| Column | Values |
|---|---|
| `tickets.status` | new, triaged, in_review, auto_resolved, resolved, closed |
| `tickets.final_priority` | P1, P2, P3, P4 |
| `tickets.reply_status` | draft, sent |
| `agent_runs.outcome` | ok, retry, fallback, failed |
| `agent_runs.intent` | password_reset, account_unlock, unclear, other (or empty) |
| `kb_articles.intent` | password_reset, account_unlock (or empty) |
| `review_queue.status` | pending, approved, corrected |
| `review_queue.reason` | low_confidence, invalid_output, ai_unavailable, edge_case |
| `sla_predictions.risk_band` | High, Medium, Low |

## Notes

- **Security:** RLS is on with no policies, so the public key sees nothing. n8n and Python use the service key or the database login; keys live only in `.env`.
- **Categories:** `tickets.final_category` and `kb_articles.category` must exist in `category_routing`, which holds the 8 exact Kaggle `Topic_group` names (seeded by `04_seed_category_routing.sql`).
- **Free tier:** Supabase pauses a project after about a week without use. Restore it from the dashboard before a demo.
- **Changing a table later:** `IF NOT EXISTS` skips tables that already exist, so column changes need an `ALTER TABLE` statement.
