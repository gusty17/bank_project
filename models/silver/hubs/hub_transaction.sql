{{ config(materialized='incremental', incremental_strategy='append') }}

with src as (

    select * from {{ ref('bronze_transactions') }}

),

hashed as (

    select
        {{ generate_hub_key(['transaction_id']) }} as transaction_hub_key,
        transaction_id,
        _loaded_at            as load_date,
        record_source,
        row_number() over (partition by transaction_id order by _loaded_at) as rn
    from src

)

select
    transaction_hub_key,
    transaction_id,
    load_date,
    record_source
from hashed
where rn = 1
{% if is_incremental() %}
  and transaction_hub_key not in (select transaction_hub_key from {{ this }})
{% endif %}
