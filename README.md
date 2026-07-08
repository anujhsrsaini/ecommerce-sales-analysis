# Ecommerce Sales Analysis (SQL)

**Stack:** PostgreSQL (Supabase) · Python (psycopg2)
**Data:** Synthetic ecommerce database — 10,000 customers, 40,000 orders, 91-day window (Mar 16 – Jun 14, 2026)

A self-directed analyst exercise: given database credentials and no data dictionary, answer three real-world business questions with nothing but SQL and judgment calls I had to defend myself.

> **TL;DR:** Revenue peaked in April and has fallen 41-67% since, driven entirely by order volume (AOV is flat) and correlated with a pullback in marketing spend. Meanwhile, 3.1% of "customers" order every 2-3 days for months straight and don't look human — they currently account for 30% of revenue and need a fraud/ops review.

**→ Five-minute version: [findings/00_executive_summary.md](findings/00_executive_summary.md)**

## What's in here

| Milestone | Question | SQL | Findings |
|---|---|---|---|
| 1 | What kind of business is this, and at what scale? | [01_exploration.sql](sql/01_exploration.sql) | [01_business_overview.md](findings/01_business_overview.md) |
| 2 | Is the business growing? What does an average order look like? | [02_revenue.sql](sql/02_revenue.sql) | [02_business_health.md](findings/02_business_health.md) |
| 3 | Who actually shops here, and where should Q4 marketing spend go? | [03_customers.sql](sql/03_customers.sql) | [03_customer_segments.md](findings/03_customer_segments.md) |

Each SQL file is commented like a lab notebook — what I checked and why, in the order I ran it — so it reads standalone, not just as a script to execute.

## Running it yourself

```bash
python3 -m venv venv && source venv/bin/activate
pip install -r requirements.txt
cp .env.example .env   # fill in host/port/database/username/password
python scripts/run_query.py sql/01_exploration.sql
```

## What I'd do next

- **Investigate the hyper-frequency accounts directly** — pull their addresses, payment methods, and device fingerprints to determine whether they're resellers, shared logins, or synthetic test data, since they currently distort every revenue-concentration and repeat-rate metric in this repo.
- **Extend the time window** — 91 days is enough to spot a trend but not to confirm one; a longer pull would confirm whether April's peak was a one-off marketing-driven spike or part of a recurring seasonal pattern.
- **Attribution-level campaign analysis** — join `attribution_touches`/`marketing_campaigns` to orders directly (not just budget-by-month) to see which specific campaigns drove real repeat customers versus one-time, discount-chasing orders.
