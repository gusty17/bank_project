with source as (

    select * from {{ source('bank', 'branches') }}

)

-- raw extract: columns passed through as-is (no casting, no trim, no renaming).
select
    branch_id,
    branch_name,
    city,
    country,
    manager_name,
    'kaggle_csv'      as record_source,
    current_timestamp as _loaded_at
from source
