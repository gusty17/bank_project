with source as (

    select * from {{ source('bank', 'transactions') }}

)

select
    cast(transaction_id as varchar(50)) as transaction_id,
    cast(account_id as varchar(50))     as account_id,
    cast(merchant_id as varchar(50))    as merchant_id,
    cast(amount_usd as numeric(15, 2))  as amount_usd,      -- pin precision on unbounded numeric
    cast(transaction_date as timestamp) as transaction_date, -- source is a timestamp (has time component)
    'kaggle_csv'                        as record_source,
    current_timestamp                   as _loaded_at
from source
