# Stage 1–2: Sources & Ingestion

&gt; **Lifecycle layers covered:** 1 (Sources), 2 (Ingestion), and the staging
&gt; half of 4 (Transformation).
&gt; **Status:** Complete — 7 staging models, 20 tests, all passing.

## What we built

A bounded raw slice of `bigquery-public-data.thelook_ecommerce` (2024-01-01
onwards) copied into `raw_thelook`, plus a dbt staging layer of 7 views in
`dbt_jhood` that rename, cast, filter, and minimise PII — nothing more.

## The ingestion contract

Two rules, decided *before* writing any SQL:

1. **Facts are date-filtered; dimensions are copied in full.**
   A customer who registered in 2019 can order in 2024 — filtering
   `users` by date would break facts that reference "old" dimensions.
2. **Raw is a faithful copy of the source.** No renames, no business logic.
   The map must match the territory. Every cleaning decision lives in dbt,
   where it's versioned, tested, and reviewable.

## Audit findings (and what we did about them)

### Finding #1 — Future-dated rows in the source
The synthetic dataset contains ~1,560 rows dated *after* today's date.
**Decision:** keep them in raw (faithful copy), filter them in staging
(`where created_at &lt; current_timestamp()`). Filtering is a business
decision, so it lives in the transformation layer.

### Finding #2 — Boundary referential-integrity break (71 orphans)
**Caught by:** dbt `relationships` test on `stg_order_items.order_id`.
**Symptom:** 71 order_items with no parent order in raw.
**Root cause:** ingestion filtered `order_items` on its *own* `created_at`.
An order created Dec 2023 can have items processed Jan 2024 — at the
2024-01-01 boundary, 71 items arrived whose parents were cut.
**Fix (ingestion contract v2):** filter `order_items` by the *parent
order's* timestamp via `WHERE EXISTS`, keeping order + items atomic.
**Verified by:** the same test now passes. 27/27 green.

**Lesson:** integrity enforced at ingestion (by construction) beats
integrity repaired downstream (by cleanup). Also: the incident required
dropping and recreating the raw table, which was safe *only because* raw
is fully reproducible from source. Disposability is a feature.

## Verification
