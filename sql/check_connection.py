"""Check the Supabase database: list every table with its row count and RLS status (NFR-04).

Run from the repo root with the project venv:
    .venv/bin/python sql/check_connection.py

Reads SUPABASE_DB_URL from .env. Prints no secrets.
"""
import os
import sys
from pathlib import Path

import psycopg
from dotenv import load_dotenv
from psycopg import sql

EXPECTED = ["agent_runs", "category_routing", "kb_articles", "review_queue",
            "settings", "sla_predictions", "tickets"]

load_dotenv(Path(__file__).resolve().parents[1] / ".env")
db_url = os.getenv("SUPABASE_DB_URL")
if not db_url:
    sys.exit("SUPABASE_DB_URL is not set. Add it to .env (see .env.example).")

try:
    conn = psycopg.connect(db_url, connect_timeout=15)
except psycopg.OperationalError as e:
    sys.exit(f"Could not connect. Is the Supabase project paused, or the password wrong?\n{e}")

with conn, conn.cursor() as cur:
    cur.execute("""
        SELECT c.relname, c.relrowsecurity
        FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'public' AND c.relkind = 'r'
        ORDER BY c.relname
    """)
    tables = cur.fetchall()
    print(f"{'table':<20}{'rows':>8}   RLS")
    for name, rls in tables:
        cur.execute(sql.SQL("SELECT count(*) FROM public.{}").format(sql.Identifier(name)))
        print(f"{name:<20}{cur.fetchone()[0]:>8}   {'on' if rls else 'OFF'}")

found = {name for name, _ in tables}
missing = [t for t in EXPECTED if t not in found]
rls_off = [name for name, rls in tables if not rls]
if missing:
    sys.exit(f"\nMissing tables: {', '.join(missing)}. Run sql/01_schema.sql.")
if rls_off:
    sys.exit(f"\nRLS is off for: {', '.join(rls_off)}. Run sql/02_security.sql.")
print(f"\nOK: all {len(EXPECTED)} tables exist and RLS is on for every table.")
