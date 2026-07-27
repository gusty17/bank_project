{{ config(materialized='incremental', incremental_strategy='append') }}

with bronze as (

    select * from {{ ref('bronze_merchants') }}

),

-- descriptive attributes are already text; no casting or trim applied
casted as (

    select
        merchant_id,
        merchant_name,
        city,
        _loaded_at,
        record_source
    from bronze

),

-- add the hub key + a fingerprint (hashdiff) of the descriptive attributes
incoming as (

    select
        {{ generate_hub_key(['merchant_id']) }} as merchant_hub_key,
        merchant_name,
        city,
        {{ dbt_utils.generate_surrogate_key([
            'merchant_name', 'city'
        ]) }} as hashdiff,
        _loaded_at as load_date,
        record_source
    from casted

)

{% if is_incremental() %}
-- the latest stored version per merchant (flat query, no nested subquery)
, current_version as (

    select distinct on (merchant_hub_key)
        merchant_hub_key,
        hashdiff
    from {{ this }}
    order by merchant_hub_key, load_date desc

)
{% endif %}

select incoming.*
from incoming
{% if is_incremental() %}
left join current_version cv
    on cv.merchant_hub_key = incoming.merchant_hub_key
where cv.merchant_hub_key is null            -- brand-new merchant
   or incoming.hashdiff <> cv.hashdiff        -- attributes changed
{% endif %}
