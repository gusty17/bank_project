with src as (

    select * from {{ ref('bronze_accounts') }}

),

hashed as (

    select
        {{ generate_hub_key(['customer_id', 'account_id']) }} as customer_account_link_key,
        {{ generate_hub_key(['customer_id']) }}              as customer_hub_key,
        {{ generate_hub_key(['account_id']) }}               as account_hub_key,
        _loaded_at        as load_date,
        record_source,
        row_number() over (partition by customer_id, account_id order by _loaded_at) as rn
    from src

)

select
    customer_account_link_key,
    customer_hub_key,
    account_hub_key,
    load_date,
    record_source
from hashed
where rn = 1
{% if is_incremental() %}
  and customer_account_link_key not in (select customer_account_link_key from {{ this }})
{% endif %}
