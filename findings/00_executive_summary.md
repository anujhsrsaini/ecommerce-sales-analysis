# Executive Summary

Three milestones, one question each: what kind of business is this, is it healthy, and who's actually buying. Working from a 10,000-customer / 40,000-order Postgres database with no data dictionary, I explored the schema and answered each question with SQL. Full detail and queries are linked below; this is the five-minute version.

## Three takeaways

- **We're a mid-sized, India-first general-merchandise retailer, and ~3% of our "customers" don't behave like people.** 10,000 customers placed 40,000 orders (₹282.9M revenue) across 14 categories in 91 days — but 262 accounts (3.1%) ordered every 2-3 days for the *entire* window, some 100+ times, and drive 30% of revenue, unflagged anywhere as B2B. → [01_business_overview.md](01_business_overview.md)
- **Revenue isn't growing — it peaked in April and has fallen every month since**, down 41% April→May (the only two full, comparable months) and 67% in daily order rate by June. AOV barely moved (₹7,349–₹7,528 all quarter), so this is a volume collapse, not a pricing one — and it tracks a 71% pullback in marketing spend. → [02_business_health.md](02_business_health.md)
- **Revenue is steeply concentrated: the top 10% of customers generate 52% of it.** A specific, actionable segment — 875 repeat buyers with human-like (weekly) cadence, 8.75% of the base — drives 29% of revenue at ~12.6x a one-time buyer's spend. Meanwhile 55.5% of customers buy once and never return. → [03_customer_segments.md](03_customer_segments.md)

## What this means

April's peak looks like demand we *bought*, not *earned* — treat May/June as the more honest baseline for planning. Q4 spend should prioritize retaining and cloning the 875-person best-customer segment over chasing one-time-buyer volume, and the hyper-frequency accounts need a fraud/ops review before they're trusted in any growth or retention metric — right now they're inflating both.
