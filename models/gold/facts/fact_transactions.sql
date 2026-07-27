{{ config(materialized='table') }}

with link as (

    select * from {{ ref('link_transaction_account_merchant') }}

),

-- current satellite version per transaction
sat_current as (
    select distinct on (transaction_hub_key)
        transaction_hub_key,
        amount_usd,
        transaction_date,
        load_date,
        record_source
    from {{ ref('sat_transaction_details') }}
    order by transaction_hub_key, load_date desc
),

-- account -> customer hop
customer_account as (
    select
        account_hub_key,
        customer_hub_key
    from {{ ref('link_customer_account') }}
)

select
    link.transaction_hub_key,
    link.account_hub_key,
    link.merchant_hub_key,
    customer_account.customer_hub_key,
    cast(to_char(cast(sat_current.transaction_date as date), 'YYYYMMDD') as integer) as date_key,
    sat_current.transaction_date,
    sat_current.amount_usd,
    sat_current.record_source,
    sat_current.load_date
from link
inner join sat_current
    on sat_current.transaction_hub_key = link.transaction_hub_key
left join customer_account
    on customer_account.account_hub_key = link.account_hub_key
