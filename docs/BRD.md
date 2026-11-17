# Business Requirements Document (BRD)
## AI Service Desk Agent + SLA Analytics — FinServ Bank L1 Service Desk

| | |
|---|---|
| **Document** | BRD v1.0 (Approved by owner, 12 Nov 2026) |
| **Date** | 12 Nov 2026 |
| **Author** | Shikhar Nigam, Business Analyst, Nimbus IT Services |
| **Client** | FinServ Bank (BFSI) |
| **Methodology** | Hybrid: BRD/SRS signed off upfront, then 1-day build sprints |
| **Related** | `SRS.md` (to follow) · `decision-log.md` · `project-flowchart.mmd` |

> **Disclaimer:** Nimbus IT Services and FinServ Bank are fictional. This is a portfolio project. All data is public (UCI, Kaggle) or simulated. Figures marked *assumption* have not been checked against industry benchmarks.

---

## 1. Executive summary

Nimbus IT Services runs FinServ Bank's L1 IT service desk under a per-ticket contract: about 5,000 tickets a month at ₹350 per ticket, roughly ₹17.5 lakh a month. Every ticket is triaged by hand today. An agent reads it, picks a category and priority, and routes it. That takes about **6 minutes per ticket** (500 agent-hours a month). Tickets that are triaged slowly or wrongly lead to SLA breaches. At an assumed **88% SLA compliance**, Nimbus loses **5% of the monthly invoice (₹87,500)** in service credits.

We propose an **AI triage agent** with human review, plus an **SLA-breach risk model** and a **Power BI dashboard**:
- The agent classifies each ticket, writes a summary, drafts a reply from the knowledge base (KB), and flags likely duplicates.
- Low-confidence tickets go to a human review queue.
- Password resets and account unlocks (about 15% of volume) can be auto-resolved.

**Base-case business case:**

| Item | Value |
|---|---|
| Monthly benefit | **₹2.99 lakh** (₹2.12 lakh labour capacity + ₹0.875 lakh credits avoided) |
| One-time build | ₹6 lakh |
| Monthly run | ₹25,000 |
| Payback | **≈ 2.2 months** |
| 12-month ROI | **≈ 299%** |

Even in the low case, payback stays under 8 months (see §10.5).

---

## 2. Background and problem statement

**Context.** FinServ Bank outsources L1 IT support (access issues, hardware, software, HR-system and network queries) to Nimbus. The contract sets resolution SLAs by priority and tiered service credits when monthly compliance falls short.

**Problem.** Manual L1 triage is slow, inconsistent and does not scale:
1. **Time:** about 6 minutes of agent effort per ticket, before any actual fixing starts.
2. **Inconsistency:** different agents give the same issue different priorities. A P1 marked as P3 is a breach waiting to happen.
3. **Misrouting:** a ticket sent to the wrong resolver group gets reassigned, and the SLA clock keeps running.
4. **Repetitive work:** about 15% of tickets are password resets or unlocks that follow a fixed script.
5. **No early warning:** nobody can see which open tickets are likely to breach until they already have.

**Cost of the problem:** about ₹87,500 a month (≈ ₹10.5 lakh a year) in service credits, plus 500 agent-hours a month spent on triage.

---

## 3. Business objectives and KPIs

| ID | Objective | KPI | Baseline | Target | By when |
|---|---|---|---|---|---|
| BO-1 | Stop paying service credits | Monthly SLA compliance | 88% | ≥ 95% | 3 months after go-live |
| BO-2 | Cut manual triage effort | Agent-hours spent on triage per month | 500 hrs | ≤ 100 hrs | 1 month after go-live |
| BO-3 | Triage accurately | Category and priority accuracy on the 100-ticket evaluation set | n/a | Category ≥ 85%, priority ≥ 80% | Before go-live (Sprint 2) |
| BO-4 | Keep humans in control | Share of tickets sent to human review | 100% (all manual) | ≤ 30% | 1 month after go-live |
| BO-5 | Remove repetitive work *(Could-have)* | Auto-resolution rate | 0% | ≈ 15% of tickets | 2 months after go-live |
| BO-6 | Warn before breaches | Breach-risk model recall on breached tickets | n/a | Set in Sprint 1 after EDA | Sprint 1 |

