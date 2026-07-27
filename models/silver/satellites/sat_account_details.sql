{{ config(materialized='incremental', incremental_strategy='append') }}

with bronze as (
    select * from {{ ref('bronze_accounts') }}
),
-- simple transformations: type casting (no trim)
casted as (

    select
        account_id,
        account_type,
        cast(balance_usd as numeric(15, 2)) as balance_usd,
        cast(open_date as date)             as open_date,
        _loaded_at,
        record_source
    from bronze
),
-- add the hub key + a fingerprint (hashdiff) of the descriptive attributes
incoming as (
    select
        {{ generate_hub_key(['account_id']) }} as account_hub_key,
        account_type,
        balance_usd,
        open_date,
        {{ dbt_utils.generate_surrogate_key([
            'account_type', 'balance_usd', 'open_date'
        ]) }} as hashdiff,
        _loaded_at as load_date,
        record_source
    from casted
)
{% if is_incremental() %}
-- the latest stored version per account (flat query, no nested subquery)
, current_version as (

    select distinct on (account_hub_key)
        account_hub_key,
        hashdiff
    from {{ this }}
    order by account_hub_key, load_date desc

)
{% endif %}

select incoming.*
from incoming
{% if is_incremental() %}
left join current_version cv
    on cv.account_hub_key = incoming.account_hub_key
where cv.account_hub_key is null             -- brand-new account
   or incoming.hashdiff <> cv.hashdiff        -- attributes changed
{% endif %}
