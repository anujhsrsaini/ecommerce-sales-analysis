#!/usr/bin/env python3
"""Generate the three README figures from the live database.

Each figure maps to one milestone's headline finding:
  1. orders_per_customer.png  -- the long-tail / hyper-frequency anomaly (M2/M4)
  2. weekly_revenue_trend.png -- the April peak and decline (M3)
  3. segment_revenue_share.png -- customers vs. revenue share by segment (M4)
"""
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import matplotlib.ticker as mticker
import psycopg2
from dotenv import dotenv_values

ROOT = Path(__file__).resolve().parent.parent
FIGURES = ROOT / "figures"
FIGURES.mkdir(exist_ok=True)

env = dotenv_values(ROOT / ".env")

# Palette (validated categorical order -- see dataviz skill reference/palette.md)
BLUE = "#2a78d6"
AQUA = "#1baf7a"
RED = "#e34948"
INK = "#0b0b0b"
SECONDARY_INK = "#52514e"
MUTED = "#898781"
GRID = "#e1e0d9"
SURFACE = "#fcfcfb"

plt.rcParams.update({
    "font.family": "sans-serif",
    "font.sans-serif": ["DejaVu Sans", "Arial", "sans-serif"],
    "axes.edgecolor": GRID,
    "axes.labelcolor": SECONDARY_INK,
    "text.color": INK,
    "xtick.color": MUTED,
    "ytick.color": MUTED,
    "figure.facecolor": SURFACE,
    "axes.facecolor": SURFACE,
    "savefig.facecolor": SURFACE,
})


def get_conn():
    return psycopg2.connect(
        host=env["host"], port=env["port"], dbname=env["database"],
        user=env["username"], password=env["password"],
    )


def fetch(sql):
    with get_conn() as conn, conn.cursor() as cur:
        cur.execute(sql)
        return cur.fetchall()


def fig_orders_per_customer():
    rows = fetch("""
        with per_cust as (
          select customer_id, count(*) as n from ecom.orders
          where payment_status = 'paid' group by customer_id
        )
        select
          case
            when n = 1 then '1 order'
            when n between 2 and 9 then '2-9 orders'
            when n between 10 and 19 then '10-19 orders'
            else '20+ orders'
          end as bucket,
          count(*) as customers
        from per_cust
        group by 1
    """)
    order = ["1 order", "2-9 orders", "10-19 orders", "20+ orders"]
    counts = dict(rows)
    values = [counts.get(b, 0) for b in order]
    colors = [BLUE, BLUE, BLUE, RED]

    fig, ax = plt.subplots(figsize=(7, 4.2))
    bars = ax.bar(order, values, color=colors, width=0.6)
    ax.set_ylabel("Customers")
    ax.set_title("Half of customers order once — a small tail orders constantly", loc="left", fontsize=12, color=INK, pad=14)
    ax.spines[["top", "right", "left"]].set_visible(False)
    ax.yaxis.grid(True, color=GRID, linewidth=0.8)
    ax.set_axisbelow(True)
    ax.tick_params(left=False)
    for bar, v in zip(bars, values):
        ax.annotate(f"{v:,}", (bar.get_x() + bar.get_width() / 2, bar.get_height()),
                    textcoords="offset points", xytext=(0, 4), ha="center",
                    fontsize=10, color=INK)
    ax.annotate("262 accounts order every 2-3 days\nfor the entire 91-day window",
                xy=(3, values[3]), xytext=(1.6, values[0] * 0.55),
                fontsize=9, color=RED,
                arrowprops=dict(arrowstyle="->", color=RED, lw=1))
    fig.tight_layout()
    fig.savefig(FIGURES / "orders_per_customer.png", dpi=180)
    plt.close(fig)


