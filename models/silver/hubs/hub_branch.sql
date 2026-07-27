{{ config(materialized='incremental', incremental_strategy='append') }}

with src as (

    select * from {{ ref('bronze_branches') }}

),

hashed as (

    select
        {{ generate_hub_key(['branch_id']) }} as branch_hub_key,
        cast(branch_id as varchar(20)) as branch_id,
        _loaded_at        as load_date,
        record_source,
        row_number() over (partition by branch_id order by _loaded_at) as rn
    from src

)

select
    branch_hub_key,
    branch_id,
    load_date,
    record_source
from hashed
where rn = 1
{% if is_incremental() %}
  and branch_hub_key not in (select branch_hub_key from {{ this }})
{% endif %}
