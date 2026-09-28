# this table houses order information, one row per order. It also contains user id, order status etc. 
# It does not contain the order value, just the amount of items within an order. 
select
    order_id,
    user_id,
    status,
    gender,
    created_at,
    returned_at,
    shipped_at,
    delivered_at,
    num_of_item as number_of_items 
from {{ source('thelook', 'orders') }}