-- =============================================================================
-- INGESTION: raw_thelook slice of thelook_ecommerce (v2)
-- =============================================================================
-- WHAT THIS FILE IS:
--   One-off "loading dock" script that copies a bounded slice of the public
--   dataset `bigquery-public-data.thelook_ecommerce` into OUR project as
--   raw tables in the `raw_thelook` dataset.
--
-- WHERE IT RUNS:
--   BigQuery console (browser) ONLY. This is NOT a dbt model and never
--   becomes one. dbt reads FROM raw_thelook via {{ source() }} but never
--   writes TO it. Raw tables are owned by the ingestion process.
--
-- THE INGESTION CONTRACT (our design principle):
--   1. FACTS are filtered by date (>= 2024-01-01) to bound cost and scope.
--      Facts: orders, order_items, inventory_items, events.
--   2. DIMENSIONS are copied in FULL, never date-filtered.
--      Dimensions: users, products, distribution_centers.
--      Why: a dimension must exist for every fact that references it,
--      regardless of when the dimension record was created. A customer who
--      registered in 2019 can still place an order in 2024.
--   3. Raw = faithful copy of the source. No renames, no casts, no
--      business logic here. "The map must match the territory." All
--      cleaning decisions live in the dbt staging layer.
--
-- VERSION HISTORY:
--   v1: order_items filtered on its OWN created_at.
--   v2 (this file): order_items filtered on the PARENT ORDER's created_at.
--       Fixes Audit Finding #2: 71 order_items created Jan 1-4 2024 were
--       orphaned because their parent orders were created in Dec 2023 and
--       fell outside the date filter. An item belongs to an order — if the
--       order is in scope, all of its items must be in scope.
--
-- COST NOTE:
--   Every query below reads the public dataset once. The heavy tables are
--   partitioned + clustered so downstream queries stay cheap. The bounding
--   date (2024-01-01) keeps the raw slice small by design.
-- =============================================================================


-- =============================================================================
-- FACT: orders
-- Grain: one row per order.
-- Filter: orders created on/after 2024-01-01 (the bounding date).
-- Partition by order date + cluster by user_id: the two most common
-- filter/join keys in analytics queries, so BigQuery scans less data.
-- =============================================================================
CREATE OR REPLACE TABLE `melodic-metrics-508711-u3.raw_thelook.orders`
PARTITION BY DATE(created_at)
CLUSTER BY user_id AS
SELECT *
FROM `bigquery-public-data.thelook_ecommerce.orders`
WHERE created_at >= TIMESTAMP '2024-01-01';


-- =============================================================================
-- FACT: order_items  *** v2 — THE FIX LIVES HERE ***
-- Grain: one row per item within an order (the revenue grain).
-- Filter: every item whose PARENT ORDER was created on/after 2024-01-01.
--
-- WHY EXISTS instead of filtering oi.created_at directly:
--   An order and its items can have slightly different timestamps (an order
--   created Dec 30 can have items processed Jan 2). Filtering items on their
--   own timestamp at a hard boundary orphans them — the item arrives without
--   its parent. Filtering on the parent's timestamp keeps order + items
--   together as an atomic unit. Referential integrity is preserved BY
--   CONSTRUCTION, which is always better than repairing it later.
--
-- WHY NOT a JOIN: we don't want any columns from orders in this table —
--   raw stays a faithful copy of the source table. WHERE EXISTS is a
--   semi-join: it filters without adding columns or duplicating rows.
-- =============================================================================
CREATE OR REPLACE TABLE `melodic-metrics-508711-u3.raw_thelook.order_items`
PARTITION BY DATE(created_at)
CLUSTER BY order_id AS
SELECT oi.*
FROM `bigquery-public-data.thelook_ecommerce.order_items` oi
WHERE EXISTS (
    SELECT 1
    FROM `bigquery-public-data.thelook_ecommerce.orders` o
    WHERE o.order_id = oi.order_id
      AND o.created_at >= TIMESTAMP '2024-01-01'
);


-- =============================================================================
-- FACT: inventory_items
-- Grain: one row per physical unit of stock.
-- Filter: items received into the warehouse on/after 2024-01-01.
-- NOTE: sold_at is NULL for unsold stock — that's a fact about the world,
--       not missing data. We keep it untouched in raw.
-- =============================================================================
CREATE OR REPLACE TABLE `melodic-metrics-508711-u3.raw_thelook.inventory_items`
PARTITION BY DATE(created_at) AS
SELECT *
FROM `bigquery-public-data.thelook_ecommerce.inventory_items`
WHERE created_at >= TIMESTAMP '2024-01-01';


-- =============================================================================
-- FACT: events  (the big one — ~1.3M rows in our window)
-- Grain: one row per website/app event (page view, cart, purchase...).
-- Filter: events on/after 2024-01-01.
-- Partitioning matters most here: events is by far the largest table, so
-- date-partitioned queries are dramatically cheaper than full scans.
-- =============================================================================
CREATE OR REPLACE TABLE `melodic-metrics-508711-u3.raw_thelook.events`
PARTITION BY DATE(created_at)
CLUSTER BY user_id AS
SELECT *
FROM `bigquery-public-data.thelook_ecommerce.events`
WHERE created_at >= TIMESTAMP '2024-01-01';


-- =============================================================================
-- DIMENSION: users
-- One row per customer. Copied in FULL (all registration dates) — a customer
-- who signed up in 2019 can still order in 2024, so filtering this table by
-- date would break facts that reference "old" customers.
-- NOTE: PII lives here in raw (names, emails, addresses). Raw is the only
--       place it exists in our project — staging minimises it.
-- =============================================================================
CREATE OR REPLACE TABLE `melodic-metrics-508711-u3.raw_thelook.users`
CLUSTER BY id AS
SELECT *
FROM `bigquery-public-data.thelook_ecommerce.users`;


-- =============================================================================
-- DIMENSION: products
-- One row per product in the catalogue. Copied in FULL — same reasoning as
-- users: an order in 2024 can reference a product listed years earlier.
-- =============================================================================
CREATE OR REPLACE TABLE `melodic-metrics-508711-u3.raw_thelook.products`
AS
SELECT *
FROM `bigquery-public-data.thelook_ecommerce.products`;


-- =============================================================================
-- DIMENSION: distribution_centers
-- One row per warehouse. Tiny table (~10 rows) — no partition/cluster needed.
-- Copied in FULL.
-- =============================================================================
CREATE OR REPLACE TABLE `melodic-metrics-508711-u3.raw_thelook.distribution_centers`
AS
SELECT *
FROM `bigquery-public-data.thelook_ecommerce.distribution_centers`;


-- =============================================================================
-- AFTER RUNNING — expected row counts (2024-01-01 onwards):
--   orders              ~90,700
--   order_items        ~131,400   (v2: now includes items of boundary orders)
--   events           ~1,333,000
--   inventory_items    (varies — 2024+ receipts)
--   users              100,000    (full dimension, all years)
--   products           ~29,000    (full dimension)
--   distribution_centers    10    (full dimension)
--
-- NOT here on purpose: future-dated rows (Audit Finding #1 — the synthetic
-- dataset contains rows dated after today). Filtering those is a BUSINESS
-- decision, so it lives in the dbt staging layer, not in raw.
-- =============================================================================