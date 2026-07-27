with bronze as (

    select * from {{ ref('bronze_branches') }}

),

-- descriptive attributes are already text; no casting or trim applied
casted as (

    select
        branch_id,
        branch_name,
        city,
        country,
        manager_name,
        _loaded_at,
        record_source
    from bronze

),

-- add the hub key + a fingerprint (hashdiff) of the descriptive attributes
incoming as (

    select
        {{ generate_hub_key(['branch_id']) }} as branch_hub_key,
        branch_name,
        city,
        country,
        manager_name,
        {{ dbt_utils.generate_surrogate_key([
            'branch_name', 'city', 'country', 'manager_name'
        ]) }} as hashdiff,
        _loaded_at as load_date,
        record_source
    from casted

)

{% if is_incremental() %}
-- the latest stored version per branch (flat query, no nested subquery)
, current_version as (

    select distinct on (branch_hub_key)
        branch_hub_key,
        hashdiff
    from {{ this }}
    order by branch_hub_key, load_date desc

)
{% endif %}

select incoming.*
from incoming
{% if is_incremental() %}
left join current_version cv
    on cv.branch_hub_key = incoming.branch_hub_key
where cv.branch_hub_key is null              -- brand-new branch
   or incoming.hashdiff <> cv.hashdiff        -- attributes changed
{% endif %}
