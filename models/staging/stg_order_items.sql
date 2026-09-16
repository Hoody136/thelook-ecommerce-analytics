-- ============================================================================
-- stg_order_items — cleaned order line items. THE REVENUE GRAIN.
-- Grain: 1 row = 1 order line item (per our Bus Matrix). Every pound of
-- revenue, margin, and returns maths hangs off this table.
-- ============================================================================
with source as (

    select * from {{ source('thelook', 'order_items') }}

),

renamed as (

    select
        id                as order_item_id,
        order_id,
        user_id           as customer_id,
        product_id,
        inventory_item_id,
        status,                  -- lifecycle: 'Complete', 'Returned', 'Cancelled'...
                                 -- these exact strings drive gross vs net revenue later
        sale_price,              -- actual captured revenue for this line
        created_at        as ordered_at,
        shipped_at,
        delivered_at,
        returned_at
    from source
    -- Audit finding #1 applies here too (this table also had future-dated rows):
    where created_at < current_timestamp()

)

select * from renamed