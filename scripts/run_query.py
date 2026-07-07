#!/usr/bin/env python3
"""Run a SQL query (from a file or stdin) against the ecommerce Postgres DB and print results as a table."""
import sys
import os
from pathlib import Path

import psycopg2
from dotenv import dotenv_values

ROOT = Path(__file__).resolve().parent.parent
env = dotenv_values(ROOT / ".env")

def get_conn():
    return psycopg2.connect(
        host=env["host"],
        port=env["port"],
        dbname=env["database"],
        user=env["username"],
        password=env["password"],
    )

def main():
    if len(sys.argv) > 1:
        sql = Path(sys.argv[1]).read_text()
    else:
        sql = sys.stdin.read()

    conn = get_conn()
    try:
        with conn.cursor() as cur:
            cur.execute(sql)
            if cur.description is None:
                conn.commit()
                print("OK (no result set)")
                return
            cols = [d.name for d in cur.description]
            rows = cur.fetchall()
            widths = [len(c) for c in cols]
            for row in rows:
                for i, val in enumerate(row):
                    widths[i] = max(widths[i], len(str(val)))
            print(" | ".join(c.ljust(widths[i]) for i, c in enumerate(cols)))
            print("-+-".join("-" * w for w in widths))
            for row in rows:
                print(" | ".join(str(val).ljust(widths[i]) for i, val in enumerate(row)))
            print(f"\n({len(rows)} rows)")
    finally:
        conn.close()

if __name__ == "__main__":
    main()
