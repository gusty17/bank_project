{{ config(materialized='incremental', incremental_strategy='append') }}

with src as (

    select * from {{ ref('bronze_accounts') }}

),

hashed as (

    select
        {{ generate_hub_key(['account_id']) }} as account_hub_key,
        account_type,
        balance_usd,
        open_date,
        {{ dbt_utils.generate_surrogate_key([
            'account_type', 'balance_usd', 'open_date'
        ]) }} as hashdiff,
        _loaded_at        as load_date,
        record_source
    from src

)

select h.*
from hashed h
{% if is_incremental() %}
left join (
    select account_hub_key, hashdiff
    from (
        select
            account_hub_key,
            hashdiff,
            row_number() over (partition by account_hub_key order by load_date desc) as rn
        from {{ this }}
    ) ranked
    where rn = 1
) latest
  on h.account_hub_key = latest.account_hub_key
where latest.account_hub_key is null
   or h.hashdiff <> latest.hashdiff
{% endif %}
