{% macro generate_dates_dimension(start_date) %}

/*
 - Assuming start of fiscal year as at 1st of July.
 - Automatically calculate the date that is 10,000 days after the start date. 
 - Filter the end date as 12 month after today. 
 */


WITH dates AS (
  SELECT 
    DATEADD(day, SEQ4(), '{{ start_date }}'::DATE) AS date
  FROM 
    TABLE(GENERATOR(ROWCOUNT => 5000))
),
dates_fin AS( -- add fiscal dates
SELECT 
  date AS DATE_ID,
  EXTRACT(DAYOFWEEK FROM date) as Day_Of_Week,
  TO_CHAR(date,'DY') as Day_Of_Week_Name,
  DATE_TRUNC('WEEK', date) AS Cal_Week_Start_Date, --Monday Start
  EXTRACT(DAY FROM date) AS Day_Of_Month,
  EXTRACT(MONTH FROM date) AS Cal_Month,
  TO_CHAR(date,'MMMM') AS Cal_Mon_Name,
  TO_CHAR(date,'MON') AS Cal_Mon_Name_Short,
  EXTRACT(quarter FROM date) AS Cal_Quarter,
  CONCAT('Q',EXTRACT(quarter FROM date)) AS Cal_Quarter_Name,
  EXTRACT(year FROM date) AS Cal_Year,
  CASE EXTRACT(DAYOFWEEK FROM date)
    WHEN 6 THEN TRUE
    WHEN 7 THEN TRUE
    ELSE FALSE
  END AS Is_Weekend,
  CASE 
    WHEN EXTRACT(MONTH FROM date) < 7 THEN EXTRACT(YEAR FROM date)
    ELSE EXTRACT(YEAR FROM date) + 1
    END AS Fin_Year,
  CASE 
    WHEN EXTRACT(MONTH FROM date) < 7 THEN EXTRACT(MONTH FROM date) + 6
    ELSE EXTRACT(MONTH FROM date) - 6
    END AS Fin_Period,
  CASE 
    WHEN EXTRACT(MONTH FROM date) < 7 THEN EXTRACT(quarter FROM date) + 2
    ELSE EXTRACT(quarter FROM date) - 2
    END AS Fin_Quarter,
  CASE
    WHEN date < date_trunc('year', date) + interval '6 months' 
    THEN EXTRACT(WEEK FROM (date - interval '6 months'))::integer
    ELSE EXTRACT(WEEK FROM (date + interval '6 months'))::integer
    END AS Fin_Week

FROM 
  dates
WHERE
  date <= DATEADD(MONTH, 12, CURRENT_DATE()) -- including 12 months in the future for forecasting purpose
)
SELECT *,
CONCAT('p',Fin_Period) AS Fin_Period_Name,
CONCAT('FQ',Fin_Quarter) AS Fin_Quarter_Name,
CONCAT('wk',Fin_Week) AS Fin_Week_Name
FROM dates_fin

{% endmacro %}