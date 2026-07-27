{{ config(materialized='incremental', incremental_strategy='append') }}

with src as (

    select * from {{ ref('bronze_loans') }}

),

hashed as (

    select
        {{ generate_hub_key(['customer_id', 'loan_id']) }} as customer_loan_link_key,
        {{ generate_hub_key(['customer_id']) }}           as customer_hub_key,
        {{ generate_hub_key(['loan_id']) }}               as loan_hub_key,
        _loaded_at     as load_date,
        record_source,
        row_number() over (partition by customer_id, loan_id order by _loaded_at) as rn
    from src

)

select
    customer_loan_link_key,
    customer_hub_key,
    loan_hub_key,
    load_date,
    record_source
from hashed
where rn = 1
{% if is_incremental() %}
  and customer_loan_link_key not in (select customer_loan_link_key from {{ this }})
{% endif %}
