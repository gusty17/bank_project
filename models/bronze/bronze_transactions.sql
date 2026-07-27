with source as (

    select * from {{ source('bank', 'transactions') }}

)

-- raw extract: columns passed through as-is (no casting, no trim, no renaming).
select
    transaction_id,
    account_id,
    merchant_id,
    amount_usd,
    transaction_date,
    'kaggle_csv'      as record_source,
    current_timestamp as _loaded_at
from source
