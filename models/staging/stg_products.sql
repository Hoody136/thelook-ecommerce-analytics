-- stg_products — the product catalogue. Grain: 1 row = 1 SKU.
with source as (

    select * from {{ source('thelook', 'products') }}

),

renamed as (

    select
        id              as product_id,
        name            as product_name,
        brand,
        category,
        department,
        sku,
        cost,                  -- wholesale cost → feeds margin maths
        retail_price,          -- list price → vs sale_price = discount depth
        distribution_center_id
    from source

)

select * from renamed