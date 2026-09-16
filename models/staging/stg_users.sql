-- stg_users — customer dimension. Grain: 1 row = 1 customer.
-- PII DECISION (data minimisation): no KPI in our contract needs names,
-- street addresses, or raw emails — so staging doesn't expose them.
-- Email is hashed (SHA-256): still joinable, useless if leaked.
with source as (

    select * from {{ source('thelook', 'users') }}

),

renamed as (

    select
        id                 as customer_id,
        gender,
        age,
        city,
        state,
        country,
        postal_code,
        latitude,
        longitude,
        traffic_source,        -- acquisition channel → feeds marketing analysis
        created_at         as customer_since,
        to_hex(sha256(email)) as email_hash
    from source

)

select * from renamed