with source as (

    select * from {{ source('bank', 'loans') }}

)

select
    cast(loan_id as varchar(20))        as loan_id,
    cast(customer_id as varchar(20))    as customer_id,
    cast(loan_amount as numeric(15, 2)) as loan_amount,    -- pin precision on unbounded numeric
    cast(interest_rate as numeric(5, 2)) as interest_rate, -- pin precision on unbounded numeric
    cast(start_date as date)            as start_date,
    'kaggle_csv'                        as record_source,
    current_timestamp                   as _loaded_at
from source
