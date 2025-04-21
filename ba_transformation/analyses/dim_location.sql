with review as (
    select * from {{ref("stg_airlinequality__reviews")}}
),

all_location as (
    select 
        coalesce(origin_city, 'Unknown') as city, 
        coalesce(origin_airport, 'Unknown') as airport
    from review

    union  

    select 
        coalesce(destination_city, 'Unknown') as city, 
        coalesce(destination_airport, 'Unknown') as airport 
    from review

    union 

    select 
        coalesce(transit_city, 'Unknown') as city, 
        coalesce(transit_airport, 'Unknown') as airport 
    from review
),
distinct_location as (
    select 
        distinct
        city, 
        airport
    from all_location
),

final as (
    select 
        row_number() over(order by city, airport) as location_id,
        city,
        airport
    from distinct_location
)
select * from final