---

## 4. Scope (MoSCoW)

| Priority | In scope |
|---|---|
| **Must** | AI triage (category, priority, summary, confidence as structured JSON) · KB-grounded draft reply · human review queue below a confidence threshold · audit trail of every AI decision · SLA-breach risk scoring (batch) · Power BI dashboard (1 page first) |
| **Should** | Duplicate / known-issue detection (open tickets from the last 2 hours) |
| **Could** | Auto-resolve 1–2 safe intents (password reset, account unlock); this is the first item cut if time runs short |
| **Won't (v1)** | Live scoring API · real email or ServiceNow integration · multilingual support · web ops console (revisited at the end of Sprint 3) |

**Out of scope:** L2/L3 resolution work, changes to the contract or SLAs, and real bank or personal data.

---

## 5. Stakeholders

### 5.1 Stakeholder map (power × interest)

| | **Low interest** | **High interest** |
|---|---|---|
| **High power** | *Keep satisfied:* Bank InfoSec & Compliance | *Manage closely:* Bank CIO (sponsor), Bank IT Service Manager (contract owner), Nimbus Engagement Manager |
| **Low power** | *Monitor:* Bank employees (end users) | *Keep informed:* Nimbus Service Desk Manager, L1 agents, L2 resolver groups, Nimbus Automation team |

### 5.2 RACI

R = Responsible · A = Accountable · C = Consulted · I = Informed

| Activity | Bank CIO | Bank IT Svc Mgr | Bank InfoSec | Nimbus Eng. Mgr | Desk Mgr | L1 agents | L2 resolvers | Automation team | BA |
|---|---|---|---|---|---|---|---|---|---|
| Approve BRD and business case | A | C | C | R | C | I | I | I | R |
| Define requirements (BRD/SRS) | I | C | C | A | C | C | C | C | R |
| Data privacy and AI-use approval | C | C | A/R | C | I | I | I | C | C |
| Build agent, model and dashboard | I | I | C | A | C | I | I | R | C |
| Write and maintain KB articles | I | C | I | I | A | R | C | C | C |
| Run the human review queue | I | I | I | I | A | R | I | C | I |
| UAT | I | A | C | R | R | R | C | C | R |
| Go-live decision | A | R | C | R | C | I | I | C | C |
| Monthly SLA and credit reporting | I | A | I | R | R | I | I | C | C |

---

## 6. As-is process (today)

1. A bank employee raises a ticket (portal or email). It lands in a shared L1 queue.
2. An L1 agent picks it up, reads it, and chooses a **category** and **priority** by judgment (≈ 6 minutes).
3. The agent fixes it at L1 (e.g., a password reset) or routes it to an L2 resolver group.
4. If it was misrouted, it bounces between groups while the SLA clock runs.
5. At month-end, compliance is calculated; if it is below 95%, credits come off the invoice.

**Pain points:** manual effort at peaks · inconsistent priority · reassignment loops · repetitive resets · no breach warning · credits found only after the fact.

## 7. To-be process (with the AI agent)

See `project-flowchart.mmd`. In short:
1. **Intake:** the employee submits an n8n form; a webhook receives it.
2. **Triage:** Gemini returns structured JSON (category, priority, summary, confidence). Invalid output is retried once, then sent to a human.
3. **Duplicate check:** if the ticket matches an open ticket from the last 2 hours, it is linked to the parent with a known-issue reply.
4. **Confidence gate:** below the threshold, the ticket goes to the human review queue, where an L1 agent approves or corrects it.
5. **Auto-resolve** (Could): password reset or unlock gets KB steps and is marked auto-resolved.
6. **Otherwise:** a KB-grounded draft reply is written and the ticket is routed to its resolver group.
7. **Breach risk:** open tickets are batch-scored by the ML model; high-risk ones are visible to the desk manager.
8. **Insights:** SQL views feed a Power BI dashboard (volume, MTTR, SLA %, AI accuracy, credit exposure).

