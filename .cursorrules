When generating dbt models for this project, always follow the folder structure,
naming conventions, and hub/link/satellite/star-schema patterns described below exactly.

# Project: Banking Data Pipeline (dbt + PostgreSQL) — Medallion Architecture

## Overview
This is a learning project implementing a medallion architecture (bronze → silver → gold)
using dbt and PostgreSQL, based on a synthetic banking dataset loaded into the `public`
schema in Postgres.

## Source tables (in `public` schema)
- customers(customer_id, first_name, last_name, email, city, credit_score, created_at)
- accounts(account_id, customer_id, account_type, balance_usd, open_date)
- cards(card_id, account_id, card_type, expiration_date)
- branches(branch_id, branch_name, city, country, manager_name)
- loans(loan_id, customer_id, loan_amount, interest_rate, start_date)
- merchants(merchant_id, merchant_name, city)
- transactions(transaction_id, account_id, merchant_id, amount_usd, transaction_date)

transactions is the central event table — it links accounts to merchants and is the
primary fact table candidate for the gold layer.

## Architecture

### Bronze (models/bronze/)
- One model per source table.
- Materialized as `table`.
- RAW extract only: `select source.*` — NO casting, NO trim, NO renaming, no business logic, no joins.
- The only additions are two lineage/metadata columns (not data transformations):
  `record_source` (literal, value 'kaggle_csv') and `_loaded_at` (ingestion timestamp).
- All type-casting/renaming happens later, in the silver layer.
- The silver layer INHERITS `record_source` from bronze (passthrough) rather than hardcoding it.
  `record_source` is descriptive metadata only: NEVER hashed into a hub/link key and NEVER part
  of a satellite hashdiff.
- Naming: bronze_<table_name>.sql (e.g. bronze_customers.sql, bronze_transactions.sql)

### Silver (models/silver/) — Data Vault
- Simple transformations live here: type-casting (e.g. numeric/date casts) applied inside the DV
  models via a `casted` CTE. NO trim() and no heavy business logic. Any renames (e.g. created_at ->
  created_date) also happen here. Business keys are hashed from the raw column so the hash stays
  identical across hubs, links, and satellites. Prefer flat CTEs / DISTINCT ON over nested subqueries.
- hubs/    — one hub per business entity, containing only the hashed business key + load_date + record_source.
             Materialized incremental, strategy = append (business keys are never updated, only added).
             Naming: hub_<entity>.sql (e.g. hub_customer.sql, hub_transaction.sql)
- links/   — relationships between hubs, keyed by a hash of the combined business keys.
             Materialized incremental, strategy = append.
             Naming: link_<entity1>_<entity2>.sql (e.g. link_account_merchant.sql, link_customer_account.sql)
- satellites/ — descriptive/measure attributes with hashdiff-based change detection.
             KEEP FULL HISTORY: every version of a hub's attributes is retained.
             Materialized incremental, strategy = append. Each row is a version keyed by
             (<entity>_hub_key, load_date). On each run, insert a new version row only when
             the incoming hashdiff differs from the LATEST stored hashdiff for that hub
             (latest fetched via DISTINCT ON (<entity>_hub_key) ordered by load_date desc).
             Unchanged rows are never re-inserted; older versions are never overwritten.
             Uniqueness is on the combination (<entity>_hub_key, load_date), not hub_key alone.
             Naming: sat_<entity>_details.sql (e.g. sat_account_details.sql, sat_transaction_details.sql)

Hub/link keys are generated via the generate_hub_key macro (macros/generate_hub_key.sql),
which wraps dbt_utils.generate_surrogate_key. Hashdiffs are generated the same way, over
the descriptive columns for that satellite. Never hash record_source into a hub/link key
or a hashdiff — it's metadata, not identity.

### Gold (models/gold/) — Kimball Star Schema over the Data Vault
Business logic lives here: derived columns (e.g. credit_tier bucketing), SCD Type 2
resolution from satellite history, and joins that combine entities into
business-meaningful, analyst-ready tables. Materialized as `table` in the gold schema.

**Dimensions are SCD Type 2** (one row per satellite version) — everywhere except `dim_date`.
Every SCD2 dim has:
- `<entity>_key` (PK) — version surrogate key = `generate_hub_key([<entity>_hub_key, load_date])`,
  hashing the actual column values (never literal strings).
- `<entity>_hub_key` — durable key, inherited from the hub, referenced by facts.
- The validity trio: `effective_start_date`, `effective_end_date`, `is_current`.
- `record_source`, passed through from the satellite.

SCD2 validity is derived per dim via a window function on the satellite (no nested subquery):
effective_start_date = load_date
effective_end_date = coalesce(lead(load_date) over (partition by <hub_key> order by load_date), '9999-12-31')
is_current = (lead(load_date) over (partition by <hub_key> order by load_date) is null)
Half-open `[start, end)` intervals — versions must never overlap. Add a deterministic
tie-breaker to the `ORDER BY` (e.g. `load_date, <hub_key>`) in case two versions share a
timestamp.

**Dimensions (models/gold/dimensions/):**
- `dim_customer`: customer_key (PK), customer_hub_key, customer_id, first_name, last_name,
  email, city, credit_score, credit_tier (derived), created_date, acquisition_month (derived),
  effective_start_date, effective_end_date, is_current, record_source
- `dim_account`: account_key (PK), account_hub_key, account_id, customer_hub_key, account_type,
  open_date, effective_start_date, effective_end_date, is_current, record_source
- `dim_card`: card_key (PK), card_hub_key, card_id, account_hub_key, card_type,
  expiration_date, effective_start_date, effective_end_date, is_current, record_source
