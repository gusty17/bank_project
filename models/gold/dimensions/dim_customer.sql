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

),

-- current-state account counts per customer (is_current avoids SCD2 fan-out)
account_counts as (

    select
        customer_hub_key,
        count(*)                                              as total_account_count,
        count(*) filter (where account_type = 'Checking')     as checking_account_count,
        count(*) filter (where account_type = 'Savings')      as savings_account_count
    from {{ ref('dim_account') }}
    where is_current
    group by customer_hub_key

),

loan_counts as (

    select
        customer_hub_key,
        count(*)           as total_loan_count,
        sum(loan_amount)   as total_loan_amount
    from {{ ref('fact_loans') }}
    group by customer_hub_key

)

select
    {{ generate_hub_key(['versioned.customer_hub_key', 'versioned.load_date']) }} as customer_key,
    versioned.customer_hub_key,
    versioned.customer_id,
    versioned.first_name,
    versioned.last_name,
    versioned.email,
    versioned.city,
    versioned.credit_score,
    versioned.credit_tier,
    versioned.created_date,
    versioned.acquisition_month,
    coalesce(account_counts.total_account_count, 0)      as total_account_count,
    coalesce(account_counts.checking_account_count, 0)   as checking_account_count,
    coalesce(account_counts.savings_account_count, 0)    as savings_account_count,
    coalesce(loan_counts.total_loan_count, 0)            as total_loan_count,
    coalesce(loan_counts.total_loan_amount, 0)             as total_loan_amount,
    versioned.effective_start_date,
    versioned.effective_end_date,
    versioned.is_current,
    versioned.record_source
from versioned
left join account_counts
    on account_counts.customer_hub_key = versioned.customer_hub_key
left join loan_counts
    on loan_counts.customer_hub_key = versioned.customer_hub_key
