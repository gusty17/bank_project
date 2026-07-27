with src as (

    select * from {{ ref('bronze_merchants') }}

),

hashed as (

    select
        {{ generate_hub_key(['merchant_id']) }} as merchant_hub_key,
        cast(merchant_id as varchar(20)) as merchant_id,
        _loaded_at         as load_date,
        record_source,
        row_number() over (partition by merchant_id order by _loaded_at) as rn
    from src

)

select
    merchant_hub_key,
    merchant_id,
    load_date,
    record_source
from hashed
where rn = 1
{% if is_incremental() %}
  and merchant_hub_key not in (select merchant_hub_key from {{ this }})
{% endif %}