- `dim_merchant`: merchant_key (PK), merchant_hub_key, merchant_id, merchant_name, city,
  effective_start_date, effective_end_date, is_current, record_source
- `dim_branch` (orphan — no fact FK): branch_key (PK), branch_hub_key, branch_id,
  branch_name, city, country, manager_name, effective_start_date, effective_end_date,
  is_current, record_source
- `dim_date` (static, NOT SCD2): built via `dbt_utils.date_spine` (2015-01-01 .. 2030-01-01).
  date_key (PK, yyyymmdd int), date_day, year, quarter, month, month_name, day_of_month,
  day_of_week, day_name, is_weekend, week_of_year, day_of_year, is_month_end.

Relationship hops: `dim_account` carries `customer_hub_key` (via `link_customer_account`);
`dim_card` carries `account_hub_key` (via `link_account_card`); `fact_transactions` gets
`customer_hub_key` via the account relationship.

**Facts (models/gold/facts/)** — carry durable hub keys, measures come from each entity's
current satellite version (historical attribute changes live in the SCD2 dims, not in facts):
- `fact_transactions` (grain: 1 transaction): transaction_hub_key, account_hub_key,
  merchant_hub_key, customer_hub_key, date_key, transaction_date, amount_usd,
  record_source, load_date
- `fact_loans` (grain: 1 loan): loan_hub_key, customer_hub_key, date_key, start_date,
  loan_amount, interest_rate, record_source, load_date
- `fact_account_balance` (grain: 1 account, current snapshot): account_hub_key,
  customer_hub_key, date_key, snapshot_date (capture date — NOT open_date), open_date,
  balance_usd, record_source, load_date. Dedupe to one row per account via
  `DISTINCT ON (account_hub_key) ... ORDER BY load_date DESC` (or `ROW_NUMBER() = 1`
  for portability to non-Postgres engines).

**Fan-out risk — this is a hard rule, not a suggestion:**
Because SCD2 dims can have multiple rows per hub_key, joining a fact to a dim on hub_key
alone will silently duplicate rows. Every fact-to-dim join must use one of:
- Current-state: `join dim_x d on d.<entity>_hub_key = f.<entity>_hub_key and d.is_current`
- Point-in-time: `... and f.<event_date> >= d.effective_start_date and f.<event_date> < d.effective_end_date`
The `is_current` uniqueness test (below) is what makes the current-state join provably 1:1.

## Folder structure
models/
├── bronze/
│ ├── _bronze__sources.yml
│ ├── bronze_customers.sql
│ ├── bronze_accounts.sql
│ ├── bronze_cards.sql
│ ├── bronze_branches.sql
│ ├── bronze_loans.sql
│ ├── bronze_merchants.sql
│ ├── bronze_transactions.sql
│ └── _bronze__models.yml
├── silver/
│ ├── hubs/ (hub_customer, hub_account, hub_card, hub_branch, hub_loan,
│ │ hub_merchant, hub_transaction, + _hubs__models.yml)
│ ├── links/ (link_customer_account, link_account_card, link_customer_loan,
│ │ link_account_merchant, + _links__models.yml)
│ └── satellites/ (sat_customer_details, sat_account_details, sat_card_details,
│ sat_branch_details, sat_loan_details, sat_merchant_details,
│ sat_transaction_details, + _satellites__models.yml)
└── gold/
├── dimensions/ (dim_date, dim_customer, dim_account, dim_card, dim_merchant,
│ dim_branch)
├── facts/ (fact_transactions, fact_loans, fact_account_balance)
└── _gold.yml

macros/
└── generate_hub_key.sql
## dbt_project.yml config convention
- Folder-level config (materialization, schema, incremental_strategy) is set once per
  folder in dbt_project.yml — including `models.bank_project.gold: +materialized: table, +schema: gold`.
- Model-level config() blocks only override what's unique to that model (mainly unique_key).
- Do not repeat folder-level defaults inside individual model files.

## Tests (models/gold/_gold.yml)
- **SCD2 dims**: `unique` + `not_null` on `<entity>_key`; `not_null` on `<entity>_hub_key`,
  business key, `effective_start_date`, `is_current`; one-current-row guardrail via
  `dbt_utils.unique_combination_of_columns` on `[<entity>_hub_key]` with `config: {where: "is_current"}`.
- **dim_date**: `unique` + `not_null` on `date_key`.
- **Facts**: `unique` + `not_null` on the grain key; `not_null` + `relationships` on each
  hub-key FK (tested against the silver **hubs**, the source of truth — not against gold
  dims) and on `date_key` (tested against `dim_date`); `not_null` on measures.

## Tech stack
- dbt-postgres
- PostgreSQL
- dbt_utils package (generate_surrogate_key, date_spine, unique_combination_of_columns)

## What Cursor should help with
- Writing/reviewing SQL models following the exact bronze (zero-touch) → silver
  (cast/format only, data vault) → gold (SCD2 dims + facts, star schema, business logic)
  pattern above.
- Verifying incremental logic and hashdiff comparisons are correct (skip unchanged rows,
  insert only on new business keys, new relationships, or changed hashdiffs).
- Verifying SCD2 window-function logic is correct (no overlapping intervals, exactly one
  current row per hub_key, correct tie-breaking).
- Enforcing the fan-out-safe join pattern on every fact-to-dim join.
- Catching schema/join mistakes and any accidental business logic leaking into silver.
- Keeping naming conventions consistent across all models.
- Build order: customers → accounts → cards → loans → branches → merchants → transactions
  (silver), then dim_date → SCD2 dims → facts (gold, after silver is fully built and tested).
- Run/build with `dbt build --select bronze` / `silver` / `gold` per layer, in order.
