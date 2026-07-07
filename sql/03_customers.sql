-- =====================================================================
-- 03_customers.sql
-- Milestone 4: who actually shops with us -- one-time vs repeat,
-- revenue contribution per group, and a defensible "best customer"
-- segment for Marketing's Q4 spend decision.
-- Comments record what I checked and why, in the order I ran it.
-- =====================================================================


-- STEP 1: PER-CUSTOMER SUMMARY -- build once, reuse everywhere below.
-- Uses payment_status = 'paid' (same filter decided in milestone 3) so
-- cancelled/failed orders don't inflate order counts or revenue.
-- NOTE: only 8,438 of 10,000 customers have ever placed a PAID order --
-- 1,562 customers never converted at all. That's a real number worth
-- knowing, but it's an activation question, not a repeat-purchase one,
-- so the segments below are all "as a % of customers who bought
-- something" unless stated otherwise.
with per_customer as (
  select
    customer_id,
    count(*) as order_count,
    sum(total) as total_spend,
    min(created_at) as first_order_at,
    max(created_at) as last_order_at,
    extract(epoch from (max(created_at) - min(created_at))) / 86400.0 as span_days
  from ecom.orders
  where payment_status = 'paid'
  group by customer_id
)
select count(*) as customers_with_paid_order,
       round(avg(order_count), 2) as avg_orders_per_customer,
       round(avg(total_spend)) as avg_spend_per_customer
from per_customer;
-- 8,438 converting customers, avg 4.48 orders each, avg spend ~33,522.
-- The average masks a very skewed distribution -- see Step 3.


-- STEP 2: DEFINING "REPEAT"
-- Simplest defensible definition: repeat = 2+ paid orders, ever.
-- One-time vs repeat split, with revenue share for each.
with per_customer as (
  select customer_id, count(*) as order_count, sum(total) as total_spend
  from ecom.orders
  where payment_status = 'paid'
  group by customer_id
)
select
  case when order_count = 1 then 'one_time' else 'repeat' end as customer_type,
  count(*) as customers,
  round(100.0 * count(*) / sum(count(*)) over (), 1) as pct_customers,
  round(sum(total_spend)) as revenue,
  round(100.0 * sum(total_spend) / sum(sum(total_spend)) over (), 1) as pct_revenue
from per_customer
group by 1;
-- one_time: 4,679 customers (55.5%), 12.4% of revenue.
-- repeat:   3,759 customers (44.5%), 87.6% of revenue.
-- Sanity check vs milestone 2 total revenue (282,859,232):
-- 34,995,567 + 247,863,665 = 282,859,232 -- matches. No customers dropped.


-- STEP 3: A NAIVE "REPEAT" BUCKET HIDES TWO VERY DIFFERENT BEHAVIORS.
-- Milestone 2 already flagged 281 customers ordering 20-178 times in
-- 91 days -- multiple orders/day, every day. That's not "two orders six
-- months apart" repeat buying; it's a different phenomenon entirely
-- (the brief's own question: is a 6-day-apart repeat the same as a
-- 6-month-apart repeat?). Split "repeat" into a plausible-human tier
-- and a hyper-frequency tier, and look at the cadence (avg days between
-- orders) for each to confirm the split is real, not arbitrary.
with per_customer as (
  select
    customer_id,
    count(*) as order_count,
    sum(total) as total_spend,
    extract(epoch from (max(created_at) - min(created_at))) / 86400.0 as span_days
  from ecom.orders
  where payment_status = 'paid'
  group by customer_id
),
tiered as (
  select *,
    case
      when order_count = 1 then '1_one_time'
      when order_count between 2 and 19 then '2_repeat_normal'
      else '3_hyper_frequency'
    end as tier,
    case when order_count > 1 then span_days / (order_count - 1) else null end as avg_gap_days
  from per_customer
)
select
  tier,
  count(*) as customers,
  round(100.0 * count(*) / sum(count(*)) over (), 1) as pct_customers,
  round(sum(total_spend)) as revenue,
  round(100.0 * sum(total_spend) / sum(sum(total_spend)) over (), 1) as pct_revenue,
  round(avg(order_count), 1) as avg_orders,
  round(avg(avg_gap_days), 2) as avg_gap_days
