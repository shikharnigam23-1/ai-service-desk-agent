# AI Service Desk Agent — Claude Code guide

## Project
Portfolio project. Nimbus IT Services (fictional) runs the L1 IT service desk for FinServ Bank (fictional, BFSI). We are building an AI triage agent (n8n + Gemini) with a Supabase human review queue, an SLA-breach risk model (Python/sklearn) and a Power BI dashboard.
Specs: `docs/BRD.md` (business), `docs/SRS.md` (FR-01…FR-19, NFR-01…NFR-13), `docs/decision-log.md`. Open only the sections a task needs.
Cite FR/NFR IDs in code comments and in suggested commit messages.

## Folder map
- `docs/` specs, decision log, flowchart
- `data/raw/` downloaded datasets (git-ignored); `data/sample/` small committed samples
- `ml/` EDA notebook, training and batch-scoring scripts
- `n8n/` exported workflow JSON
- `sql/` schema, seed data, views
- `eval/` 100-ticket eval set, results, edge tests
- `powerbi/` .pbix and screenshots

## Hard rules
- Never read, print or commit `.env`. Use the variable names in `.env.example`.
- Never run `git commit` or `git push`. The owner reviews every diff and commits.
- Ask before installing packages, changing the DB schema, or creating files outside the agreed plan.
- n8n Code nodes are JavaScript only (no Python runner in n8n 2.47.4).
- ML runs in `/ml` with Python, outside n8n.
- Public or synthetic data only. No real names, emails or IDs (Gemini free tier may use prompts, BRD R2).
- Breach model: open-time features only, with a written leakage check (FR-16).
- Reproducibility: random seed 42, time-based train/test split, save metrics with the model version (NFR-12).
- Flag anything unverified instead of guessing.

## Stack and limits
- Gemini 3.5 Flash Lite, fallback 3.1 Flash Lite on rate-limit errors. Free tier: 15 req/min, 500 req/day; throttle to ≤ 12 req/min (NFR-02).
- Supabase free tier (pauses after about a week idle). Power BI Desktop reads Postgres views.

## Commands
```bash
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
```
