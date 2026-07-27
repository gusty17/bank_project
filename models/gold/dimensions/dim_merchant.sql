with sat as (

    select * from {{ ref('sat_merchant_details') }}

),

hub as (

    select * from {{ ref('hub_merchant') }}

),

versioned as (

    select
        sat.merchant_hub_key,
        hub.merchant_id,
        sat.merchant_name,
        sat.city,
        sat.load_date                                                    as effective_start_date,
        coalesce(
            lead(sat.load_date) over (
                partition by sat.merchant_hub_key
                order by sat.load_date, sat.merchant_hub_key
            ),
            cast('9999-12-31' as timestamp)
        )                                                                as effective_end_date,
        lead(sat.load_date) over (
            partition by sat.merchant_hub_key
            order by sat.load_date, sat.merchant_hub_key
        ) is null                                                        as is_current,
        sat.record_source,
        sat.load_date
    from sat
    inner join hub
        on hub.merchant_hub_key = sat.merchant_hub_key

)

select
    {{ generate_hub_key(['merchant_hub_key', 'load_date']) }} as merchant_key,
    merchant_hub_key,
    merchant_id,
    merchant_name,
    city,
    effective_start_date,
    effective_end_date,
    is_current,
    record_source
from versioned
