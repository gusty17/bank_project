with source as (

    select * from {{ source('bank', 'loans') }}

)

-- raw extract: columns passed through as-is (no casting, no trim, no renaming).
select
    loan_id,
    customer_id,
    loan_amount,
    interest_rate,
    start_date,
    'kaggle_csv'      as record_source,
    current_timestamp as _loaded_at
from source
