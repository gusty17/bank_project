{{ config(materialized='table') }}

with sat as (

    select * from {{ ref('sat_account_details') }}

),

hub as (

    select * from {{ ref('hub_account') }}

),

customer_link as (

    select
        account_hub_key,
        customer_hub_key
    from {{ ref('link_customer_account') }}

),

versioned as (

    select
        sat.account_hub_key,
        hub.account_id,
        customer_link.customer_hub_key,
        sat.account_type,
        sat.open_date,
        sat.load_date                                                    as effective_start_date,
        coalesce(
            lead(sat.load_date) over (
                partition by sat.account_hub_key
                order by sat.load_date
            ),
            cast('9999-12-31' as timestamp)
        )                                                                as effective_end_date,
        lead(sat.load_date) over (
            partition by sat.account_hub_key
            order by sat.load_date
        ) is null                                                        as is_current,
        sat.record_source
    from sat
    inner join hub
        on hub.account_hub_key = sat.account_hub_key
    left join customer_link
        on customer_link.account_hub_key = sat.account_hub_key

)

select
    {{ generate_hub_key(['account_hub_key', 'effective_start_date']) }} as account_key,
    account_hub_key,
    account_id,
    customer_hub_key,
    account_type,
    open_date,
    effective_start_date,
    effective_end_date,
    is_current,
    record_source
from versioned
