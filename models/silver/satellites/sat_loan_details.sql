with bronze as (

    select * from {{ ref('bronze_loans') }}

),

-- simple transformations: type casting (no trim)
casted as (

    select
        loan_id,
        cast(loan_amount as numeric(15, 2))  as loan_amount,
        cast(interest_rate as numeric(5, 2)) as interest_rate,
        cast(start_date as date)             as start_date,
        _loaded_at,
        record_source
    from bronze

),

-- add the hub key + a fingerprint (hashdiff) of the descriptive attributes
incoming as (

    select
        {{ generate_hub_key(['loan_id']) }} as loan_hub_key,
        loan_amount,
        interest_rate,
        start_date,
        {{ dbt_utils.generate_surrogate_key([
            'loan_amount', 'interest_rate', 'start_date'
        ]) }} as hashdiff,
        _loaded_at as load_date,
        record_source
    from casted

)

{% if is_incremental() %}
-- the latest stored version per loan (flat query, no nested subquery)
, current_version as (

    select distinct on (loan_hub_key)
        loan_hub_key,
        hashdiff
    from {{ this }}
    order by loan_hub_key, load_date desc

)
{% endif %}

select incoming.*
from incoming
{% if is_incremental() %}
left join current_version cv
    on cv.loan_hub_key = incoming.loan_hub_key
where cv.loan_hub_key is null                -- brand-new loan
   or incoming.hashdiff <> cv.hashdiff        -- attributes changed
{% endif %}
