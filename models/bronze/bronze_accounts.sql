with source as (

    select * from {{ source('bank', 'accounts') }}

)

select
    cast(account_id as varchar(20))     as account_id,
    cast(customer_id as varchar(20))    as customer_id,
    trim(account_type)                  as account_type,
    cast(balance_usd as numeric(15, 2)) as balance_usd,    -- pin precision on unbounded numeric
    cast(open_date as date)             as open_date,
    'kaggle_csv'                        as record_source,
    current_timestamp                   as _loaded_at
from source
