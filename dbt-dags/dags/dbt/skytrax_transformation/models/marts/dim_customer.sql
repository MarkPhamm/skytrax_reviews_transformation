with review as (
    select * from {{ref("stg__skytrax_reviews")}}
),

customer_agg as (
    select
        
        customer_name, 
        nationality,
        count(*) number_of_flights

    from review
    group by 1,2
),

-- assume customer_name, nationality uniquely indentify customers
final as (
    select
        row_number() over(order by customer_name, nationality) customer_id,
        *
    from customer_agg
)

select * from final