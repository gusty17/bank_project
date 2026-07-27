{{ config(materialized='table') }}

with customer_account as (
    select
        account_hub_key,
        customer_hub_key
    from {{ ref('link_customer_account') }}
),

-- current satellite version per account (balance snapshot)
sat_current as (
    select distinct on (account_hub_key)
        account_hub_key,
        balance_usd,
        open_date,
        load_date,
        record_source
    from {{ ref('sat_account_details') }}
    order by account_hub_key, load_date desc
)

select
    sat_current.account_hub_key,
    customer_account.customer_hub_key,
    -- date_key / snapshot_date = when the balance was captured (NOT open_date)
    cast(to_char(cast(sat_current.load_date as date), 'YYYYMMDD') as integer) as date_key,
    cast(sat_current.load_date as date) as snapshot_date,
    sat_current.open_date,
    sat_current.balance_usd,
    sat_current.record_source,
    sat_current.load_date
from sat_current
left join customer_account
    on customer_account.account_hub_key = sat_current.account_hub_key
