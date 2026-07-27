with sat as (

    select * from {{ ref('sat_customer_details') }}

),

hub as (

    select * from {{ ref('hub_customer') }}

),

versioned as (

    select
        sat.customer_hub_key,
        hub.customer_id,
        sat.first_name,
        sat.last_name,
        sat.email,
        sat.city,
        sat.credit_score,
        case
            when sat.credit_score >= 750 then 'excellent'
            when sat.credit_score >= 700 then 'good'
            when sat.credit_score >= 650 then 'fair'
            when sat.credit_score >= 600 then 'poor'
            else 'very_poor'
        end                                                              as credit_tier,
        sat.created_date,
        date_trunc('month', sat.created_date)::date                      as acquisition_month,
        sat.load_date                                                    as effective_start_date,
        coalesce(
            lead(sat.load_date) over (
                partition by sat.customer_hub_key
                order by sat.load_date, sat.customer_hub_key
            ),
            cast('9999-12-31' as timestamp)
        )                                                                as effective_end_date,
        lead(sat.load_date) over (
            partition by sat.customer_hub_key
            order by sat.load_date, sat.customer_hub_key
        ) is null                                                        as is_current,
        sat.record_source,
        sat.load_date
    from sat
    inner join hub
        on hub.customer_hub_key = sat.customer_hub_key

)

select
    {{ generate_hub_key(['customer_hub_key', 'load_date']) }} as customer_key,
    customer_hub_key,
    customer_id,
    first_name,
    last_name,
    email,
    city,
    credit_score,
    credit_tier,
    created_date,
    acquisition_month,
    effective_start_date,
    effective_end_date,
    is_current,
    record_source
from versioned
