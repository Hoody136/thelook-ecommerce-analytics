# this table houses product information, -- One row per product. Its cost, category, name, brand, retail price, department, sku, and distribution center id are included.
select
    id as product_id,
    cost,
    category,
    name, 
    brand, 
    retail_price,
    department,
    sku,
    distribution_center_id
from {{ source('thelook', 'products') }}