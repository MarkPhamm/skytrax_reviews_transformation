select 

    row_number() over(order by date_submitted, customer_name) review_id,
    *

from {{ source('AIRLINEQUALITY', 'REVIEW') }}
