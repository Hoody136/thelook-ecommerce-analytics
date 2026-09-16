-- ============================================================================
-- stg_orders — the cleaned, renamed, business-ready view of raw orders.
--
-- STAGING LAYER RULES (what a stg_ model may and may not do):
--   MAY:    rename columns, cast types, filter junk rows, basic cleanup
--   MAY NOT: join to other tables, aggregate, apply business logic
--   Grain:  unchanged — 1 row = 1 order header, same as the raw table.
--   Materialized as a VIEW (set once in dbt_project.yml): cheap, always fresh.
-- ============================================================================

-- CTE 1: IMPORT — grab the raw data through the source() contract.
-- {{ source('thelook', 'orders') }} compiles to the full physical table name
-- `melodic-metrics-508711-u3.raw_thelook.orders` — and records the lineage link.
with source as (

    select * from {{ source('thelook', 'orders') }}

),

-- CTE 2: RENAMED + CLEANED — the only "logic" a staging model is allowed.
renamed as (

    select
        order_id,
        user_id          as customer_id,   -- rename to the language the business uses
        status,
        gender,
        created_at       as ordered_at,    -- "created" is ambiguous
        shipped_at,
        delivered_at,
        returned_at,
        num_of_item      as item_count
    from source
    -- AUDIT FINDING #1: The Look generates synthetic rows dated in the FUTURE.
    -- Left unfiltered, "sales to date" would include orders from 3 days ahead.
    -- This upper bound is the fix, documented in docs/lifecycle/.
    where created_at < current_timestamp()

)

-- FINAL: staging models always end with a bare select from the last CTE.
-- If you need to debug, you can highlight any single CTE and run it alone.
select * from renamed