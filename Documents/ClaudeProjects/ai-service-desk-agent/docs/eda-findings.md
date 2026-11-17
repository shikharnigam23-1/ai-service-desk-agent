# EDA findings — UCI incident event log (Sprint 1)

Source: `ml/01_eda.ipynb`, run end to end on `data/raw/incident_event_log.csv` with seed 42. Supports FR-16 and NFR-12. No model has been trained.

## Answers

**1. What is in the file?**
141,712 event rows, 36 columns, **24,918 incidents** (2 to 58 events each, about 5.7 on average). Unknown values are written as `?` and are treated as missing. Five columns are almost entirely missing (`cmdb_ci`, `problem_id`, `rfc`, `vendor`, `caused_by`). Among the candidate features, only `u_symptom` (23%) and `assignment_group` (10%) have notable gaps at event level.

**2. One row per incident**
Built by sorting each incident's events by update counter. Open-time values come from the first event, outcomes from the last. Every incident ends in `Closed`, so every incident has an outcome.

**3. Which `made_sla` value means "breached"?**
**`made_sla = false` means breached.** The label is the value on the *last* event. Evidence:
- Incidents ending `false` took a median of 201 hours to resolve; incidents ending `true` took 1.1 hours. The same direction holds inside every priority.
- The flag is `true` on the first event of all but one incident, and inside an incident it only ever moves `true → false` (9,114 times), never back.

**4. Breach rate**
**36.6% overall** (9,115 of 24,918), so SLA compliance in this log is 63.4%.

| Split (value at open) | What the data shows |
|---|---|
| Priority | Critical 80%, High 97%, Moderate 36%, Low 15%. Moderate is 95% of tickets. |
| Impact / urgency | Same pattern: High 86–90%, Medium 36–37%, Low 14–15%. |
| Category | 8% to 77% across categories with 100+ tickets. |
| Assignment group | `Group 70` takes 51% of tickets at open and breaches 25%. Most other groups breach 45–90%. |
| Contact type | 99.1% Phone. No useful signal. |
| Opening hour | 36–44% between 10:00 and 17:00; 16–37% at night and early morning. |
| Weekday | 34–40% Monday to Friday; 21–28% at weekends (low volume). |

**5. Do more reassignments mean more breaches?**
Yes, as a pattern. Breach rate rises at every step: **22% with no reassignment, 43% with one, 60% with two, 91% with six or more**. It holds inside Moderate and Low priority and in both the early and later months. It does not show for Critical and High tickets, which nearly always breach anyway. This is a link, not proof of cause: a ticket that stays open longer also has more time to be reassigned.

**6. Leakage check**
Every feature must be read from the **first event**. Tickets whose fields were edited later breach 53–86% of the time, against 25–36% for unedited tickets, so final values would leak the outcome.

| Feature | Changes between first and last event | Verdict |
|---|---|---|
| `contact_type` | 5 incidents (0.0%) | Known at open |
| `impact` / `urgency` / `priority` | 1.2% / 1.1% / 1.5% | Known at open; use first value |
| `category` / `subcategory` | 4.8% / 7.1% | Known at open; use first value |
| `u_symptom` | 7.1% (23% missing at open) | Use first value; keep "missing" as a level |
| `assignment_group` | **40.7%** (3.6% missing at open) | First value only; final group is leakage |
| `knowledge` | 0.8% | **Drop** (see Surprises) |
| Opening hour / weekday | 0 — `opened_at` never changes | Known at open |

**7. Date range**
`opened_at` runs from **29 Feb 2016 to 16 Feb 2017**, but 98.9% of incidents were opened by 31 May 2016. Suggested split: cut at the 80th percentile of `opened_at` (11 May 2016), giving 19,934 training and 4,984 test incidents.

## Final open-time feature list (FR-16)

All from the first event: `priority`, `impact`, `urgency`, `category`, `subcategory`, `u_symptom`, `assignment_group`, `open_hour`, `open_weekday`. `contact_type` is safe but adds almost nothing, so it is optional.

Never use: `knowledge`, `made_sla` before the last event, `reassignment_count`, `reopen_count`, `sys_mod_count`, `incident_state`, `active`, `assigned_to`, and anything about resolution or closure (`resolved_*`, `closed_*`).

## Surprises

- **The `knowledge` flag is a calendar artefact.** It is `true` at open for 3,550 of the 3,551 incidents opened up to 10 March 2016 and for only 5 after that. It looks highly predictive (75% vs 30% breach) only because those first days had the worst breach rates. This removes one feature from the SRS candidate list.
- **The breach rate changes sharply over time.** March 2016: 60%. April and May: 23%. Median time to resolve fell from 71 hours to about 3. The log does not explain why. A time-based split will train at about 40% breach and test at about 23%, so predicted risk will run high on the test set; judge the model on ranking and check calibration separately.
- **Compliance is far below the BRD baseline.** 63% here (77% in April–May) against the 88% assumed in A2 / D-25. Different organisation, so this is a comparison point, not a correction.
- **High and Critical tickets almost always breach** (80–97%), on only 496 tickets.
- **The SLA flag appears to follow time to closure, not time to resolution.** For Moderate tickets, a single cut-off of about 9 days to close reproduces the flag for 98% of tickets. This is inferred from the data, not documented.
- **Resolution fields are copied onto every row.** `resolved_at`, `closed_at`, `closed_code` and `resolved_by` already appear on the first event. A value being on the first row does not prove it was known at open.
- **The tail is thin.** Only 274 incidents were opened between June 2016 and February 2017.

## Not verified

- "First event" means the first *logged* event, a median of 1 minute after `opened_at` (99% within 50 minutes). It stands in for open time but is not exact.
- 7.3% of incidents are already `Resolved` on their first event; a risk score has little use for those.
- The time zone of the timestamps is not documented, so opening-hour patterns may be shifted.
- Subcategory and symptom have hundreds of small levels (247 and 501 at open); rare levels need grouping before modelling.
