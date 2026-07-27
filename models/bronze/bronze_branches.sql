with source as (

    select * from {{ source('bank', 'branches') }}

)

select
    cast(branch_id as varchar(20))      as branch_id,
    trim(branch_name)                   as branch_name,
    trim(city)                          as city,
    trim(country)                       as country,
    trim(manager_name)                  as manager_name,
    'kaggle_csv'                        as record_source,
    current_timestamp                   as _loaded_at

from source
