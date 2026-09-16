-- stg_events — website clickstream. Grain: 1 row = 1 pageview/event.
with source as (

    select * from {{ source('thelook', 'events') }}

),

renamed as (

    select
        id             as event_id,
        user_id        as customer_id,
        session_id,                     -- groups events into visits → conversion rate
        sequence_number,                -- event order within a session
        event_type,                     -- 'product', 'cart', 'purchase'...
        uri,                            -- which page
        browser,
        traffic_source,
        city,
        state,
        postal_code,
        -- ip_address deliberately dropped: personal data under GDPR,
        -- and no KPI needs it when we have city/state.
        created_at     as event_at
    from source
    -- Audit finding #1 again:
    where created_at < current_timestamp()

)

select * from renamed