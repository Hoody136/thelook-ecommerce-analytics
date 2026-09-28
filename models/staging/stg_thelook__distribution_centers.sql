# this table houses information about distribution centers.
select
    id as distribution_center_id,
    name,
    latitude,
    longitude,
    distribution_center_geom
from {{ source('thelook', 'distribution_centers') }}