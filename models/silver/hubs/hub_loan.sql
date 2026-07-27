{{ config(materialized='incremental', incremental_strategy='append') }}

with src as (

    select * from {{ ref('bronze_loans') }}

),

hashed as (

    select
        {{ generate_hub_key(['loan_id']) }} as loan_hub_key,
        cast(loan_id as varchar(20)) as loan_id,
        _loaded_at     as load_date,
        record_source,
        row_number() over (partition by loan_id order by _loaded_at) as rn
    from src

)

select
    loan_hub_key,
    loan_id,
    load_date,
    record_source
from hashed
where rn = 1
{% if is_incremental() %}
  and loan_hub_key not in (select loan_hub_key from {{ this }})
{% endif %}
