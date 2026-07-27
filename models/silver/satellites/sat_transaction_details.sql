{{ config(materialized='incremental', incremental_strategy='append') }}

with src as (

    select * from {{ ref('bronze_transactions') }}

),

hashed as (

    select
        {{ generate_hub_key(['transaction_id']) }} as transaction_hub_key,
        amount_usd,
        transaction_date,
        {{ dbt_utils.generate_surrogate_key([
            'amount_usd', 'transaction_date'
        ]) }} as hashdiff,
        _loaded_at            as load_date,
        record_source
    from src

)

select h.*
from hashed h
{% if is_incremental() %}
left join (
    select transaction_hub_key, hashdiff
    from (
        select
            transaction_hub_key,
            hashdiff,
            row_number() over (partition by transaction_hub_key order by load_date desc) as rn
        from {{ this }}
    ) ranked
    where rn = 1
) latest
  on h.transaction_hub_key = latest.transaction_hub_key
where latest.transaction_hub_key is null
   or h.hashdiff <> latest.hashdiff
{% endif %}
