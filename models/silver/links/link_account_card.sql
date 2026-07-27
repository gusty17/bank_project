{{ config(materialized='incremental', incremental_strategy='append') }}

with src as (

    select * from {{ ref('bronze_cards') }}

),

hashed as (

    select
        {{ generate_hub_key(['account_id', 'card_id']) }} as account_card_link_key,
        {{ generate_hub_key(['account_id']) }}           as account_hub_key,
        {{ generate_hub_key(['card_id']) }}              as card_hub_key,
        _loaded_at     as load_date,
        record_source,
        row_number() over (partition by account_id, card_id order by _loaded_at) as rn
    from src

)

select
    account_card_link_key,
    account_hub_key,
    card_hub_key,
    load_date,
    record_source
from hashed
where rn = 1
{% if is_incremental() %}
  and account_card_link_key not in (select account_card_link_key from {{ this }})
{% endif %}
