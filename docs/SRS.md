# Software Requirements Specification (SRS)
## AI Service Desk Agent + SLA Analytics — FinServ Bank L1 Service Desk

| | |
|---|---|
| **Document** | SRS v1.0 (Approved by owner, 12 Nov 2026) |
| **Date** | 12 Nov 2026 |
| **Author** | Shikhar Nigam, Business Analyst, Nimbus IT Services |
| **Parent document** | `BRD.md` v1.0 (approved 12 Nov 2026) |
| **Related** | `decision-log.md` · `project-flowchart.mmd` |
| **Format** | IEEE 830-lite "shall" statements + user stories; acceptance criteria in Given/When/Then |

> **Disclaimer:** Nimbus IT Services and FinServ Bank are fictional. Portfolio project. Public or synthetic data only.

---

## 1. Introduction

### 1.1 Purpose
This SRS turns the 12 business requirements (BR-01…BR-12) in the BRD into testable functional (FR) and non-functional (NFR) requirements. It is the build reference for Sprints 1–3 and the basis for test cases in Sprint 2.

### 1.2 Scope
In scope: ticket intake, AI triage, human review queue, KB-grounded draft reply, routing, duplicate detection (Should), auto-resolve (Could), audit log, SLA-breach risk model (batch), SQL views and a Power BI dashboard.
Out of scope (v1): live scoring API, real email/ServiceNow integration, multilingual support, web ops console (BRD §4).

### 1.3 Glossary

| Term | Meaning |
|---|---|
| Triage | Choosing a ticket's category and priority, and writing a short summary |
| Confidence | The AI's own score (0–1) for its triage; used to decide if a human must check it |
| Review queue | Supabase table where L1 agents approve or correct AI triage |
| KB | Knowledge base: approved help articles the AI may quote from |
| Open-time features | Ticket fields known at the moment it is opened (no future information) |
| Leakage | Training a model on information it would not have at prediction time |
| RTM | Requirements Traceability Matrix |
| MTTR | Mean time to resolve |

### 1.4 How to read a requirement
Each FR has: a **"shall" statement** (what the system must do), a **user story** (who needs it and why), **acceptance criteria** (how we prove it), its **MoSCoW** priority and the **BR** it traces to.

---

## 2. System overview

### 2.1 Actors

| Actor | Role in the system |
|---|---|
| Bank employee (requester) | Raises tickets through the form |
| L1 agent | Reviews and corrects AI triage; approves draft replies |
| Desk manager | Watches breach-risk list and dashboard |
| Bank IT service manager (client) | Reads SLA and credit reporting |
| BA / builder | Runs the evaluation and the batch model |

### 2.2 System components

| Component | Tool | Job |
|---|---|---|
| Intake | n8n Form + webhook | Collects tickets |
| AI agent | n8n workflow + Gemini 3.5 Flash Lite (fallback 3.1 Flash Lite) | Triage, duplicate check, draft reply, routing |
| Data store | Supabase Postgres | Tickets, AI runs, review queue, KB, predictions |
| Breach model | Python + scikit-learn (outside n8n) | Trains on UCI data; batch-scores open tickets |
| Insights | SQL views + Power BI Desktop | KPIs for manager and client |

Flow: see `project-flowchart.mmd`.

---

## 3. Functional requirements

### 3.1 Intake

**FR-01 — Intake form** · Must · BR-01
The system shall capture a ticket through one web form with: requester name, requester email, department (pick-list), subject (≤ 120 characters) and description (≤ 2,000 characters).
*User story:* As a bank employee, I want one simple form so that I can report an IT issue in under a minute.
- **Given** the form is open, **when** I submit with all required fields filled, **then** I see a confirmation with a ticket ID.
- **Given** a required field is empty or over its length limit, **when** I submit, **then** the form blocks submission and shows which field is wrong.

