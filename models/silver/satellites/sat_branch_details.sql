{{ config(materialized='incremental', incremental_strategy='append') }}

with src as (

    select * from {{ ref('bronze_branches') }}

),

hashed as (

    select
        {{ generate_hub_key(['branch_id']) }} as branch_hub_key,
        branch_name,
        city,
        country,
        manager_name,
        {{ dbt_utils.generate_surrogate_key([
            'branch_name', 'city', 'country', 'manager_name'
        ]) }} as hashdiff,
        _loaded_at        as load_date,
        record_source
    from src

)

select h.*
from hashed h
{% if is_incremental() %}
left join (
    select branch_hub_key, hashdiff
    from (
        select
            branch_hub_key,
            hashdiff,
            row_number() over (partition by branch_hub_key order by load_date desc) as rn
        from {{ this }}
    ) ranked
    where rn = 1
) latest
  on h.branch_hub_key = latest.branch_hub_key
where latest.branch_hub_key is null
   or h.hashdiff <> latest.hashdiff
{% endif %}
