with sat as (

    select * from {{ ref('sat_branch_details') }}

),

hub as (

    select * from {{ ref('hub_branch') }}

),

versioned as (

    select
        sat.branch_hub_key,
        hub.branch_id,
        sat.branch_name,
        sat.city,
        sat.country,
        sat.manager_name,
        sat.load_date                                                    as effective_start_date,
        coalesce(
            lead(sat.load_date) over (
                partition by sat.branch_hub_key
                order by sat.load_date, sat.branch_hub_key
            ),
            cast('9999-12-31' as timestamp)
        )                                                                as effective_end_date,
        lead(sat.load_date) over (
            partition by sat.branch_hub_key
            order by sat.load_date, sat.branch_hub_key
        ) is null                                                        as is_current,
        sat.record_source,
        sat.load_date
    from sat
    inner join hub
        on hub.branch_hub_key = sat.branch_hub_key

)

select
    {{ generate_hub_key(['branch_hub_key', 'load_date']) }} as branch_key,
    branch_hub_key,
    branch_id,
    branch_name,
    city,
    country,
    manager_name,
    effective_start_date,
    effective_end_date,
    is_current,
    record_source
from versioned
