{{ config(materialized='table') }}

with link as (
    select * from {{ ref('link_customer_loan') }}
),

-- current satellite version per loan
sat_current as (

    select distinct on (loan_hub_key)
        loan_hub_key,
        loan_amount,
        interest_rate,
        start_date,
        load_date,
        record_source
    from {{ ref('sat_loan_details') }}
    order by loan_hub_key, load_date desc

)

select
    link.loan_hub_key,
    link.customer_hub_key,
    cast(to_char(sat_current.start_date, 'YYYYMMDD') as integer) as date_key,
    sat_current.start_date,
    sat_current.loan_amount,
    sat_current.interest_rate,
    sat_current.record_source,
    sat_current.load_date
from link
inner join sat_current
    on sat_current.loan_hub_key = link.loan_hub_key
