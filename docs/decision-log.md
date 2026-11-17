# Decision Log — AI Service Desk Agent + SLA Analytics

Owner: Shikhar Nigam · All decisions are owner-approved · Claude proposes options, the owner decides.
Status key: ✅ decided · ⏳ pending

| # | Date | Decision | Options considered | Chosen | Why |
|---|---|---|---|---|---|
| D-01 | 12 Nov 2026 | Portfolio project | Several project ideas | AI Service Desk Agent + SLA Analytics | Real IT-services pain point (manual L1 triage → SLA penalties); matches target roles at HCLTech, Capgemini, Infosys, Accenture |
| D-02 | 12 Nov 2026 | Time budget | 3 or 4 days; 3–4 or 6–8 hrs/day | 4 days × 6–8 hrs | Enough for a full build plus business documents |
| D-03 | 12 Nov 2026 | Tool stack | Paid vs free tools | Free only: n8n (Docker), Gemini free tier, Supabase free tier, Power BI Desktop | Zero cost; all are recognisable names for ATS filters |
| D-04 | 12 Nov 2026 | Ticket intake | n8n Form + webhook / Gmail trigger / both | n8n Form + webhook | Fastest to set up, no OAuth, easy to demo |
| D-05 | 12 Nov 2026 | Human-in-the-loop | Supabase review queue / Telegram–Slack / email | Supabase review queue | Keeps everything in one stack; clear audit trail |
| D-06 | 12 Nov 2026 | Linking text data and SLA data | Two models joined by shared fields / fully synthetic / UCI + LLM-written text | Two models, shared fields | ML learns from real ServiceNow data, which is defensible in interviews; synthetic data would only re-learn invented rules |
| D-07 | 12 Nov 2026 | Career framing | BA / Consultant / PM / BA + Consulting | BA + Consulting mix | Targeting roles from an MBA lens, not engineering; requirements and business case lead, tech is the proof |
| D-08 | 12 Nov 2026 | SDLC methodology | Hybrid / Waterfall / Scrum / V-Model | Hybrid | Mirrors IT-services fixed-scope deals: BRD/SRS signed off upfront, then 1-day build sprints |
| D-09 | 12 Nov 2026 | Business scenario | IT vendor serving client / internal desk / vendor pitch | IT vendor serving a client | Mirrors real IT-services work; SLA penalties make the ROI concrete |
| D-10 | 12 Nov 2026 | Extra business documents | Process maps / business case + ROI / RTM + UAT / RACI | Business case + ROI; stakeholder map + RACI | Strongest consulting signal for the time; light traceability goes inside the SRS |
| D-11 | 12 Nov 2026 | Time trade-off for documents | Simplify tech / extend to 5 days / lighter docs | Simplify tech | Batch risk scoring instead of a live API; 1-page Power BI first; keeps documents strong |
| D-12 | 12 Nov 2026 | Client industry | BFSI / retail / telecom / healthcare | BFSI (fictional "FinServ Bank") | Strict SLAs and penalty clauses; common vertical for target firms |
| D-13 | 12 Nov 2026 | Agent scope (MoSCoW) | — | Must: triage + KB draft reply + human review · Should: duplicate detection · Could: auto-resolve (1–2 safe intents) · Won't v1: live API, real email/ServiceNow, multilingual | Scope fits 4 days; auto-resolve is the first cut if time runs short |
| D-14 | 12 Nov 2026 | Document format | Markdown + PDF / Claude Docs / Word | Markdown in repo + PDF | Renders on GitHub; PDFs to attach to applications |
| D-15 | 12 Nov 2026 | Where coding happens | This chat / Claude Code in VS Code | Claude Code in VS Code; owner commits and pushes | Files and Docker live on the Mac; owner reviews every diff; clean commit history |
| D-16 | 12 Nov 2026 | Insights interface | Power BI only / + Streamlit ops console | Power BI only (ops console revisited end of Sprint 3) | Power BI is the target CV skill; avoids scope creep |
| D-17 | 12 Nov 2026 | Agent evaluation tickets | Kaggle text as-is / real labels + rewritten text / fully synthetic | 100 Kaggle tickets, real labels, Gemini-rewritten into natural sentences | Real ground-truth labels, with realistic text for the agent |
| D-18 | 12 Nov 2026 | SLA targets (resolution) | Standard ITIL / strict BFSI / derive from UCI | P1 4h · P2 8h · P3 24h · P4 72h | Common industry pattern, easy to defend |
| D-19 | 12 Nov 2026 | Penalty model | Tiered credits / flat credit / per-breach | Tiered service credits: 2% / 5% / 10% of monthly fee below 95% / 90% / 85% compliance | How real outsourcing contracts work |
| D-20 | 12 Nov 2026 | Desk size (assumption) | Small / mid-size / large | ~5,000 tickets/month, 20 L1 agents, ₹400/hr loaded cost | Believable for a regional bank; conservative ROI |
| D-21 | 12 Nov 2026 | LLM model (was P-02) | 3.5 Flash Lite + fallback / 3.1 Flash Lite only / Lite for eval + 3.8 Flash for demo | Gemini 3.5 Flash Lite, with automatic fallback to 3.1 Flash Lite on rate-limit errors | Free tier allows 500 requests/day at 15/min (vs 20/day for Flash); one model for dev, eval and demo keeps results consistent; fallback is a good agent-reliability practice |
| D-22 | 12 Nov 2026 | Contract pricing (was P-01) | ₹18 lakh fixed / ₹350 per ticket / ₹90,000 per agent | ₹350 per ticket (≈ ₹17.5 lakh/month at 5,000 tickets); service credits apply to the monthly invoice | Transaction pricing: revenue moves with volume, so automation savings flow straight to vendor margin, which makes a stronger business-case story |
| D-23 | 12 Nov 2026 | GitHub repo visibility | Private until done / public from start | Public from start | Daily commit history visible to recruiters; requires `.gitignore` for `.env` before the first commit |
| D-24 | 12 Nov 2026 | A1 Manual triage time per ticket | 4 / 6 / 8 min | 6 min | Middle value: 500 hrs ≈ ₹2.0 lakh/month; unbenchmarked assumption |
| D-25 | 12 Nov 2026 | A2 Baseline SLA compliance | 84% / 88% / 92% / UCI made_sla rate | 88% (5% credit tier ≈ ₹87,500/month) | Believable and clearly costly; UCI rate can be compared in Sprint 1 EDA |
| D-26 | 12 Nov 2026 | A3 Password reset/unlock share | 10% / 15% / 25% | 15% (≈ 750 tickets/month) | Middle value; unbenchmarked assumption |
| D-27 | 12 Nov 2026 | A4 SLA target after go-live | 95% / 97% / baseline + 3 pts | 95% | Just clears every credit tier; easiest to defend |
| D-28 | 12 Nov 2026 | Secondary ROI assumptions A5–A10 | Claude-proposed defaults | A5 reset handling 10 min · A6 human review 30% (placeholder until P-03) · A7 review 1 min · A8 build ₹6 lakh (60 person-days × ₹10k) · A9 run ₹25k/month (unverified) · A10 12-month simple ROI + payback + low/base/high sensitivity; freed hours redeployed, not cut | Completes the business case; sensitivity shows the case holds in the low scenario |
| D-29 | 12 Nov 2026 | BRD outline | — | 13 sections incl. stakeholder map + RACI, BR-01…BR-12, business case with sensitivity, risks | Base case: ₹2.99 lakh/month benefit, payback ≈ 2.2 months, 12-month ROI ≈ 299% (low case ≈ 41%) |
| D-30 | 12 Nov 2026 | BO-3 accuracy targets (was P-07) | Claude-proposed | Category ≥ 85%, priority ≥ 80% on the 100-ticket eval set | Approved with the BRD |
| D-31 | 12 Nov 2026 | BRD sign-off (was P-08) | — | BRD v1.0 approved, incl. FTE conversion (1 FTE = 176 hrs/month) and the Sprint 1 reassignment hypothesis | Unblocks the SRS |
| D-32 | 12 Nov 2026 | SRS requirement format | IEEE-lite + user stories / IEEE-lite only / user stories only | IEEE-lite "shall" + user story per FR | Formal enough for sign-off, agile enough for the Hybrid SDLC |
| D-33 | 12 Nov 2026 | Acceptance criteria style | Given/When/Then / measurable bullets | Given/When/Then | Testable; maps straight to UAT cases |
| D-34 | 12 Nov 2026 | Traceability depth | BR→FR / BR→FR→test / full RTM with components | BR → FR/NFR → test ID | Strong BA signal at small cost |
| D-35 | 12 Nov 2026 | SRS outline and NFR targets | Claude-proposed | 10-section SRS; 19 FRs, 13 NFRs; triage ≤ 10 s median, 0 lost tickets, 0 successful injections, 100% audit, ₹0 demo cost | Approved; SRS v0.1 drafted |
| D-36 | 12 Nov 2026 | Priority ground truth for eval (was P-09) | (a) owner labels all 100 / (b) Gemini drafts, owner checks | (b) Gemini drafts P1–P4 labels with the SRS §6.2 guide; owner reviews every label | Faster; risk that the AI grades its own work is noted, mitigated by full human review |
| D-37 | 12 Nov 2026 | P1–P4 priority guide (SRS §6.2) | Claude-proposed | Approved | One shared rubric for the AI and human labellers |
| D-38 | 12 Nov 2026 | SRS sign-off (was P-11) | — | SRS v1.0 approved | Requirements baseline locked; Sprint 0 moves to repo starter |
| D-39 | 12 Nov 2026 | Model that drafts eval priority labels | Different model / same model as agent | Different model (e.g., Gemini 3.8 Flash, ~20 tickets per request, ≈ 5 of 20 daily requests) | Reduces self-grading bias; owner still reviews every label |
| D-40 | 12 Nov 2026 | Working preference | — | All approvals and choices asked through interactive question boxes, not plain chat | Owner may miss questions in chat text |
| D-41 | 12 Nov 2026 | Repo folder layout | Proposed (+ data, eval) / handoff only / sprint-numbered | `docs/ data/ ml/ n8n/ sql/ eval/ powerbi/` at the root | Evaluation and data are easy for reviewers to find |
| D-42 | 12 Nov 2026 | Raw data in the public repo | Ignore raw + commit samples / commit full raw / Git LFS | `data/raw/` git-ignored; README gives download links and credits; 100-ticket eval set and small samples committed | Small repo; respects CC BY attribution |
| D-43 | 12 Nov 2026 | Repo licence | MIT code + CC BY docs / MIT for everything / none | MIT for everything | One simple licence; datasets keep their own licences (UCI CC BY 4.0 credited in README) |
| D-44 | 12 Nov 2026 | Python environment | venv + requirements.txt / uv / conda | venv + requirements.txt (versions pinned after first working install) | Built into Python; simplest for reviewers |
| D-45 | 12 Nov 2026 | `CLAUDE.md` scope | Short rules file / detailed guide / rules only | Short rules file (~40 lines) | Claude Code reads it every turn, so shorter saves tokens |
| D-46 | 12 Nov 2026 | README style | Recruiter-first / technical-first | Recruiter-first (problem → solution → impact, then setup) | Fits the BA + Consulting framing (D-07) |
| D-47 | 12 Nov 2026 | `.gitignore` and `.env.example` | As shown / also ignore model + .pbix | As shown; trained model and `.pbix` are committed | Reviewers can open the dashboard and model without rebuilding |
| D-48 | 12 Nov 2026 | How starter files reach the repo | Connect folder / download files / Claude Code prompt / zip + terminal | Zip download + one terminal block (owner switched from "connect folder") | Owner runs every step himself and reviews before the first commit |
| D-49 | 17 Nov 2026 | PDF copies of BRD and SRS | Consulting style / plain GitHub style / black + neon; Claude places files / files sent in chat | Consulting-style A4 PDFs at `docs/pdf/BRD.pdf` and `docs/pdf/SRS.pdf`, linked from the README; Claude places the files, owner commits and pushes | Recruiters can open or download a formatted document in one click; white pages print well and read formal |

