with source as (

    select * from {{ source('bank', 'customers') }}

)

select
    cast(customer_id as varchar(20))    as customer_id,
    trim(first_name)                    as first_name,
    trim(last_name)                     as last_name,
    trim(email)                         as email,
    trim(city)                          as city,
    cast(credit_score as integer)       as credit_score,
    cast(created_at as date)            as created_date,   -- renamed: source is a DATE, not a timestamp
    'kaggle_csv'                        as record_source,
    current_timestamp                   as _loaded_at
from source
