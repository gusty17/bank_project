{{ config(materialized='incremental', incremental_strategy='append') }}

with src as (

    select * from {{ ref('bronze_customers') }}

),

hashed as (

    select
        {{ generate_hub_key(['customer_id']) }} as customer_hub_key,
        customer_id,
        _loaded_at        as load_date,
        record_source,
        row_number() over (partition by customer_id order by _loaded_at) as rn
    from src

)

select
    customer_hub_key,
    customer_id,
    load_date,
    record_source
from hashed
where rn = 1
{% if is_incremental() %}
  and customer_hub_key not in (select customer_hub_key from {{ this }})
{% endif %}
