with source as (

    select * from {{ source('bank', 'customers') }}

)

-- raw extract: columns passed through as-is (no casting, no trim, no renaming).
select
    customer_id,
    first_name,
    last_name,
    email,
    city,
    credit_score,
    created_at,
    'kaggle_csv'      as record_source,
    current_timestamp as _loaded_at
from source
