{{ config(materialized='incremental', incremental_strategy='append') }}

with src as (

    select * from {{ ref('bronze_cards') }}

),

hashed as (

    select
        {{ generate_hub_key(['card_id']) }} as card_hub_key,
        card_id,
        _loaded_at     as load_date,
        record_source,
        row_number() over (partition by card_id order by _loaded_at) as rn
    from src

)

select
    card_hub_key,
    card_id,
    load_date,
    record_source
from hashed
where rn = 1
{% if is_incremental() %}
  and card_hub_key not in (select card_hub_key from {{ this }})
{% endif %}
