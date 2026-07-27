with date_spine as (

    {{ dbt_utils.date_spine(
        datepart="day",
        start_date="cast('2015-01-01' as date)",
        end_date="cast('2030-01-01' as date)"
    ) }}

)

select
    cast(to_char(date_day, 'YYYYMMDD') as integer) as date_key,
    date_day,
    extract(year from date_day)::integer           as year,
    extract(quarter from date_day)::integer        as quarter,
    extract(month from date_day)::integer          as month,
    to_char(date_day, 'Month')                     as month_name,
    extract(day from date_day)::integer            as day_of_month,
    extract(isodow from date_day)::integer         as day_of_week,
    to_char(date_day, 'Day')                       as day_name,
    extract(isodow from date_day) in (6, 7)        as is_weekend,
    extract(week from date_day)::integer           as week_of_year,
    extract(doy from date_day)::integer            as day_of_year,
    date_day = (date_trunc('month', date_day) + interval '1 month - 1 day')::date
                                                   as is_month_end
from date_spine
