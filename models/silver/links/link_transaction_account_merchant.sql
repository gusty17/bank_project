{{ config(materialized='incremental', incremental_strategy='append') }}

with src as (

    select * from {{ ref('bronze_transactions') }}

),

hashed as (

    select
        {{ generate_hub_key(['transaction_id', 'account_id', 'merchant_id']) }} as transaction_account_merchant_link_key,
        {{ generate_hub_key(['transaction_id']) }} as transaction_hub_key,
        {{ generate_hub_key(['account_id']) }}     as account_hub_key,
        {{ generate_hub_key(['merchant_id']) }}    as merchant_hub_key,
        _loaded_at            as load_date,
        record_source,
        row_number() over (partition by transaction_id, account_id, merchant_id order by _loaded_at) as rn
    from src

)

select
    transaction_account_merchant_link_key,
    transaction_hub_key,
    account_hub_key,
    merchant_hub_key,
    load_date,
    record_source
from hashed
where rn = 1
{% if is_incremental() %}
  and transaction_account_merchant_link_key not in (select transaction_account_merchant_link_key from {{ this }})
{% endif %}