from tiered
group by tier
order by tier;
-- 1_one_time:        4,679 (55.5%), 12.4% revenue, 1.0 orders, n/a gap
-- 2_repeat_normal:    3,497 (41.4%), 57.7% revenue, 6.3 orders, ~10.5 day gap
-- 3_hyper_frequency:    262 ( 3.1%), 30.0% revenue, 42.9 orders, ~2.6 day gap
-- The hyper-frequency tier is 3.1% of customers driving 30% of revenue by
-- ordering every 2-3 days for three straight months -- not organic retail
-- behavior. Excluded from the "best customer" segment below; flagged in
-- the writeup as needing a fraud/ops look, not a marketing target.


-- STEP 4: RECENCY BY TIER -- are "repeat" customers even still active?
with per_customer as (
  select customer_id, count(*) as order_count, sum(total) as total_spend, max(created_at) as last_order_at
  from ecom.orders
  where payment_status = 'paid'
  group by customer_id
),
tiered as (
  select *,
    case
      when order_count = 1 then '1_one_time'
      when order_count between 2 and 19 then '2_repeat_normal'
      else '3_hyper_frequency'
    end as tier
  from per_customer
)
select tier,
  round(avg(extract(epoch from ((select max(created_at) from ecom.orders) - last_order_at)) / 86400), 1) as avg_days_since_last_order
from tiered
group by tier
order by tier;
-- one_time customers are stalest (avg 47 days since last/only order);
-- normal repeat customers ordered more recently (avg 29 days) --
-- consistent with still being active, not lapsed.


-- STEP 5: HOW CONCENTRATED IS REVENUE? (the 80/20 question)
with per_customer as (
  select customer_id, sum(total) as total_spend
  from ecom.orders
  where payment_status = 'paid'
  group by customer_id
),
ranked as (
  select *, percent_rank() over (order by total_spend desc) as pr
  from per_customer
)
select
  round(100.0 * sum(total_spend) filter (where pr <= 0.10) / sum(total_spend), 1) as pct_revenue_from_top10pct,
  round(100.0 * sum(total_spend) filter (where pr <= 0.20) / sum(total_spend), 1) as pct_revenue_from_top20pct
from ranked;
-- Top 10% of converting customers = 52.1% of revenue.
-- Top 20% of converting customers = 69.8% of revenue.
-- Concentration is real and steep -- reinforces focusing Q4 spend
-- narrowly rather than spreading it evenly across the base.


-- STEP 6: PICK AND PROFILE A "BEST CUSTOMER" SEGMENT
-- Lens chosen: within the *normal-repeat* tier only (plausible human
-- cadence, excludes the hyper-frequency anomaly), take the top quartile
-- by total spend. This favors customers who are both loyal (repeat,
-- reasonable gap) AND valuable (high spend) -- the combination Marketing
-- can actually build a lookalike/retention campaign around.
with per_customer as (
  select
    customer_id,
    count(*) as order_count,
    sum(total) as total_spend,
    max(created_at) as last_order_at,
    extract(epoch from (max(created_at) - min(created_at))) / 86400.0 as span_days
  from ecom.orders
  where payment_status = 'paid'
  group by customer_id
  having count(*) between 2 and 19          -- normal-repeat tier only
),
q as (
  select *,
    ntile(4) over (order by total_spend desc) as quartile,
    span_days / (order_count - 1) as avg_gap_days
  from per_customer
)
select
  count(*) as customers,
  round(100.0 * count(*) / (select count(*) from ecom.customers), 2) as pct_of_all_customers,
  round(avg(order_count), 1) as avg_orders,
  round(avg(total_spend)) as avg_spend,
  round(avg(avg_gap_days), 1) as avg_days_between_orders,
  round(avg(extract(epoch from ((select max(created_at) from ecom.orders) - last_order_at)) / 86400), 1) as avg_days_since_last_order,
  round(sum(total_spend)) as segment_revenue,
  round(100.0 * sum(total_spend) / (select sum(total) from ecom.orders where payment_status = 'paid'), 1) as pct_of_total_revenue
from q
where quartile = 1;
-- 875 customers (8.75% of the full customer base), avg 10.0 orders,
-- avg spend 94,414, avg 7.6 days between orders (roughly weekly --
-- clearly human, distinct from the 2.6-day hyper-frequency tier),
-- last ordered 21 days before the window's end (still active).
-- This group alone = 29.2% of all revenue.

-- For context in the writeup: average spend of a one-time buyer is just
-- their single order value -- compare directly to the segment above.
select round(sum(total_spend) / count(*)) as avg_one_time_spend
from (
  select customer_id, sum(total) as total_spend
  from ecom.orders where payment_status = 'paid'
  group by customer_id having count(*) = 1
) t;
-- ~7,479 -- so the best-customer segment above spends ~12.6x what a
-- one-time buyer spends.
