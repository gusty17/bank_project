with source as (

    select * from {{ source('bank', 'cards') }}

)

select
    cast(card_id as varchar(20))        as card_id,
    cast(account_id as varchar(20))     as account_id,
    trim(card_type)                     as card_type,
    cast(expiration_date as date)       as expiration_date,
    'kaggle_csv'                        as record_source,
    current_timestamp                   as _loaded_at
from source