---

## 8. Business requirements

The SRS will break each of these into functional and non-functional requirements and trace them back.

| ID | Requirement | MoSCoW | Objective |
|---|---|---|---|
| BR-01 | Capture tickets through one web intake form (requester, department, subject, description). | Must | BO-2 |
| BR-02 | Automatically assign category and priority to each ticket and give a one-line summary and a confidence score. | Must | BO-2, BO-3 |
| BR-03 | Send tickets below a confidence threshold to a human review queue where an L1 agent approves or corrects the triage. | Must | BO-3, BO-4 |
| BR-04 | Draft a reply for each ticket using only approved KB articles. | Must | BO-2 |
| BR-05 | Fail safe: if the AI is unavailable, rate-limited or returns invalid output, the ticket goes to human review. No ticket is lost. | Must | BO-1 |
| BR-06 | Store every ticket, AI decision and human correction for audit and for measuring accuracy. | Must | BO-3 |
| BR-07 | Predict SLA-breach risk for open tickets using only information known when the ticket is opened. | Must | BO-1, BO-6 |
| BR-08 | Report volume, MTTR, SLA compliance, AI accuracy and credit exposure to the desk manager and the client. | Must | BO-1 |
| BR-09 | Treat ticket text as data, not instructions (resist prompt injection) and handle empty or non-English tickets safely. | Must | BO-3 |
| BR-10 | Use only public or synthetic data in v1; no real employee or customer personal data is sent to the AI. | Must | (compliance) |
| BR-11 | Detect likely duplicates of open tickets raised in the last 2 hours and link them to a parent incident. | Should | BO-1, BO-2 |
| BR-12 | Auto-resolve password-reset and account-unlock tickets with KB steps. | Could | BO-5 |

---

## 9. Assumptions, constraints and dependencies

### 9.1 Contract facts (from the engagement story, decided)

| ID | Fact | Value | Decision |
|---|---|---|---|
| C-1 | Ticket volume | ≈ 5,000 per month | D-20 |
| C-2 | L1 team | 20 agents, ₹400/hr loaded cost | D-20 |
| C-3 | Pricing | ₹350 per ticket ≈ ₹17.5 lakh/month | D-22 |
| C-4 | Resolution SLAs | P1 4h · P2 8h · P3 24h · P4 72h | D-18 |
| C-5 | Service credits | 2% / 5% / 10% of the monthly invoice below 95% / 90% / 85% compliance | D-19 |

### 9.2 Business-case assumptions (owner-approved, not benchmarked)

| ID | Assumption | Value |
|---|---|---|
| A1 | Manual triage time per ticket today | 6 min |
| A2 | Baseline SLA compliance | 88% (5% credit tier, D-25). Comparison point: UCI `made_sla` compliance ≈ 63% (Sprint 1 EDA). 88% stays the base case because UCI is a different organisation with a different SLA setup |
| A3 | Share of tickets that are password reset or unlock | 15% (≈ 750/month) |
| A4 | SLA compliance target after go-live | 95% (clears all credit tiers) |
| A5 | Handling time for a reset or unlock today (triage included) | 10 min |
| A6 | Share of non-auto-resolved tickets sent to human review | 30% (placeholder until P-03, Sprint 2) |
| A7 | Time to review or correct one AI triage | 1 min |
| A8 | One-time build cost charged by Nimbus | ₹6 lakh (60 person-days × ₹10,000) |
| A9 | Run cost at production scale (paid LLM, DB, hosting) | ₹25,000/month *(unverified estimate)* |
| A10 | ROI method | 12 months, simple ROI and payback, no discounting; freed hours are redeployed, not cut |
| — | Conversion used for FTE | 1 FTE = 176 hrs/month (8 h × 22 days) |

