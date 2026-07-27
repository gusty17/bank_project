{{ config(materialized='incremental', incremental_strategy='append') }}

with src as (

    select * from {{ ref('bronze_cards') }}

),

hashed as (

    select
        {{ generate_hub_key(['card_id']) }} as card_hub_key,
        card_type,
        expiration_date,
        {{ dbt_utils.generate_surrogate_key([
            'card_type', 'expiration_date'
        ]) }} as hashdiff,
        _loaded_at     as load_date,
        record_source
    from src

)

select h.*
from hashed h
{% if is_incremental() %}
left join (
    select card_hub_key, hashdiff
    from (
        select
            card_hub_key,
            hashdiff,
            row_number() over (partition by card_hub_key order by load_date desc) as rn
        from {{ this }}
    ) ranked
    where rn = 1
) latest
  on h.card_hub_key = latest.card_hub_key
where latest.card_hub_key is null
   or h.hashdiff <> latest.hashdiff
{% endif %}
