{{ config(materialized='incremental', incremental_strategy='append') }}

with bronze as (

    select * from {{ ref('bronze_transactions') }}

),

-- simple transformations: type casting (no trim)
casted as (

    select
        transaction_id,
        cast(amount_usd as numeric(15, 2))  as amount_usd,
        cast(transaction_date as timestamp) as transaction_date,
        _loaded_at,
        record_source
    from bronze

),

-- add the hub key + a fingerprint (hashdiff) of the descriptive attributes
incoming as (

    select
        {{ generate_hub_key(['transaction_id']) }} as transaction_hub_key,
        amount_usd,
        transaction_date,
        {{ dbt_utils.generate_surrogate_key([
            'amount_usd', 'transaction_date'
        ]) }} as hashdiff,
        _loaded_at as load_date,
        record_source
    from casted

)

{% if is_incremental() %}
-- the latest stored version per transaction (flat query, no nested subquery)
, current_version as (

    select distinct on (transaction_hub_key)
        transaction_hub_key,
        hashdiff
    from {{ this }}
    order by transaction_hub_key, load_date desc

)
{% endif %}

select incoming.*
from incoming
{% if is_incremental() %}
left join current_version cv
    on cv.transaction_hub_key = incoming.transaction_hub_key
where cv.transaction_hub_key is null         -- brand-new transaction
   or incoming.hashdiff <> cv.hashdiff        -- attributes changed
{% endif %}
