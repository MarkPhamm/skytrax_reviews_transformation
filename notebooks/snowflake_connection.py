from snowflake import connector
import pathlib
from dotenv import dotenv_values
import pandas as pd
from sqlalchemy import create_engine

# Load config
script_path = pathlib.Path(__file__).parent.parent.resolve()
config = dotenv_values(f"{script_path}/configuration.env")

# Create the connection URL with proper formatting
connection_url = (
    f"snowflake://{config.get('snowflake_user')}:"
    f"{config.get('snowflake_password')}@"
    f"{config.get('snowflake_account')}/"
    f"warehouse={config.get('snowflake_warehouse')}&"
    f"role={config.get('snowflake_role')}"
)
engine = create_engine(connection_url)

# Load data with pandas
query = """
/* =============================================================
   COMPLETE, FLATTENED VIEW FOR DASHBOARD CONSUMPTION
   ============================================================= */

SELECT
    /* ───────────── FACT COLUMNS ───────────── */
    f.review_id,
    
    /* ───────────── CUSTOMER DIM ───────────── */
    c.customer_name,
    c.nationality,
    c.number_of_flights,

    /* ───────────── REVIEW-DATE DIM (all columns) ───────────── */
    f.date_submitted_id,
    -- ds.day_of_week            AS review_day_of_week,
    -- ds.day_of_week_name       AS review_day_of_week_name,
    -- ds.cal_week_start_date    AS review_cal_week_start_date,
    -- ds.day_of_month           AS review_day_of_month,
    -- ds.cal_month              AS review_cal_month,
    -- ds.cal_mon_name           AS review_cal_mon_name,
    -- ds.cal_mon_name_short     AS review_cal_mon_name_short,
    -- ds.cal_quarter            AS review_cal_quarter,
    -- ds.cal_quarter_name       AS review_cal_quarter_name,
    -- ds.cal_year               AS review_cal_year,
    -- ds.is_weekend             AS review_is_weekend,
    -- ds.fin_year               AS review_fin_year,
    -- ds.fin_period             AS review_fin_period,
    -- ds.fin_quarter            AS review_fin_quarter,
    -- ds.fin_week               AS review_fin_week,
    -- ds.fin_period_name        AS review_fin_period_name,
    -- ds.fin_quarter_name       AS review_fin_quarter_name,
    -- ds.fin_week_name          AS review_fin_week_name,

    /* ───────────── FLIGHT-DATE DIM (all columns) ───────────── */
    f.date_flown_id,
    -- df.day_of_week            AS flight_day_of_week,
    -- df.day_of_week_name       AS flight_day_of_week_name,
    -- df.cal_week_start_date    AS flight_cal_week_start_date,
    -- df.day_of_month           AS flight_day_of_month,
    -- df.cal_month              AS flight_cal_month,
    -- df.cal_mon_name           AS flight_cal_mon_name,
    -- df.cal_mon_name_short     AS flight_cal_mon_name_short,
    -- df.cal_quarter            AS flight_cal_quarter,
    -- df.cal_quarter_name       AS flight_cal_quarter_name,
    -- df.cal_year               AS flight_cal_year,
    -- df.is_weekend             AS flight_is_weekend,
    -- df.fin_year               AS flight_fin_year,
    -- df.fin_period             AS flight_fin_period,
    -- df.fin_quarter            AS flight_fin_quarter,
    -- df.fin_week               AS flight_fin_week,
    -- df.fin_period_name        AS flight_fin_period_name,
    -- df.fin_quarter_name       AS flight_fin_quarter_name,
    -- df.fin_week_name          AS flight_fin_week_name,

    /* ───────────── ORIGIN LOCATION DIM ───────────── */
    f.origin_location_id,
    ol.city                   AS origin_city,
    ol.airport                AS origin_airport,

    /* ───────────── DESTINATION LOCATION DIM ───────────── */
    f.destination_location_id,
    dl.city                   AS destination_city,
    dl.airport                AS destination_airport,

    /* ───────────── TRANSIT LOCATION DIM ───────────── */
    f.transit_location_id,
    tl.city                   AS transit_city,
    tl.airport                AS transit_airport,


    /* ───────────── AIRCRAFT DIM ───────────── */
    f.aircraft_id,
    a.aircraft_model,
    a.aircraft_manufacturer,
    a.seat_capacity,

    /* ───────────── REVIEW CONTEXT ───────────── */
    f.verified,
    f.seat_type,
    f.type_of_traveller,

    /* ───────────── METRICS ───────────── */
    f.seat_comfort,
    f.cabin_staff_service,
    f.food_and_beverages,
    f.inflight_entertainment,
    f.ground_service,
    f.wifi_and_connectivity,
    f.value_for_money,
    f.average_rating,
    f.rating_band,
    f.recommended,

    /* ───────────── REVIEW_TEXT ───────────── */
    f.review_text,

    /* ───────────── TIMESTAMPS ───────────── */
    f.el_updated_at,
    f.t_updated_at

FROM british_airways_db.marts.fct_review_enriched  AS f

/* ----- date dimensions ----- */
LEFT JOIN british_airways_db.marts.dim_date     AS ds
       ON f.date_submitted_id = ds.date_id

LEFT JOIN british_airways_db.marts.dim_date     AS df
       ON f.date_flown_id     = df.date_id

/* ----- customer dimension ----- */
LEFT JOIN british_airways_db.marts.dim_customer AS c
       ON f.customer_id = c.customer_id

/* ----- location dimensions (three roles) ----- */
LEFT JOIN british_airways_db.marts.dim_location AS ol
       ON f.origin_location_id = ol.location_id

LEFT JOIN british_airways_db.marts.dim_location AS dl
       ON f.destination_location_id = dl.location_id

LEFT JOIN british_airways_db.marts.dim_location AS tl
       ON f.transit_location_id = tl.location_id

/* ----- aircraft dimension ----- */
LEFT JOIN british_airways_db.marts.dim_aircraft AS a
       ON f.aircraft_id = a.aircraft_id

/* optional filter */
WHERE f.date_submitted_id IS NOT NULL
ORDER BY 1 DESC
"""
df = pd.read_sql(query, engine)

df.head()