**Hypothesis to test (Sprint 1):** faster, more consistent triage and fewer reassignments are what lift SLA compliance from 88% to 95%. The UCI event log has reassignment and SLA fields, so the EDA will check whether reassignments are linked to breaches. If they are not, the SLA claim in BO-1 will be revised.

**Sprint 1 result (EDA, 17 Nov 2026):** the link holds as an association only, not causation. In the UCI log the breach rate rises with each reassignment (22% with none, 43% with one, 60% with two, 91% with six or more), but a ticket that stays open longer also has more time to be reassigned (`docs/eda-findings.md`, answer 5).

### 9.3 Constraints
- **Free tools only for the build:** n8n 2.47.4 (Docker), Gemini free tier, Supabase free tier, Power BI Desktop.
- **Gemini free tier:** 3.5 Flash Lite and 3.1 Flash Lite, 15 requests/min, 500 requests/day. This is enough for a demo and the 100-ticket evaluation, not for 5,000 tickets a month. Production needs a paid tier (A9).
- **n8n:** no Python task runner, so Code nodes are JavaScript and ML runs outside n8n.
- **Supabase free:** the project pauses after about a week of low activity.
- **Time:** 4 days × 6–8 hours, one person.

### 9.4 Dependencies
- UCI "Incident management process enriched event log" (CC BY 4.0) to train the breach model.
- Kaggle "IT Service Ticket Classification" (CC0, licence to confirm on download) for 100 evaluation tickets with real labels.
- About 15 KB articles written in Sprint 2.
- Gemini API availability.

---

## 10. Business case and ROI

### 10.1 Benefits (base case, per month)

| Benefit | Working | Hours | ₹/month |
|---|---|---|---|
| Faster triage on non-auto tickets | 4,250 tickets: 6 min each today (425 hrs) → 30% reviewed at 1 min (21.25 hrs) | 403.75 | 1,61,500 |
| Auto-resolved resets and unlocks | 750 tickets × 10 min | 125.00 | 50,000 |
| **Labour capacity released** | ≈ **3.0 FTE** | **528.75** | **2,11,500** |
| Service credits avoided | 88% → ≥ 95%: 5% × ₹17.5 lakh | — | 87,500 |
| **Total gross benefit** | | | **2,99,000** |

**How to read the labour figure:** Nimbus is paid per ticket, so saved hours raise Nimbus's margin only if the freed capacity absorbs volume growth or avoids new hiring. Service credits avoided are revenue Nimbus keeps directly.

**Not counted (upside):** fewer reassignment loops, faster first response, and better requester experience.

### 10.2 Costs

| Cost | Value |
|---|---|
| One-time build (A8) | ₹6,00,000 |
| Run cost (A9) | ₹25,000/month → ₹3,00,000 over 12 months |
| **12-month total cost** | **₹9,00,000** |

### 10.3 Returns (12 months)

| Metric | Working | Value |
|---|---|---|
| Net monthly benefit | ₹2,99,000 − ₹25,000 | ₹2,74,000 |
| Payback | ₹6,00,000 ÷ ₹2,74,000 | **≈ 2.2 months** |
| 12-month gross benefit | ₹2,99,000 × 12 | ₹35,88,000 |
| 12-month net gain | ₹35,88,000 − ₹9,00,000 | ₹26,88,000 |
| **12-month ROI** | ₹26,88,000 ÷ ₹9,00,000 | **≈ 299%** |

The simple model assumes full benefit from month 1. A real rollout would ramp up, and the low case below covers that.

### 10.4 Sensitivity inputs

| Input | Low | Base | High |
|---|---|---|---|
| Triage time today | 4 min | 6 min | 8 min |
| Reset/unlock share | 10% | 15% | 25% |
| Human review share | 50% | 30% | 20% |
| Review time | 2 min | 1 min | 1 min |
| SLA reached | 92% (2% tier remains) | 95% | 95% |
| Build / run cost | ₹9 lakh / ₹50k per month | ₹6 lakh / ₹25k | ₹6 lakh / ₹25k |

