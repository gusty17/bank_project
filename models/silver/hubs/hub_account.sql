with src as (
    select * from {{ ref('bronze_accounts') }}
),

hashed as (
    select
        {{ generate_hub_key(['account_id']) }} as account_hub_key,
        cast(account_id as varchar(20)) as account_id,
        _loaded_at        as load_date,
        record_source,
        row_number() over (partition by account_id order by _loaded_at) as rn
    from src
)

select
    account_hub_key,
    account_id,
    load_date,
    record_source
from hashed
where rn = 1
{% if is_incremental() %}
  and account_hub_key not in (select account_hub_key from {{ this }})
{% endif %}
