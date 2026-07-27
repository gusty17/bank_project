{{ config(materialized='incremental', incremental_strategy='append') }}

with bronze as (

    select * from {{ ref('bronze_customers') }}

),

-- simple transformations: type casting + rename (no trim)
casted as (

    select
        customer_id,
        first_name,
        last_name,
        email,
        city,
        cast(credit_score as integer) as credit_score,
        cast(created_at as date)      as created_date,
        _loaded_at,
        record_source
    from bronze

),

-- add the hub key + a fingerprint (hashdiff) of the descriptive attributes
incoming as (

    select
        {{ generate_hub_key(['customer_id']) }} as customer_hub_key,
        first_name,
        last_name,
        email,
        city,
        credit_score,
        created_date,
        {{ dbt_utils.generate_surrogate_key([
            'first_name', 'last_name', 'email', 'city', 'credit_score', 'created_date'
        ]) }} as hashdiff,
        _loaded_at as load_date,
        record_source
    from casted

)

{% if is_incremental() %}
-- the latest stored version per customer (flat query, no nested subquery)
, current_version as (

    select distinct on (customer_hub_key)
        customer_hub_key,
        hashdiff
    from {{ this }}
    order by customer_hub_key, load_date desc

)
{% endif %}

select incoming.*
from incoming
{% if is_incremental() %}
left join current_version cv
    on cv.customer_hub_key = incoming.customer_hub_key
where cv.customer_hub_key is null            -- brand-new customer
   or incoming.hashdiff <> cv.hashdiff        -- attributes changed
{% endif %}
