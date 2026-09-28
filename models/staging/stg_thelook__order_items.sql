# this table houses order information, but at a granular level: one row per order line item. It contains the product id, order id, user id, sale price etc.
select
    id as order_item_id,
    order_id,
    user_id,
    product_id,
    inventory_item_id,
    status,
    created_at,
    returned_at,
    shipped_at,
    delivered_at,
    sale_price
from {{ source('thelook', 'order_items') }}