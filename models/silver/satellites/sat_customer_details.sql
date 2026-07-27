{{ config(materialized='incremental', incremental_strategy='append') }}

with src as (

    select * from {{ ref('bronze_customers') }}

),

hashed as (

    select
        {{ generate_hub_key(['customer_id']) }} as customer_hub_key,
        first_name,
        last_name,
        email,
        city,
        credit_score,
        created_date,
        {{ dbt_utils.generate_surrogate_key([
            'first_name', 'last_name', 'email', 'city', 'credit_score', 'created_date'
        ]) }} as hashdiff,
        _loaded_at        as load_date,
        record_source
    from src

)

select h.*
from hashed h
{% if is_incremental() %}
left join (
    select customer_hub_key, hashdiff
    from (
        select
            customer_hub_key,
            hashdiff,
            row_number() over (partition by customer_hub_key order by load_date desc) as rn
        from {{ this }}
    ) ranked
    where rn = 1
) latest
  on h.customer_hub_key = latest.customer_hub_key
where latest.customer_hub_key is null
   or h.hashdiff <> latest.hashdiff
{% endif %}
