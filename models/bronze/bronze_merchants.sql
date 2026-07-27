with source as (

    select * from {{ source('bank', 'merchants') }}

)

select
    cast(merchant_id as varchar(20))    as merchant_id,
    trim(merchant_name)                 as merchant_name,
    trim(city)                          as city,
    'kaggle_csv'                        as record_source,
    current_timestamp                   as _loaded_at
from source
