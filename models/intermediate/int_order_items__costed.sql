-- =============================================================================
-- MODEL: int_order_items__costed
-- LAYER: Intermediate (ephemeral — creates NO object in BigQuery)
-- =============================================================================
-- PURPOSE:
--   Attach the true unit cost to every order item. Sale price lives on the
--   order item; cost lives on the inventory item (the physical unit that
--   was sold). Joining them here — once — means every downstream mart gets
--   cost for free, and the join logic exists in exactly one place.
--
-- NAMING:
--   int_           = intermediate layer
--   order_items    = the entity (grain: one row per order item, unchanged)
--   __costed       = what this model does to it (double underscore separates
--                    entity from operation — dbt community convention)
--
-- GRAIN RULE: this model MUST NOT change the row count. One order item in,
--   one row out. If it ever does, the bug is here.
-- =============================================================================


-- -----------------------------------------------------------------------------
-- CTE 1: the order items (revenue grain — our starting point)
-- -----------------------------------------------------------------------------
with order_items as (

    select * from {{ ref('stg_order_items') }}

),

-- -----------------------------------------------------------------------------
-- CTE 2: inventory items — we only need the two columns involved in the join
-- (the key, and the cost we're fetching). Selecting narrowly keeps the
-- compiled SQL readable and the query cheaper.
-- -----------------------------------------------------------------------------
inventory as (

    select
        inventory_item_id,
        cost as product_cost   -- rename now, so the join output is unambiguous
    from {{ ref('stg_inventory_items') }}

),

-- -----------------------------------------------------------------------------
-- CTE 3: the join.
-- LEFT JOIN, deliberately: every order item must survive even if its
-- inventory row is somehow missing. An INNER JOIN here would silently drop
-- revenue rows — the most dangerous kind of bug, because nothing errors.
-- A missing cost instead leaves product_cost NULL, which is VISIBLE
-- downstream (and testable).
-- -----------------------------------------------------------------------------
joined as (

    select
        order_items.order_item_id,
        order_items.order_id,
        order_items.product_id,
        order_items.inventory_item_id,
        order_items.status,
        order_items.sale_price,
        inventory.product_cost,          -- the whole point of this model
        order_items.ordered_at as item_created_at,
        order_items.shipped_at,
        order_items.delivered_at,
        order_items.returned_at
    from order_items
    left join inventory
        on order_items.inventory_item_id = inventory.inventory_item_id

)

-- dbt style: the final select just exposes the last CTE. All the thinking
-- happened above; this line should be boring.
select * from joined