-- stg_inventory_items — physical stock units. Grain: 1 row = 1 unit of stock.
with source as (

    select * from {{ source('thelook', 'inventory_items') }}

),

renamed as (

    select
        id          as inventory_item_id,
        product_id,
        created_at  as received_at,     -- stock receipt date → sell-through denominator
        sold_at,                        -- NULL = still sitting on the shelf
        cost
        -- NOTE: the raw table carries denormalised product_* columns
        -- (product_name, product_brand...). We deliberately DROP them:
        -- stg_products is the single source of truth for product attributes.
        -- One fact, one home.
    from source

)

select * from renamed
