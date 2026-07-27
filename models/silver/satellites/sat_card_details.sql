{{ config(materialized='incremental', incremental_strategy='append') }}

with bronze as (

    select * from {{ ref('bronze_cards') }}

),

-- simple transformations: type casting (no trim)
casted as (

    select
        card_id,
        card_type,
        cast(expiration_date as date) as expiration_date,
        _loaded_at,
        record_source
    from bronze

),

-- add the hub key + a fingerprint (hashdiff) of the descriptive attributes
incoming as (

    select
        {{ generate_hub_key(['card_id']) }} as card_hub_key,
        card_type,
        expiration_date,
        {{ dbt_utils.generate_surrogate_key([
            'card_type', 'expiration_date'
        ]) }} as hashdiff,
        _loaded_at as load_date,
        record_source
    from casted

)

{% if is_incremental() %}
-- the latest stored version per card (flat query, no nested subquery)
, current_version as (

    select distinct on (card_hub_key)
        card_hub_key,
        hashdiff
    from {{ this }}
    order by card_hub_key, load_date desc

)
{% endif %}

select incoming.*
from incoming
{% if is_incremental() %}
left join current_version cv
    on cv.card_hub_key = incoming.card_hub_key
where cv.card_hub_key is null                -- brand-new card
   or incoming.hashdiff <> cv.hashdiff        -- attributes changed
{% endif %}