**FR-02 — Store before AI** · Must · BR-01, BR-05, BR-06
The system shall save every submitted ticket to `tickets` with a unique ID, timestamp and status `new` **before** any AI call.
*User story:* As the desk manager, I want every ticket saved first so that no ticket is lost if the AI fails.
- **Given** a valid submission, **when** the webhook fires, **then** a `tickets` row exists with status `new` before the Gemini node runs.

### 3.2 AI triage

**FR-03 — Structured triage** · Must · BR-02, BR-09
The system shall send the ticket to Gemini and receive JSON with `category` (one of the fixed list in §6.2), `priority` (P1–P4), `summary` (≤ 25 words) and `confidence` (0–1). Ticket text shall be passed as clearly marked data, never as instructions.
*User story:* As an L1 agent, I want each ticket pre-classified so that I stop spending 6 minutes reading and sorting it.
- **Given** a normal English ticket, **when** triage runs, **then** the stored result has all four fields and every value is within its allowed set or range.

**FR-04 — Invalid output handling** · Must · BR-05
The system shall validate the AI output against the JSON contract (§6.2). On failure it shall retry once; if it fails again, the ticket goes to the review queue with reason `invalid_output`.
- **Given** the first AI response is not valid JSON, **when** validation fails, **then** exactly one retry is made.
- **Given** the retry also fails, **then** a `review_queue` row is created with reason `invalid_output` and the ticket is not lost.

**FR-05 — Rate-limit and outage fallback** · Must · BR-05
On a rate-limit or unavailable error, the system shall call the fallback model once; if that also fails, the ticket goes to the review queue with reason `ai_unavailable`.
- **Given** the primary model returns a rate-limit error, **when** triage runs, **then** the fallback model is called and the model used is logged.
- **Given** both models fail, **then** the ticket is in the review queue with reason `ai_unavailable`.

**FR-06 — Edge-case tickets** · Must · BR-09
The system shall send empty, gibberish or non-English tickets to the review queue with reason `edge_case`, and shall take no automatic action on them.
- **Given** a ticket written in Hindi, **when** triage runs, **then** it is routed to review with reason `edge_case` and is not auto-resolved.
- **Given** a description containing only spaces or symbols, **then** the same applies.

### 3.3 Human review

**FR-07 — Confidence gate** · Must · BR-03
The system shall send any ticket whose confidence is below the review threshold (decided in P-03, Sprint 2) to `review_queue` with status `pending`.
*User story:* As the desk manager, I want low-confidence tickets checked by a person so that a wrong P1/P3 call does not cause a breach.
- **Given** threshold = T and a ticket with confidence < T, **when** triage finishes, **then** a `pending` review row exists for it.
- **Given** confidence ≥ T, **then** no review row is created (unless FR-04/05/06 apply).

**FR-08 — Approve or correct** · Must · BR-03, BR-06
The system shall let an L1 agent approve or correct category and priority in the review queue (Supabase table editor in v1), recording reviewer, time, old values and new values. The human value becomes the final triage.
*User story:* As an L1 agent, I want to fix the AI's call in a few clicks so that the right group gets the ticket.
- **Given** a pending item, **when** I change priority from P3 to P1 and save, **then** the ticket's final priority is P1, the review row shows `corrected`, and the AI's original value is still kept in `agent_runs`.

### 3.4 Draft reply and routing

**FR-09 — KB-grounded draft reply** · Must · BR-04
The system shall draft a reply using only the KB articles retrieved for the ticket's category, and shall store the article ID(s) used. If no article fits, the draft shall say so and add no fix steps.
*User story:* As an L1 agent, I want a ready draft based on approved articles so that I reply faster without risky advice.
- **Given** a matching KB article, **when** the draft is written, **then** it references that article's ID and every step in it appears in that article.
- **Given** no matching article, **then** the draft states that no KB article was found and contains no fix steps.

