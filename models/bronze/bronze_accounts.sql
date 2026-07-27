with source as (

    select * from {{ source('bank', 'accounts') }}

)

-- raw extract: columns passed through as-is (no casting, no trim, no renaming).
select
    account_id,
    customer_id,
    account_type,
    balance_usd,
    open_date,
    'kaggle_csv'      as record_source,
    current_timestamp as _loaded_at
from source
