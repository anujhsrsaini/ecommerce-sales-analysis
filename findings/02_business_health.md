# Business Health — Revenue & Growth Story

**Headline: We are not growing. Revenue peaked in April and has fallen every month since — down 41% from April to May alone — on falling order volume, not falling order value.**

## Revenue trajectory

Across the 91 days of data we have (March 16 – June 14), we generated **₹282.9M in gross revenue** on 37,822 paid orders (refunds are immaterial, at 0.4%). The all-time total hides the shape: revenue by month was ₹67.6M (Mar, partial) → **₹123.1M (Apr, peak)** → ₹72.8M (May) → ₹19.4M (Jun, partial). April and May are the only full, directly comparable months, and revenue fell **41% between them**. Daily order volume has fallen from ~569/day in March to ~189/day in June — a 67% decline in run rate, with June on pace to be the weakest month yet.

## What an average order looks like

AOV has been remarkably stable: ₹7,416 → ₹7,528 → ₹7,490 → ₹7,349, never moving more than 2.5%. We checked whether that stability hides an offsetting shift — bigger baskets but cheaper items, say — and it doesn't: basket size (~2.5 line items/order) and average item price (~₹2,375) are both flat too. **This is entirely a volume story, not a pricing story**: when revenue moves, order count moved with it.

## The observation worth investigating

The decline isn't an acquisition problem — new signups held steady at ~105-113/day every month, including June. It's a broad drop in *order-placing activity*, hitting new and repeat customers alike. The strongest lead: active marketing budget tracks the same shape almost exactly — ₹20L (Mar) → **₹43.75L (Apr, peak)** → ₹29.5L (May) → ₹12.7L (Jun), a 71% falloff that roughly matches the 65% falloff in daily orders. Several large (₹2L) reactivation and paid-acquisition campaigns ran back-to-back in late March/April; as spend tapered off, so did orders. Correlation, not proof — but it suggests April's volume was demand we bought, not demand we earned, and our real baseline may be closer to May/June than April.

*Methodology: revenue = orders where `payment_status = 'paid'` (cancelled orders never carry that status, so this cleanly excludes them). Orders tagged to a "USD" price list are numerically identical in scale to INR orders — almost certainly a labeling artifact, not a real second currency — so we've treated revenue as one homogeneous figure rather than apply a fabricated FX conversion.*
