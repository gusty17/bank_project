{{ config(materialized='incremental', incremental_strategy='append') }}

with src as (

    select * from {{ ref('bronze_merchants') }}

),

hashed as (

    select
        {{ generate_hub_key(['merchant_id']) }} as merchant_hub_key,
        merchant_name,
        city,
        {{ dbt_utils.generate_surrogate_key([
            'merchant_name', 'city'
        ]) }} as hashdiff,
        _loaded_at         as load_date,
        record_source
    from src

)

select h.*
from hashed h
{% if is_incremental() %}
left join (
    select merchant_hub_key, hashdiff
    from (
        select
            merchant_hub_key,
            hashdiff,
            row_number() over (partition by merchant_hub_key order by load_date desc) as rn
        from {{ this }}
    ) ranked
    where rn = 1
) latest
  on h.merchant_hub_key = latest.merchant_hub_key
where latest.merchant_hub_key is null
   or h.hashdiff <> latest.hashdiff
{% endif %}
