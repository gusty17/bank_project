with source as (

    select * from {{ source('bank', 'merchants') }}

)

-- raw extract: columns passed through as-is (no casting, no trim, no renaming).
select
    merchant_id,
    merchant_name,
    city,
    'kaggle_csv'      as record_source,
    current_timestamp as _loaded_at
from source
