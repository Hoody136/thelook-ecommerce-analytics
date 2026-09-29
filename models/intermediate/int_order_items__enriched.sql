with order_items as (

    select * from {{ ref('stg_thelook__order_items') }}

),

products as (

    select * from {{ ref('stg_thelook__products') }}

),

inventory_items as (

    select * from {{ ref('stg_thelook__inventory_items') }}

),

final as (

    select
        oi.order_item_id,
        oi.order_id,
        oi.product_id,
        oi.user_id,
        oi.status,
        oi.created_at,
        oi.inventory_item_id,
        oi.returned_at,
        oi.shipped_at,
        oi.delivered_at,
        oi.sale_price,
        p.name as product_name,
        p.category,
        p.brand,
        p.retail_price,
        ii.cost as unit_cost,
        oi.sale_price - ii.cost as line_gross_profit,
        p.retail_price - oi.sale_price as line_discount,
        (safe_divide(p.retail_price - oi.sale_price, p.retail_price)) as discount_pct,
        (safe_divide(oi.sale_price - ii.cost, oi.sale_price)) as gross_margin_pct
    from order_items oi
    left join products p on oi.product_id = p.product_id
    left join inventory_items ii on oi.inventory_item_id = ii.inventory_item_id

)

select * from final