def fig_weekly_revenue():
    rows = fetch("""
        select date_trunc('week', created_at) as week, sum(total) as revenue
        from ecom.orders
        where payment_status = 'paid'
        group by 1 order by 1
    """)
    weeks = [r[0] for r in rows]
    revenue = [float(r[1]) / 1e6 for r in rows]  # in millions

    fig, ax = plt.subplots(figsize=(7.5, 4.2))
    ax.plot(weeks, revenue, color=BLUE, linewidth=2, marker="o", markersize=5,
            markerfacecolor=BLUE, markeredgecolor=SURFACE, markeredgewidth=1)
    ax.fill_between(weeks, revenue, color=BLUE, alpha=0.08)
    ax.set_ylabel("Weekly revenue (₹M)")
    ax.set_title("Revenue peaked in early April and has fallen every week since", loc="left", fontsize=12, color=INK, pad=14)
    ax.spines[["top", "right"]].set_visible(False)
    ax.yaxis.grid(True, color=GRID, linewidth=0.8)
    ax.set_axisbelow(True)
    ax.xaxis.set_major_formatter(mticker.FuncFormatter(lambda x, pos: matplotlib.dates.num2date(x).strftime("%b %d")))
    fig.autofmt_xdate(rotation=30, ha="right")

    peak_idx = revenue.index(max(revenue))
    ax.annotate(f"peak: ₹{revenue[peak_idx]:.1f}M",
                xy=(weeks[peak_idx], revenue[peak_idx]), xytext=(10, 12),
                textcoords="offset points", fontsize=9, color=INK,
                arrowprops=dict(arrowstyle="->", color=MUTED, lw=1))
    ax.annotate(f"₹{revenue[-1]:.1f}M",
                xy=(weeks[-1], revenue[-1]), xytext=(0, -18),
                textcoords="offset points", fontsize=9, color=RED, ha="center")
    fig.tight_layout()
    fig.savefig(FIGURES / "weekly_revenue_trend.png", dpi=180)
    plt.close(fig)


def fig_segment_revenue_share():
    rows = fetch("""
        with per_cust as (
          select
            customer_id, count(*) as n, sum(total) as spend,
            extract(epoch from (max(created_at) - min(created_at))) / 86400.0 as span_days
          from ecom.orders where payment_status = 'paid'
          group by customer_id
        ),
        tiered as (
          select *,
            case when n = 1 then 'One-time'
                 when n between 2 and 19 then 'Repeat'
                 else 'Hyper-frequency' end as tier
          from per_cust
        )
        select tier, count(*) as customers, sum(spend) as revenue
        from tiered group by tier
    """)
    order = ["One-time", "Repeat", "Hyper-frequency"]
    data = {t: (c, float(r)) for t, c, r in rows}
    total_customers = sum(v[0] for v in data.values())
    total_revenue = sum(v[1] for v in data.values())
    pct_customers = [100 * data[t][0] / total_customers for t in order]
    pct_revenue = [100 * data[t][1] / total_revenue for t in order]

    x = range(len(order))
    width = 0.32
    fig, ax = plt.subplots(figsize=(7.5, 4.2))
    b1 = ax.bar([i - width / 2 for i in x], pct_customers, width, label="% of customers", color=BLUE)
    b2 = ax.bar([i + width / 2 for i in x], pct_revenue, width, label="% of revenue", color=AQUA)
    ax.set_xticks(list(x), order)
    ax.set_ylabel("Share (%)")
    ax.set_title("3.1% of customers, ordering like bots, drive 30% of revenue", loc="left", fontsize=12, color=INK, pad=14)
    ax.spines[["top", "right"]].set_visible(False)
    ax.yaxis.grid(True, color=GRID, linewidth=0.8)
    ax.set_axisbelow(True)
    ax.legend(frameon=False, loc="upper right")
    for bars in (b1, b2):
        for bar in bars:
            ax.annotate(f"{bar.get_height():.0f}%", (bar.get_x() + bar.get_width() / 2, bar.get_height()),
                        textcoords="offset points", xytext=(0, 4), ha="center", fontsize=9, color=INK)
    fig.tight_layout()
    fig.savefig(FIGURES / "segment_revenue_share.png", dpi=180)
    plt.close(fig)


if __name__ == "__main__":
    fig_orders_per_customer()
    fig_weekly_revenue()
    fig_segment_revenue_share()
    print("Wrote figures to", FIGURES)
