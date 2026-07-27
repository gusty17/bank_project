{{ config(materialized='incremental', incremental_strategy='append') }}

with src as (

    select * from {{ ref('bronze_loans') }}

),

hashed as (

    select
        {{ generate_hub_key(['loan_id']) }} as loan_hub_key,
        loan_amount,
        interest_rate,
        start_date,
        {{ dbt_utils.generate_surrogate_key([
            'loan_amount', 'interest_rate', 'start_date'
        ]) }} as hashdiff,
        _loaded_at     as load_date,
        record_source
    from src

)

select h.*
from hashed h
{% if is_incremental() %}
left join (
    select loan_hub_key, hashdiff
    from (
        select
            loan_hub_key,
            hashdiff,
            row_number() over (partition by loan_hub_key order by load_date desc) as rn
        from {{ this }}
    ) ranked
    where rn = 1
) latest
  on h.loan_hub_key = latest.loan_hub_key
where latest.loan_hub_key is null
   or h.hashdiff <> latest.hashdiff
{% endif %}
