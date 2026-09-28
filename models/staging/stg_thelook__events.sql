# this table houses information pertaining to online events, like session id, sequence number and traffic source.
select
    id as event_id,
    user_id,
    sequence_number,
    session_id,
    created_at,
    ip_address,
    city,
    state,
    postal_code,
    browser,
    traffic_source,
    uri,
    event_type
from {{ source('thelook', 'events') }}