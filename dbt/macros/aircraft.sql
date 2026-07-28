{% macro extract_aircraft_manufacturer(column_name) %}
{#-
    Derive manufacturer from the leading token of an aircraft model string.
    e.g. "Boeing 737-800WINGLET" -> "Boeing", "unknown" -> "Unknown"
-#}
case
    when lower(split_part({{ column_name }}, ' ', 1)) = 'unknown' then 'Unknown'
    else split_part({{ column_name }}, ' ', 1)
end
{% endmacro %}


{% macro aircraft_family_seed() %}
{#-
    Canonical aircraft family lookup used for fuzzy capacity matching.
    Returns columns: model, manufacturer, capacity
-#}
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
    {'model': 'Unknown', 'manufacturer': 'Unknown', 'capacity': none},
] %}
select
    *,
from (
    values
    {% for aircraft in aircraft_data %}
        (
            '{{ aircraft.model }}',
            '{{ aircraft.manufacturer }}',
            {{ aircraft.capacity if aircraft.capacity is not none else 'null' }}
        ){{ "," if not loop.last }}
    {% endfor %}
) as t (model, manufacturer, capacity)
{% endmacro %}


{% macro fuzzy_match_aircraft_family(model_column, seed_model_column) %}
{#-
    True when review model text contains a seed family name (case-insensitive).
    Pair with QUALIFY ... order by length(seed_model) desc to prefer the longest hit.
-#}
contains(upper({{ model_column }}), upper({{ seed_model_column }}))
{% endmacro %}
