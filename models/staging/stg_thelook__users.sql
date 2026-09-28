# this table houses user information, -- One row per registered user: identity, geography, acquisition source, signup date.
select
    id as user_id,
    first_name,
    last_name,
    email,
    age,
    gender,
    state,
    street_address,
    postal_code,
    city,
    country,
    latitude,
    longitude,
    traffic_source,
    created_at
from {{ source('thelook', 'users') }}


-- user_geom excluded: duplicates latitude/longitude; reintroduce if spatial
-- analysis (e.g. customer-to-DC distance) is ever required.
-- PII columns present here (staging mirrors source); marts will exclude/hash — see docs.