-- =====================================================================
-- 02_revenue.sql
-- Milestone 3: revenue trajectory, AOV, and the growth story for the
-- board. Builds on 01_exploration.sql. Comments record what I checked
-- and why, in the order I ran it.
-- =====================================================================


-- STEP 0: STATUS FILTER DECISION
-- Does 'cancelled' ever overlap with a successful payment? If not, a
-- simple payment_status = 'paid' filter cleanly excludes cancelled/
-- failed/abandoned orders without needing to touch order.status at all.
select status, payment_status, count(*) as n, round(sum(total)) as rev
from ecom.orders
group by status, payment_status
order by status, payment_status;
-- Every 'cancelled' order has payment_status = 'failed' -- no cancelled
-- order ever collected money. Decision: revenue = sum(total) where
-- payment_status = 'paid'. This also sidesteps the status-casing mess
-- (shipped/SHIPPED/Shipped) noted in milestone 2, since we never filter
-- on `status` for revenue.


-- STEP 0b: CURRENCY CHECK -- catches a real trap before summing `total`
-- orders.price_list_id -> price_lists.currency. If some orders are USD
-- and some are INR, summing `total` directly mixes currencies.
select pl.currency, count(*) as orders, round(sum(o.total)) as raw_total, round(avg(o.total)) as raw_aov
from ecom.orders o
join ecom.price_lists pl on o.price_list_id = pl.price_list_id
group by pl.currency;
-- 3,206 orders are tagged 'USD', 36,794 'INR' -- but both groups have
-- the SAME average order total (~7,500). Real USD retail orders
-- averaging $7,500 would be absurd, so the USD tag doesn't reflect an
-- actual FX-adjusted total in this column -- it looks like a labeling
-- artifact, not a real second currency. Decision: treat `total` as one
-- homogeneous revenue figure (effectively INR, since the price points
-- and 76% India customer base both point that way) and flag the USD
-- tag as a data-quality issue rather than fabricate an FX conversion
-- the data doesn't actually support. Documented in the writeup.


-- STEP 1: TOTAL REVENUE, ALL-TIME -- ORDER OF MAGNITUDE
select
  count(*) as paid_orders,
  round(sum(total)) as gross_revenue,
  round(avg(total)) as aov
from ecom.orders
where payment_status = 'paid';
-- 37,822 paid orders, ~282.9M revenue (in the order's native units --
-- effectively INR per the currency note above), AOV ~7,479.

-- Net of refunds, for completeness -- are refunds material to the
-- headline number?
select
  round(sum(o.total)) as gross_revenue,
  round((select sum(amount) from ecom.refunds where status = 'succeeded')) as total_refunds,
  round(sum(o.total) - (select sum(amount) from ecom.refunds where status = 'succeeded')) as net_revenue
from ecom.orders o
where o.payment_status = 'paid';
-- Refunds are ~1.06M against ~282.9M gross -- 0.37%. Immaterial to the
-- trend story; gross and net revenue tell the same shape.


-- STEP 2: MONTHLY REVENUE SERIES -- EYEBALL THE SHAPE
select
  date_trunc('month', created_at) as month,
  count(*) as orders,
  round(sum(total)) as revenue,
  round(avg(total)) as aov
from ecom.orders
where payment_status = 'paid'
group by 1
order by 1;

-- Sanity check: do the four monthly revenue figures sum to the
-- all-time total from Step 1? (confirms no months are being dropped
-- or double-counted by the date_trunc grouping)
-- 67,565,766 + 123,101,391 + 72,768,051 + 19,424,024 = 282,859,232 -- matches.

-- The data only covers March 16 - June 14 (confirmed in milestone 1).
-- March and June are PARTIAL months (16 and 14 days respectively);
-- April and May are the only full, directly comparable months. Check
-- day coverage explicitly so the writeup doesn't compare apples to oranges.
select date_trunc('month', created_at) as month,
       min(created_at::date) as first_day, max(created_at::date) as last_day,
       count(distinct created_at::date) as distinct_days
from ecom.orders
group by 1 order by 1;

-- Normalize for partial months: orders per day, not just orders per
-- month, is the only fair way to compare March/June against April/May.
select
  date_trunc('month', created_at) as month,
  count(*) as orders,
  count(distinct created_at::date) as days,
  round(count(*)::numeric / count(distinct created_at::date), 1) as orders_per_day