### 10.5 Sensitivity results

| Result | Low | Base | High |
|---|---|---|---|
| Hours freed per month | 308 (≈ 1.8 FTE) | 529 (≈ 3.0 FTE) | 696 (≈ 4.0 FTE) |
| Labour benefit / month | ₹1,23,333 | ₹2,11,500 | ₹2,78,333 |
| Credits avoided / month | ₹52,500 | ₹87,500 | ₹87,500 |
| Gross benefit / month | ₹1,75,833 | ₹2,99,000 | ₹3,65,833 |
| Payback | ≈ 7.2 months | ≈ 2.2 months | ≈ 1.8 months |
| 12-month ROI | ≈ 41% | ≈ 299% | ≈ 388% |

**Conclusion:** the case is positive in all three scenarios. The biggest swing factors are how much human review is still needed (A6, A7) and whether SLA compliance actually reaches 95% (A4). Sprint 3 will compare actual against planned figures using the evaluation results.

---

## 11. Risks and mitigations

| ID | Risk | Impact | Likelihood | Mitigation |
|---|---|---|---|---|
| R1 | AI gives a P1 issue a low priority, and it breaches | High | Medium | Confidence threshold with human review; evaluation on 100 labelled tickets before go-live; track accuracy weekly |
| R2 | **Data privacy:** on the Gemini free tier, Google may use prompts and responses to improve its products, and human reviewers may read them (verified in Google's terms, 12 Nov 2026) | High | Certain on the free tier | v1 uses only public or synthetic data (BR-10); production must use a paid or enterprise tier, where data is not used for training; InfoSec sign-off before any real data |
| R3 | Prompt injection through ticket text | Medium | Medium | Ticket text treated as data; strict JSON output; the AI cannot take actions on its own; edge tests in Sprint 2 |
| R4 | Draft reply invents steps not in the KB | Medium | Medium | Replies grounded in the KB only; a human approves before sending, except for auto-resolve intents |
| R5 | Free-tier rate limits (500/day) stop the demo | Low | Medium | Automatic fallback model; tickets go to human review on errors (BR-05); production on a paid tier |
| R6 | Breach model trained on UCI data does not transfer to FinServ Bank | Medium | High | Positioned as a proof of approach; retrain on client data at rollout |
| R7 | L1 agents don't trust or use the AI | Medium | Medium | Human-in-the-loop by design; show accuracy on the dashboard; corrections feed back |
| R8 | Auto-resolved password resets are abused through social engineering | High | Low | Could-have only; requires identity verification through the bank's existing SSO/self-service; InfoSec review |
| R9 | Benefit assumptions are wrong | Medium | Medium | Sensitivity table; validate A1–A3 with the desk manager; actual-vs-planned review in Sprint 3 |

---

## 12. Success criteria and next steps

**This BRD is successful if** the sponsor approves the scope, objectives and business case, and the SRS can trace every functional requirement back to a BR-ID.

**Next steps:**
1. ✅ BRD signed off by owner (12 Nov 2026).
2. SRS with FR/NFR IDs, acceptance criteria and light traceability to BR-01…BR-12.
3. Repo starter and `CLAUDE.md`.
4. Sprint 1: UCI EDA (including the reassignment hypothesis in §9.2) and the breach model.

## 13. Sign-off

| Role | Name | Decision | Date |
|---|---|---|---|
| Sponsor (Bank CIO) | *fictional* | | |
| Bank IT Service Manager | *fictional* | | |
| Nimbus Engagement Manager | *fictional* | | |
| Business Analyst | Shikhar Nigam | Author · Approved | 12 Nov 2026 |

---
*Sources: UCI Machine Learning Repository (CC BY 4.0, credit to the dataset authors); Kaggle "IT Service Ticket Classification"; Google, "Migrate from Google AI Studio to Gemini Enterprise Agent Platform" (data use by tier).*
