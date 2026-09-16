# Metric Dictionary

&gt; The single source of truth for how this project calculates business
&gt; metrics. Every definition is computed from governed columns in
&gt; `fct_order_items` — never re-invented in a dashboard.
&gt;
&gt; **Status key:** ✅ implemented (column exists) · 📋 defined here,
&gt; built later (Stage 4 reporting mart)

## How to read the formulas

All metrics aggregate over `dbt_jhood.fct_order_items` unless stated
otherwise. "Keep" filter = `not is_returned and not is_cancelled`.

## Core revenue metrics

| Metric | Definition | Formula | Status |
|---|---|---|---|
| Gross Revenue | All captured sales, before returns/cancels | `sum(sale_price)` | ✅ |
| Gross Profit | Revenue minus unit cost of goods sold | `sum(gross_profit)` | ✅ |
| Gross Margin % | Profit as a share of revenue | `sum(gross_profit) / sum(sale_price)` | ✅ |
| Return Rate % | Share of items that came back | `countif(is_returned) / count(*)` | ✅ |
| Cancellation Rate % | Share of items cancelled | `countif(is_cancelled) / count(*)` | ✅ |
| **Net Revenue** | Revenue from items actually kept | `sum(sale_price) filter (keep)` | 📋 |
| **Net Profit** | Profit from items actually kept | `sum(gross_profit) filter (keep)` | 📋 |
| **Return Cost** | Profit destroyed by returns | `sum(gross_profit) filter (is_returned)` | 📋 |

## Order & fulfilment metrics

| Metric | Definition | Formula | Status |
|---|---|---|---|
| Items Sold | Count of order lines | `count(*)` | ✅ |
| Orders | Distinct parent orders | `count(distinct order_id)` | ✅ |
| AOV (avg order value) | Gross revenue per order | `sum(sale_price) / count(distinct order_id)` | 📋 |
| Avg Days to Ship | Order → ship, kept items only | `avg(days_to_ship)` | ✅ |
| Avg Days to Deliver | Order → delivery, kept items only | `avg(days_to_deliver)` | ✅ |

## Design decisions

1. **Returns stay in the data, flagged — not deleted.** `is_returned`
   rows remain in the fact so gross vs net can both be computed and the
   "margin eraser" (returns + cancellations ≈ 25% of items) is visible.
2. **Margin is a ratio of sums, never an average of ratios.**
   `avg(margin_pct)` across rows is mathematically wrong (items with
   different prices would count equally). Always `sum/sum`.
3. **Nulls are honest.** `days_to_ship` is null for unshipped items —
   those rows are *excluded from the average*, which is correct:
   "average shipping time of things that shipped" is the answerable
   question.
4. **Current benchmarks (2024+ data):** gross revenue $7.74M ·
   margin 51.9% · returns 10.0% · cancellations 15.1%.
   Stage 4's reporting mart should reproduce these numbers exactly.