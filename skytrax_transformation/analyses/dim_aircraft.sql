-- models/dim_aircraft.sql

{% set aircraft_data = [
    {'model': 'A318', 'manufacturer': 'Airbus', 'capacity': 132},
    {'model': 'A319', 'manufacturer': 'Airbus', 'capacity': 134},
    {'model': 'A320', 'manufacturer': 'Airbus', 'capacity': 180},
    {'model': 'A321', 'manufacturer': 'Airbus', 'capacity': 220},
    {'model': 'A322', 'manufacturer': 'Airbus', 'capacity': 244},
    {'model': 'A329', 'manufacturer': 'Airbus', 'capacity': 160},
    {'model': 'A330', 'manufacturer': 'Airbus', 'capacity': 277},
    {'model': 'A340', 'manufacturer': 'Airbus', 'capacity': 295},
    {'model': 'A350', 'manufacturer': 'Airbus', 'capacity': 300},
    {'model': 'A380', 'manufacturer': 'Airbus', 'capacity': 555},
    {'model': 'Boeing 737', 'manufacturer': 'Boeing', 'capacity': 189},
    {'model': 'Boeing 744', 'manufacturer': 'Boeing', 'capacity': 416},
    {'model': 'Boeing 747', 'manufacturer': 'Boeing', 'capacity': 467},
    {'model': 'Boeing 757', 'manufacturer': 'Boeing', 'capacity': 200},
    {'model': 'Boeing 767', 'manufacturer': 'Boeing', 'capacity': 216},
    {'model': 'Boeing 777', 'manufacturer': 'Boeing', 'capacity': 396},
    {'model': 'Boeing 787', 'manufacturer': 'Boeing', 'capacity': 242},
    {'model': 'Boeing 789', 'manufacturer': 'Boeing', 'capacity': 296},
    {'model': 'Embraer 170', 'manufacturer': 'Embraer', 'capacity': 76},
    {'model': 'Embraer 190', 'manufacturer': 'Embraer', 'capacity': 98},
    {'model': 'Embraer 195', 'manufacturer': 'Embraer', 'capacity': 120},
    {'model': 'Saab 2000', 'manufacturer': 'Saab', 'capacity': 50},
    {'model': 'Unknown', 'manufacturer': 'Unknown', 'capacity': none}
] %}

with review as (
    select * from {{ ref("stg__skytrax_reviews") }}
),

raw_aircraft as (
    select distinct coalesce(aircraft, 'Unknown') as aircraft_model
    from review
),

final as (
    select
        row_number() over (order by aircraft_model) as aircraft_id,
        aircraft_model,
        mapped.manufacturer as aircraft_manufacturer,
        mapped.capacity as seat_capacity
    from raw_aircraft
    left join (
        select *
        from (values
            {% for aircraft in aircraft_data -%}
                ('{{ aircraft.model }}', '{{ aircraft.manufacturer }}', {{ aircraft.capacity if aircraft.capacity is not none else 'null' }}){% if not loop.last %},{% endif %}
            {% endfor %}
        ) as t(model, manufacturer, capacity)
    ) as mapped
    on raw_aircraft.aircraft_model = mapped.model
)

select * from final
