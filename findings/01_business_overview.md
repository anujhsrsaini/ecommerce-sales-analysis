# Business Overview — First Look at Our Data

## What this business does

We're a general-merchandise online retailer, not a single-category specialist. Products span 14 categories — accessories, skincare, haircare, shoes, apparel (tops, jackets, jeans), home goods (decor, kitchen, bedding), and consumer electronics (smartwatches, speakers, headphones) — across roughly 4,000 products from 120 brands. The customer base is overwhelmingly India-based (76%), with a smaller US segment (14%), and checkout runs through a mix of Razorpay, PayU, cash-on-delivery, and Stripe — a payment mix typical of an India-first operation with some international reach.

## Scale

We have **10,000 customers** and **40,000 orders**, of which **37,822 were successfully paid**, generating roughly **₹28.3 crore (~$3.4M)** in revenue at an average order value of **~₹7,500**. Important caveat: this data spans only **91 days** (March 16 – June 14, 2026). That's enough to describe current activity and shopping behavior, but too short to say anything about seasonality, year-over-year growth, or long-term retention — those conclusions will need more history.

## What I noticed

The order-to-customer ratio (4 orders per customer, on average) is misleading. **Half of our customers (4,999 of 10,000) have placed exactly one order** — the average is being pulled up by a long tail. Digging into that tail: **281 customers (2.8% of the base) account for 12,317 orders — 31% of all order volume** — and the single most active customer placed 178 orders in 91 days, often multiple per day, every day, for three straight months. That's not how an individual shops. These accounts aren't tagged as wholesale, B2B, or any other distinct segment in our system — they're scattered across every customer segment we track, including "Churned" and "At Risk," which suggests our segmentation isn't actually driven by order behavior. Before we use average order frequency or segment labels in any retention or growth analysis, we should figure out who these high-frequency accounts really are.
