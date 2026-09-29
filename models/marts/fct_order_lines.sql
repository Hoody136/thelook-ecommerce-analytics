-- grain: one row per order line - the lines on the customer's receipt,
-- enriched with order-level context (orderer, order status, order date).
with order_items as (

    select * from {{ ref('int_order_items__enriched') }}

),

orders as (

    select
        order_id,
        user_id,
        status as order_status,
        created_at as ordered_at
    from {{ ref('stg_thelook__orders') }}

),

final as (

    select
        oi.*,
        o.order_status,
        o.ordered_at
    from order_items oi
    left join orders o
        on oi.order_id = o.order_id

)

select * from final