from ecom.orders
where payment_status = 'paid'
group by 1 order by 1;
-- Daily order rate: Mar 569/day -> Apr 545/day -> May 313/day -> Jun 189/day.
-- A clear, sustained decline from the March/April peak -- not a partial-month artifact.

-- Weekly cut, to see the shape at finer grain than 4 monthly buckets.
select date_trunc('week', created_at) as week, count(*) as orders, round(sum(total)) as revenue
from ecom.orders
where payment_status = 'paid'
group by 1 order by 1;
-- Confirms it's a steady week-over-week slide from late March/early
-- April onward, not a single cliff -- revenue nearly halves by early May
-- and keeps falling into June.


-- STEP 3: AOV OVER TIME -- HAS IT MOVED?
-- Already visible in the Step 2 monthly table: AOV sits in a tight band
-- (7,349 - 7,528) across all four months, a <2.5% range. AOV is not
-- driving the revenue trend -- order volume is.

-- Is that AOV stability real, or is it masking an offsetting shift
-- (bigger baskets but cheaper items, or vice versa)? Break AOV into its
-- two components: line items per order (basket size) and average unit
-- price per line (item price).
select
  date_trunc('month', o.created_at) as month,
  round(avg(items_per_order.n_items), 2) as avg_line_items_per_order,
  round(avg(oi.unit_price)) as avg_unit_price
from ecom.orders o
join ecom.order_items oi on oi.order_id = o.order_id
join (
  select order_id, count(*) as n_items from ecom.order_items group by order_id
) items_per_order on items_per_order.order_id = o.order_id
where o.payment_status = 'paid'
group by 1
order by 1;
-- Both components are flat too (~2.5 items/order, ~2,350-2,400 avg unit
-- price every month). AOV stability is real, not two offsetting trends
-- cancelling out. Confirms: this is purely a volume story.


-- STEP 4: ONE CONCRETE OBSERVATION -- WHAT EXPLAINS THE MARCH/APRIL PEAK
-- AND THE DECLINE SINCE?

-- Is the decline an acquisition problem (fewer new customers) or a
-- retention/repeat-purchase problem (existing customers ordering less)?
select date_trunc('month', created_at) as month, count(*) as new_customers
from ecom.customers
group by 1 order by 1;
-- New signups: 1,664 / 3,382 / 3,461 / 1,493. Normalized per day (16,
-- 30, 31, 14 days) that's ~104 / 113 / 112 / 107 signups per day --
-- essentially flat all four months. Acquisition did NOT slow down.

with first_orders as (
  select customer_id, min(created_at) as first_order_at
  from ecom.orders
  group by customer_id
)
select
  date_trunc('month', o.created_at) as month,
  count(*) filter (where o.created_at = fo.first_order_at) as first_time_orders,
  count(*) filter (where o.created_at != fo.first_order_at) as repeat_orders
from ecom.orders o
join first_orders fo on o.customer_id = fo.customer_id
where o.payment_status = 'paid'
group by 1 order by 1;
-- Both first-time AND repeat order counts fall in step with the overall
-- decline -- so it isn't one customer segment; it's a broad drop in
-- order-placing activity across the board, even though new signups held steady.

-- Does marketing spend line up with the order curve? Sum campaign
-- budget active (start/end range overlaps) in each month.
select
  m as month,
  round(sum(c.budget)) as active_campaign_budget,
  count(*) as active_campaigns
from generate_series('2026-03-01'::date, '2026-06-01'::date, interval '1 month') m
join ecom.marketing_campaigns c
  on c.starts_at::date <= (m + interval '1 month' - interval '1 day')
 and c.ends_at::date  >= m
group by 1 order by 1;
-- Active budget: 2.0M (Mar) -> 4.4M (Apr) -> 2.9M (May) -> 1.3M (Jun).
-- Budget peaks in April and falls 71% by June -- almost the same shape
-- and timing as the order-volume decline (-65% daily rate, Apr to Jun).
-- Correlation, not proof of causation, but a strong lead: heavy Mar/Apr
-- campaign spend coincides with the volume peak, and as spend tapered
-- off, so did orders -- from both new and returning customers.
