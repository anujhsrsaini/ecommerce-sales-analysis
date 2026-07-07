-- =====================================================================
-- 01_exploration.sql
-- Milestone 2: first look at the database. No data dictionary was given,
-- so this file is a notebook of "what I checked and why", in the order
-- I actually ran it: inventory -> sample -> trace relationships ->
-- answer the CTO's question -> chase down the thing that looked off.
-- Connection: Postgres (Supabase), schema `ecom`. Run via scripts/run_query.py
-- =====================================================================


-- STEP 1: INVENTORY THE SCHEMA
-- What schemas/tables exist at all? The instance turned out to host more
-- than one project (ecom, saas, saas_metrics, meta) -- so scope to `ecom`.
select table_schema, table_name
from information_schema.tables
where table_schema not in ('pg_catalog', 'information_schema')
order by table_schema, table_name;

-- Roughly how big is each ecom table? Uses live-tuple estimates
-- (pg_stat_user_tables) instead of count(*) so it's fast on 40+ tables.
-- This is what pointed me at customers/orders/order_items/products as
-- the core of the business, vs. small lookup tables (categories, brands)
-- and clearly-unused ones (collections, consents both at 0 rows).
select relname as table_name, n_live_tup as approx_rows
from pg_stat_user_tables
where schemaname = 'ecom'
order by n_live_tup desc;


-- STEP 2: SAMPLE THE CORE TABLES
-- Read what's actually in the columns before trusting any names.
select * from ecom.customers limit 10;
select * from ecom.orders limit 10;
select * from ecom.order_items limit 10;
select * from ecom.products limit 10;
select * from ecom.product_variants limit 10;
select * from ecom.payment_transactions limit 10;
select * from ecom.shipments limit 10;


-- STEP 3: TRACE THE RELATIONSHIPS
-- orders.customer_id -> customers.customer_id. Sanity-check there are no
-- orphan orders pointing at a customer that doesn't exist.
select count(*) as orphan_orders
from ecom.orders o
left join ecom.customers c on o.customer_id = c.customer_id
where c.customer_id is null;
-- Result: 0. Clean on this join, at least.


-- STEP 4: ANSWER THE CTO'S QUESTION -- SCALE

-- How many customers do we have?
select count(*) as customer_count from ecom.customers;
-- 10,000

-- How many orders, and how many actually got paid for (vs. abandoned/failed)?
select count(*) as order_count from ecom.orders;
-- 40,000
select count(*) as paid_orders from ecom.orders where payment_status = 'paid';
-- 37,822

-- What time span does the data cover? This matters -- three months of
-- data supports "here's a snapshot of current activity", not "here's a
-- trend" or "here's our yearly seasonality".
select min(created_at) as first_order, max(created_at) as last_order,
       max(created_at) - min(created_at) as span
from ecom.orders;
-- 2026-03-16 to 2026-06-14 -- 91 days, ~3 months.

-- Revenue and average order value, on paid orders only.
select
  count(*) as orders,
  round(sum(total)) as total_revenue,
  round(avg(total)) as avg_order_value
from ecom.orders
where payment_status = 'paid';
-- ~40k paid orders, ~28.3 crore INR revenue, ~7,479 INR average order.

-- What does an order actually break down to, status-wise?
select status, count(*) as n, round(100.0 * count(*) / sum(count(*)) over (), 1) as pct
from ecom.orders
group by status
order by n desc;

-- What do we sell? Category footprint by product count.
select cat.category_name, count(distinct p.product_id) as num_products
from ecom.products p
join ecom.categories cat on p.category_id = cat.category_id
group by cat.category_name
order by num_products desc;

-- Where are customers based?
select country, count(*) as customers
from ecom.customers
group by country
order by customers desc;

-- How do customers find us?
select acquisition_channel, count(*) as customers
from ecom.customers
group by acquisition_channel
order by customers desc;

-- How do they pay?
select gateway, status, count(*) as n
from ecom.payment_transactions
group by gateway, status
order by gateway, n desc;


-- STEP 5: ORDER-TO-CUSTOMER RATIO -- HOW OFTEN DO PEOPLE ACTUALLY BUY?
-- 40,000 orders / 10,000 customers = 4 orders/customer on average.
-- But averages hide shape -- so look at the actual distribution.
select orders_per_customer, count(*) as num_customers
from (
  select customer_id, count(*) as orders_per_customer
  from ecom.orders
  group by customer_id
) t
group by orders_per_customer
order by orders_per_customer;
-- Half of all customers (4,999 / 10,000) have placed exactly ONE order.
-- The "4 orders per customer" average is being pulled up by a long tail.


-- STEP 6: SOMETHING LOOKED OFF -- CHASE THE TAIL
-- How much of the order volume does that tail actually account for?
with per_cust as (
  select customer_id, count(*) as n from ecom.orders group by customer_id
)
select
  count(*) filter (where n = 1)              as one_order_customers,
  count(*) filter (where n between 2 and 9)  as low_repeat_customers,
  count(*) filter (where n between 10 and 19) as heavy_customers,
  count(*) filter (where n >= 20)             as extreme_customers,
  sum(n)   filter (where n >= 20)             as orders_from_extreme_customers,
  (select count(*) from ecom.orders)          as total_orders
from per_cust;
-- 281 customers (2.8% of the base) placed 12,317 orders -- 31% of all
-- order volume -- in the same 91-day window everyone else is in.

-- What does that actually look like day-to-day for the single most
-- frequent customer (178 orders in 91 days)?
select order_id, created_at, status, total
from ecom.orders
where customer_id = (
  select customer_id from ecom.orders group by customer_id order by count(*) desc limit 1
)
order by created_at
limit 15;
-- Multiple orders per day, most days, for three straight months.
-- Not how a person shops.

-- Are these heavy buyers at least flagged as a distinct segment
-- (e.g. wholesale/B2B), which would explain the pattern?
select cs.segment_name, count(*) as n
from ecom.segment_memberships sm
join ecom.customer_segments cs on sm.segment_id = cs.segment_id
where sm.customer_id in (
  select customer_id from ecom.orders group by customer_id having count(*) >= 20
)
group by cs.segment_name
order by n desc;
-- No -- they're scattered across every segment, including "Churned" and
-- "At Risk". The segment field isn't tracking actual order behavior.


-- STEP 7: A COUPLE OF DATA-QUALITY ISSUES WORTH FLAGGING ALONGSIDE THE ABOVE

-- Order status values aren't normalized -- casing is inconsistent
-- (shipped / SHIPPED / Shipped all appear as distinct groups above).
-- Anyone aggregating by status naively will undercount.

-- How much of the customer base is missing country data?
select country, count(*) as customers
from ecom.customers
group by country
order by customers desc;
-- ~1,000 of 10,000 customers (10%) have blank/'N/A'/null country --
-- worth fixing before doing any geographic reporting.

-- Returns/refunds, for scale -- not alarming, but worth having on hand.
select
  (select count(*) from ecom.orders)          as total_orders,
  (select count(*) from ecom.return_requests)  as return_requests,
  (select count(*) from ecom.refunds)          as refunds;