**FR-10 — Drafts need approval** · Must · BR-04
The system shall store replies as `draft`; only auto-resolve intents (FR-13) may be marked as sent without human approval.
- **Given** a non-auto-resolve ticket, **then** its reply status is `draft` until an agent approves it.

**FR-11 — Routing** · Must · BR-02
The system shall assign a resolver group from a category → group mapping table (not hard-coded in the prompt).
- **Given** final category X, **then** the ticket's resolver group equals the mapping table entry for X.

### 3.5 Duplicates and auto-resolve

**FR-12 — Duplicate / known-issue detection** · Should · BR-11
The system shall compare a new ticket with open tickets created in the last 2 hours; if it matches (method decided in P-10, Sprint 2), it shall link the ticket to the parent and draft a known-issue reply.
*User story:* As an L1 agent, I want 30 "VPN down" tickets grouped under one incident so that I don't triage the same outage 30 times.
- **Given** an open ticket about "VPN not connecting" from 30 minutes ago, **when** a similar ticket arrives, **then** the new ticket has `parent_id` set and a known-issue draft.
- **Given** the only similar ticket is 3 hours old or closed, **then** no link is made.

**FR-13 — Auto-resolve safe intents** · Could · BR-12
For password-reset and account-unlock tickets with confidence ≥ the auto-resolve threshold (P-04), the system shall send the KB self-service steps (pointing to the bank's existing SSO self-service) and mark the ticket `auto_resolved`. The system shall never handle, reset or send passwords itself.
- **Given** a confident password-reset ticket, **then** status = `auto_resolved` and the reply contains only the KB self-service steps.
- **Given** a password-reset ticket below the threshold, **then** it goes to human review instead.

### 3.6 Audit and evaluation

**FR-14 — Audit log** · Must · BR-06
The system shall log every AI call in `agent_runs`: ticket ID, model, prompt version, raw output, parsed fields, confidence, outcome (ok / retry / fallback / failed), latency and timestamp.
- **Given** any processed ticket, **then** at least one `agent_runs` row exists for it with all listed fields.

**FR-15 — Evaluation harness** · Must · BR-02, BR-03
The system shall run the 100-ticket labelled evaluation set through the agent and report category accuracy, priority accuracy, a confusion matrix, review rate and failure count.
- **Given** the 100 tickets, **when** the evaluation runs, **then** a results file shows all five metrics and can be re-run with the same inputs.

### 3.7 SLA-breach risk model

**FR-16 — Train on open-time features** · Must · BR-07
The system shall train a breach-risk classifier on the UCI event log using only open-time features (candidate list: contact type, category, subcategory, symptom, impact, urgency, priority, assignment group, opening hour/day — confirmed in Sprint 1 EDA; the knowledge flag was removed by D-53 because it acts as a date proxy). The target is breach = not `made_sla` (direction confirmed in EDA).
*User story:* As the desk manager, I want a risk score at open time so that I can act before a ticket breaches.
- **Given** the feature list, **then** a written leakage check confirms no feature is set after the ticket opens.
- **Given** a time-based train/test split, **then** recall, precision and PR-AUC on the test set are saved with the model version.

**FR-17 — Batch scoring** · Must · BR-07
The system shall batch-score open tickets and write `risk_score`, `risk_band` (High / Medium / Low) and `model_version` to `sla_predictions`.
- **Given** open tickets in the store, **when** the scoring script runs, **then** each has one current prediction row.

### 3.8 Reporting

**FR-18 — SQL views** · Must · BR-08
The system shall provide SQL views for ticket volume, MTTR, SLA compliance %, AI accuracy (human override rate), review rate and service-credit exposure (using the BRD tiers).
- **Given** sample data, **then** each view returns figures that match a hand calculation on 10 rows.

**FR-19 — Power BI dashboard** · Must · BR-08
The system shall provide a one-page Power BI dashboard with KPI cards (volume, SLA %, credit exposure, AI accuracy, review rate), a trend chart and a high-risk open-ticket list.
- **Given** the dashboard is refreshed, **then** KPI values equal the SQL view results.

---

## 4. Non-functional requirements

| ID | Category | Requirement (the system shall…) | Measure / acceptance | BR |
|---|---|---|---|---|
| NFR-01 | Performance | Triage a ticket from form submit to stored result quickly | Median ≤ 10 s over the eval run *(free-tier latency unverified; measured in Sprint 2)* | BR-02 |
| NFR-02 | Capacity | Stay inside free-tier limits | Eval runs throttled to ≤ 12 requests/min (limit 15 RPM, 500/day) | BR-05 |
| NFR-03 | Reliability | Never lose a ticket | 0 lost tickets in eval and edge tests; 100% of failed AI calls end in the review queue | BR-05 |
| NFR-04 | Security | Keep secrets out of code | Keys and passwords only in `.env`; `.env` in `.gitignore`; Supabase row-level security on | BR-10 |
| NFR-05 | Privacy | Use no real personal data | Only public or synthetic data; no real names, emails or IDs in prompts (free-tier data use, BRD R2) | BR-10 |
| NFR-06 | AI safety | Resist prompt injection | 0 of the injection test tickets change category rules, routing or trigger auto-resolve | BR-09 |
| NFR-07 | AI safety | Output only the agreed contract | 100% of accepted outputs pass JSON schema validation; anything else follows FR-04 | BR-09 |
| NFR-08 | Accuracy | Triage accurately | Category ≥ 85%, priority ≥ 80% on the 100-ticket eval set (D-30) | BR-02 |
| NFR-09 | Auditability | Make every AI decision traceable | 100% of AI calls have an `agent_runs` row; 100% of corrections keep old and new values | BR-06 |
| NFR-10 | Usability | Make review fast | An L1 agent approves or corrects a ticket in ≤ 1 min (A7), timed on 10 tickets | BR-03 |
| NFR-11 | Maintainability | Keep rules editable | Prompt version, category list, mapping table and thresholds stored as config/tables; n8n workflow exported as JSON to the repo | BR-02 |
| NFR-12 | Reproducibility | Make the model repeatable | Fixed random seed, time-based split, saved metrics and model version | BR-07 |
| NFR-13 | Cost | Cost nothing to demo | ₹0 run cost on free tiers | — |

---

## 5. Data requirements

Key fields only; the full schema is built in Sprint 1.

| Table | Key fields | Written by |
|---|---|---|
| `tickets` | id, created_at, requester_name, requester_email, department, subject, description, status, final_category, final_priority, resolver_group, parent_id, reply_status, resolved_at | Intake, agent, reviewer |
| `agent_runs` | id, ticket_id, model, prompt_version, raw_output, category, priority, summary, confidence, outcome, latency_ms, created_at | Agent |
| `review_queue` | id, ticket_id, reason, status (pending / approved / corrected), old_values, new_values, reviewer, reviewed_at | Agent, L1 agent |
| `kb_articles` | id, title, category, steps, is_auto_resolve, updated_at | BA (≈ 15 articles, Sprint 2) |
| `category_routing` | category, resolver_group | BA |
| `sla_predictions` | ticket_id, risk_score, risk_band, model_version, scored_at | Batch script |

**Data sources:** UCI event log (CC BY 4.0) for the model; Kaggle IT Service Ticket Classification (CC0, confirm on download) for the 100 eval tickets. Synthetic requester names and emails only.

---

## 6. Interfaces

### 6.1 User interfaces
- **Intake form** (n8n Form): fields as in FR-01.
- **Review queue** (Supabase table editor in v1): filter `status = pending`, edit category/priority, set status.
- **Dashboard** (Power BI Desktop): one page as in FR-19.

### 6.2 AI output contract (Gemini → n8n)

```json
{
  "category": "<one of the fixed category list>",
  "priority": "P1 | P2 | P3 | P4",
  "summary": "<≤ 25 words>",
  "confidence": 0.0
}
```

- **Category list:** the 8 categories of the Kaggle dataset. ⚠️ Exact names are not yet verified; they will be copied from the dataset on download (Sprint 2) and stored in config.
- **Priority guide** (given to the model and to human labellers): P1 = many users or a critical banking system down · P2 = one team blocked or a major function degraded · P3 = one user blocked with a workaround or a minor issue · P4 = request or question, no business impact. *(Approved by owner, D-37.)*
- Any extra field, missing field or out-of-range value fails validation (FR-04).

### 6.3 System interfaces
- n8n → Gemini API (HTTPS, API key from `.env`).
- n8n → Supabase (Postgres/REST, service key from `.env`).
- Python batch script → Supabase (read open tickets, write predictions).
- Power BI → Supabase Postgres (read views).

---

## 7. Constraints and assumptions
See BRD §9. In short: free tiers only, 15 RPM / 500 requests per day on Gemini, no Python runner in n8n, Supabase pauses after about a week of inactivity, 4 build days.

## 8. Open items

| ID | Item | Affects | When |
|---|---|---|---|
| P-03 | Review confidence threshold | FR-07, A6 | Sprint 2 |
| P-04 | Auto-resolve intents and threshold | FR-13 | Sprint 2 |
| P-09 | ✅ Decided (D-36): a different Gemini model from the agent (e.g., 3.8 Flash, batched) drafts P1–P4 labels for the 100 eval tickets using the §6.2 guide (D-39); the owner checks and corrects every label. Kaggle priority labels assumed absent (verify on download) | FR-15, NFR-08 | Done |
| P-10 | Duplicate matching method (e.g., same category + similar subject) | FR-12 | Sprint 2 |

---

## 9. Requirements Traceability Matrix (RTM)

Test case IDs are reserved now; the cases are written and run in Sprint 2–3.

| BR | Requirement (short) | FR / NFR | Test cases | Status |
|---|---|---|---|---|
| BR-01 | Web intake form | FR-01, FR-02 | TC-01, TC-02 | Planned |
| BR-02 | Category, priority, summary, confidence | FR-03, FR-11, FR-15, NFR-01, NFR-08, NFR-11 | TC-03, TC-11, TC-15 | Planned |
| BR-03 | Human review below threshold | FR-07, FR-08, NFR-10 | TC-07, TC-08 | Planned |
| BR-04 | KB-only draft reply | FR-09, FR-10 | TC-09, TC-10 | Planned |
| BR-05 | Fail safe, no lost tickets | FR-02, FR-04, FR-05, NFR-02, NFR-03 | TC-04, TC-05 | Planned |
| BR-06 | Audit trail | FR-08, FR-14, NFR-09 | TC-14 | Planned |
| BR-07 | Breach risk at open time | FR-16, FR-17, NFR-12 | TC-16, TC-17 | Planned |
| BR-08 | Reporting | FR-18, FR-19 | TC-18, TC-19 | Planned |
| BR-09 | Injection, empty, non-English | FR-03, FR-06, NFR-06, NFR-07 | TC-06, TC-20 (injection set) | Planned |
| BR-10 | Public/synthetic data only | NFR-04, NFR-05 | TC-21 (repo and prompt check) | Planned |
| BR-11 | Duplicate detection (Should) | FR-12 | TC-12 | Planned |
| BR-12 | Auto-resolve (Could) | FR-13 | TC-13 | Planned |

**Coverage check:** all 12 BRs have at least one FR or NFR and at least one test case. Every FR traces back to a BR.

---

## 10. Sign-off

| Role | Name | Decision | Date |
|---|---|---|---|
| Bank IT Service Manager | *fictional* | | |
| Nimbus Engagement Manager | *fictional* | | |
| Business Analyst | Shikhar Nigam | Author · Approved | 12 Nov 2026 |