## Constraints found during setup (Sprint 0)
- **Gemini free tier (owner's AI Studio, 12 Nov 2026):** 3.5 Flash Lite and 3.1 Flash Lite: 15 RPM, 250K TPM, 500 RPD. 2.5 Flash, 3 Flash, 3.6 Flash, 3.8 Flash: 5 RPM, 20 RPD. Pro models: not available. Daily quota resets at midnight Pacific (≈ 1:30 PM IST).
- **Gemini free-tier data use (verified 12 Nov 2026, Google Cloud docs):** prompts and responses may be used to improve Google products, and human reviewers may read them; the paid tier does not do this. So v1 uses only public or synthetic data (BR-10).
- **n8n 2.47.4 (Docker):** the Python task runner is not available, so any n8n Code node is written in JavaScript; ML runs outside n8n.
- **Supabase free:** the project pauses after about a week of low activity; restore it before interviews.
- **Public repo:** API keys and DB passwords live only in `.env`, which is git-ignored and never committed.

## Pending decisions
| # | Decision | When |
|---|---|---|
| P-03 | Confidence threshold for human review (A6 placeholder 30% depends on it) | Sprint 2 |
| P-04 | Auto-resolve intents and threshold | Sprint 2 |
| P-05 | Power BI sharing: Publish to web vs screenshots/.pbix | Sprint 3 |
| P-06 | Ops console: add or not | End of Sprint 3 |
| P-10 | Duplicate matching method (FR-12) | Sprint 2 |
