{{ config(materialized='table') }}

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
        sat.created_date,
        sat.load_dateas as effective_start_date,
        coalesce(
            lead(sat.load_date) over (
                partition by sat.customer_hub_key
                order by sat.load_date
            ),
            cast('9999-12-31' as timestamp)
        ) as effective_end_date,
        lead(sat.load_date) over (
            partition by sat.customer_hub_key
            order by sat.load_date
        ) is null as is_current,
        sat.record_source
    from sat
    inner join hub
        on hub.customer_hub_key = sat.customer_hub_key
)

select
    {{ generate_hub_key(['customer_hub_key', 'effective_start_date']) }} as customer_key,
    customer_hub_key,
    customer_id,
    first_name,
    last_name,
    email,
    city,
    credit_score,
    created_date,
    effective_start_date,
    effective_end_date,
    is_current,
    record_source
from versioned
