-- =============================================================================
-- MODEL: fct_order_items
-- LAYER: Marts (materialized as a TABLE — our first real warehouse object)
-- =============================================================================
-- GRAIN: one row per order item. This is the REVENUE grain of the business:
--   the atomic "thing that happened" that money attaches to. Every measure
--   here (sale_price, product_cost, gross_profit) is true for exactly one
--   row and can be summed to any level: order, customer, product, month.
--
-- INPUTS:
--   int_order_items__costed — items with unit cost attached (ephemeral;
--       its SQL gets injected into this model at compile time)
--   stg_orders — provides customer_id and the order's canonical timestamp.
--       We can use an INNER JOIN here *because* the staging relationships
--       test already proved every item has a parent order. Tests buy you
--       the right to write confident joins.
--
-- DESIGN PRINCIPLE: anything a BI tool would otherwise have to recompute
--   (profit, margin, return flags, shipping durations) is computed HERE,
--   once, tested, and versioned. Business logic lives in the warehouse,
--   not scattered across dashboards.
-- =============================================================================


-- -----------------------------------------------------------------------------
-- CTE 1: items with cost — the intermediate model. Watch what happens in the
-- compiled SQL: this entire CTE will contain the full text of
-- int_order_items__costed, injected inline. Ephemeral in action.
-- -----------------------------------------------------------------------------
with items as (

    select * from {{ ref('int_order_items__costed') }}

),

-- -----------------------------------------------------------------------------
-- CTE 2: order context. We take only what the fact needs:
--   customer_id  — who placed the order (FK to dim_customers)
--   ordered_at   — the canonical business timestamp. NOTE: the fact's date
--                  comes from the ORDER, not the item. "When did the
--                  business event happen?" = when the order was placed.
-- -----------------------------------------------------------------------------
orders as (

    select
        order_id,
        customer_id,
        ordered_at
    from {{ ref('stg_orders') }}

),

-- -----------------------------------------------------------------------------
-- CTE 3: the join. INNER is safe here — the staging relationships test
-- guarantees every order_item has a parent order (that's the test we fixed
-- with ingestion contract v2; this is the dividend it pays).
-- -----------------------------------------------------------------------------
joined as (

    select
        items.order_item_id,
        items.order_id,
        orders.customer_id,
        items.product_id,
        date(orders.ordered_at) as order_date,   -- FK to dim_date
        items.status,
        items.sale_price,
        items.product_cost,
        items.shipped_at,
        items.delivered_at,
        items.returned_at
    from items
    inner join orders
        on items.order_id = orders.order_id

),

-- -----------------------------------------------------------------------------
-- CTE 4: derived measures, first pass.
--   gross_profit is computed here (not in the final select) because
--   margin_pct needs it — and SQL can't reference a SELECT alias in the
--   same SELECT (order of operations strikes again — remember stg_orders!).
-- -----------------------------------------------------------------------------
measures as (

    select
        *,
        sale_price - product_cost as gross_profit
    from joined

)

-- -----------------------------------------------------------------------------
-- Final select: everything above, plus the measures that depend on
-- gross_profit or on date arithmetic.
--   SAFE_DIVIDE: returns NULL instead of erroring on divide-by-zero.
--   DATE_DIFF(start, end) is (end - start) in BigQuery — check argument
--   order when you adapt this pattern; it differs across warehouses.
-- -----------------------------------------------------------------------------
select
    order_item_id,
    order_id,
    customer_id,
    product_id,
    order_date,
    status,
    sale_price,
    product_cost,
    gross_profit,
    safe_divide(gross_profit, sale_price) as margin_pct,
    returned_at is not null as is_returned,       -- boolean flags: cheap to
    status = 'Cancelled' as is_cancelled,          -- store, expensive to derive
    date_diff(date(shipped_at), order_date, day) as days_to_ship,
    date_diff(date(delivered_at), order_date, day) as days_to_deliver
from measures