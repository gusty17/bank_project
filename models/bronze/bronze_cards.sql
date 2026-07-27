with source as (

    select * from {{ source('bank', 'cards') }}

)

-- raw extract: columns passed through as-is (no casting, no trim, no renaming).
select
    card_id,
    account_id,
    card_type,
    expiration_date,
    'kaggle_csv'      as record_source,
    current_timestamp as _loaded_at
from source
