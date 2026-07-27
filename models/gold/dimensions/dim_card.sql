with sat as (

    select * from {{ ref('sat_card_details') }}

),

hub as (

    select * from {{ ref('hub_card') }}

),

account_link as (

    select
        card_hub_key,
        account_hub_key
    from {{ ref('link_account_card') }}

),

versioned as (

    select
        sat.card_hub_key,
        hub.card_id,
        account_link.account_hub_key,
        sat.card_type,
        sat.expiration_date,
        sat.load_date                                                    as effective_start_date,
        coalesce(
            lead(sat.load_date) over (
                partition by sat.card_hub_key
                order by sat.load_date, sat.card_hub_key
            ),
            cast('9999-12-31' as timestamp)
        )                                                                as effective_end_date,
        lead(sat.load_date) over (
            partition by sat.card_hub_key
            order by sat.load_date, sat.card_hub_key
        ) is null                                                        as is_current,
        sat.record_source,
        sat.load_date
    from sat
    inner join hub
        on hub.card_hub_key = sat.card_hub_key
    left join account_link
        on account_link.card_hub_key = sat.card_hub_key

)

select
    {{ generate_hub_key(['card_hub_key', 'load_date']) }} as card_key,
    card_hub_key,
    card_id,
    account_hub_key,
    card_type,
    expiration_date,
    effective_start_date,
    effective_end_date,
    is_current,
    record_source
from versioned
