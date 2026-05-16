with revenue_details AS(
    select p.product_category_name,s.seller_id,sum(oi.price) as total_seller_revenue
    from order_items oi join products p on oi.product_id=p.product_id
    join sellers s on oi.seller_id=s.seller_id
    group by s.seller_id,p.product_category_name
),
Ranked AS(
    select *,
    Rank()over(partition by product_category_name order by total_seller_revenue desc) as rn
    from revenue_details
)
select * from ranked 
where rn<=3;

--Assign a unique row number to each order per customer, ordered by order_purchase_timestamp.

WITH order_details AS (
    SELECT 
        c.customer_unique_id,
        o.order_id,
        o.order_purchase_timestamp
    FROM orders o
    JOIN customers c ON o.customer_id = c.customer_id
),
ranked AS (
    SELECT *,
        ROW_NUMBER() OVER (
            PARTITION BY customer_unique_id
            ORDER BY order_purchase_timestamp
        ) AS order_sequence_number
    FROM order_details
)
SELECT * FROM ranked;

--Rank customers by total spending within each city using DENSE_RANK. Show only rank <= 5
with customer_details AS(
    select c.customer_city,c.customer_unique_id,sum(op.payment_value) as total_customer_payment
    from customers c join orders o on c.customer_id=o.customer_id join order_payments op 
    on o.order_id=op.order_id
    group by customer_unique_id,customer_city
),
Ranked as(
    select *,
    DENSE_RANK()over(partition by customer_city order by total_customer_payment desc) as rn  
    from customer_details
)
select * from ranked where rn<=5;

/*Find customers who placed their 2nd order on the platform. Use ROW_NUMBER to sequence
orders per customer, then filter where sequence = 2.*/
with customer_details as
(
select c.customer_unique_id,o.order_id,o.order_purchase_timestamp
from customers c join orders o on c.customer_id=o.customer_id
),
Ranked as(
    select *,
   ROW_NUMBER()over(partition by customer_unique_id order by order_purchase_timestamp) as rn  
   from customer_details
)
select * from ranked where rn=2;

/*For each seller, rank their products by total quantity sold (desc). Show only the top-ranked product
per seller (rank = 1)*/
--seller_id, product_id, total_qty_sold, product_rank
/* we will use rank over rownumber because there is a possibility two product can have same rank and suppose
if two product have rank 1 then we need to return both that product since we are asked for top ranked product
not one one top product explicitly*/
with product_details as(
    select seller_id,product_id,count(*) as total_qty_sold
    from order_items 
    group by product_id,seller_id
),
ranked as(
    select *,
    Rank()over(partition by seller_id order by total_qty_sold desc) as rn    
    from product_details
)
select * from ranked where rn=1;

/*Find all categories where more than one seller shares rank 1 by revenue (a tie at the top). Use
RANK, not DENSE_RANK.*/
--RETURN category_name, seller_id, total_revenue

with seller_details AS(
    select product_category_name,seller_id,sum(oi.price) as total_revenue
    from order_items oi join products p on oi.product_id=p.product_id
    group by seller_id,product_category_name
),
Ranked AS(
    select *,
    Rank()over(partition by product_category_name order by total_revenue desc) as rn   
    from seller_details
),
-- Step 3: find categories where more than one seller holds rank 1
tied_categories AS (
    SELECT product_category_name
    FROM ranked
    WHERE rn = 1
    GROUP BY product_category_name
    HAVING COUNT(*) > 1  --  more than one seller at rank 1
)
-- Final: return all rank-1 sellers from those tied categories
SELECT 
    r.product_category_name,
    r.seller_id,
    r.total_revenue
FROM ranked r
JOIN tied_categories tc 
    ON r.product_category_name = tc.product_category_name
WHERE r.rn = 1
ORDER BY r.product_category_name, r.total_revenue DESC;


/*For each month, rank the top 3 customers by number of orders placed. Exclude months where a
customer placed 0 orders.*/
/* month, customer_unique_id, order_count, monthly_rank*/
 with customer_details AS(
    select strftime('%Y-%m',o.order_purchase_timestamp) as year_month,
    c.customer_unique_id,count(*)as order_count FROM
    customers c join orders o on c.customer_id=o.customer_id
    group by customer_unique_id,year_month
 ),
 ranked AS(
    select *,
    rank()over(partition by year_month order by order_count desc)as rn   
    from customer_details
 )
 select * from ranked where rn<=3
 order by year_month,rn;

/*Using ROW_NUMBER, find customers who placed exactly 1 order on the platform. Do NOT use
COUNT — window functions only.*/

with customer_details AS(
    select c.customer_unique_id,o.order_id,o.order_purchase_timestamp
    from customers c join orders o on c.customer_id=o.customer_id

),
Ranked AS(
    select*,ROW_NUMBER()over(partition by customer_unique_id order by order_purchase_timestamp) as rn   
    from customer_details
),
Filters AS(
    select customer_unique_id,
    max(rn)as total_orders
    from ranked
    group by customer_unique_id
)
select r.customer_unique_id,
r.order_id from ranked r join 
Filters f on r.customer_unique_id=f.customer_unique_id
where f.total_orders=1;  --exactly 1 order        --get that one order row

/*Rank sellers by avg review score (desc). For same avg score, use total orders as tiebreaker
(desc). Use DENSE_RANK.*/
--seller_id, avg_review, total_orders, rank
with seller_details AS(
    select oi.seller_id,avg(orr.review_score)as avg_review_score,
    count(Distinct oi.order_id)as total_orders from order_items oi join order_reviews orr on oi.order_id=orr.order_id
    group by seller_id
),
ranked AS(
    select *,
    Dense_Rank()over (order by avg_review_score desc, total_orders desc)as rn FROM
    seller_details
)
select * from ranked;

/*For each customer, find their single most expensive order. If two orders tie for max amount, return
-- both. Add a comment explaining why ROW_NUMBER would be wrong here.*/

--customer_unique_id, order_id, order_value, rank_within_customer

/* There will be no granularity issue since one row one customer one order and from we have to find highest paid order*/
with customer_details AS(
    select c.customer_unique_id,
    o.order_id,sum(op.payment_value)
    from customers c join orders o on c.customer_id=o.customer_id
    join order_payments op on o.order_id=op.order_id
    group by c.customer_unique_id,o.order_id
),
Ranked AS(
    select *,
    Rank()over(partition by customer_unique_id order by payment_value desc)as rn    
    from customer_details
)
select * from ranked 
where rn=1;

/* Row number cannot be used because row number assign unique value even
both value are same but in this we are asked to return two values if their is tie at the top*/

--PRACTICE DAY 2 --LAG/LEAD/PERCENTILE FUNCTION

/*For each month, calculate the total revenue and the revenue from the previous month. Show the
absolute change and whether revenue 'Increased', 'Decreased', or 'Same' compared to previous
month. First month should show NULL for previous revenue.*/
--Return  month, total_revenue, prev_month_revenue, change
with revenue_details as(
    select strftime('%Y-%m',o.order_purchase_timestamp) as year_month,
    round(sum(op.payment_value),2) as total_revenue from orders o join order_payments op
    on o.order_id=op.order_id
    group by year_month
    order by year_month
),
Previous_details as(
    select *,
    coalesce(Lag(total_revenue,1)over(order by year_month),0) as prev_month_revenue,
    round(coalesce(total_revenue-Lag(total_revenue,1)over(order by year_month),0),2) as diff_in_revenue,
    case
    when coalesce(Lag(total_revenue,1)over(order by year_month),0)=0 THEN "No Previous Data"
        when total_revenue-Lag(total_revenue,1)over(order by year_month) >0 then "Increased"
        when total_revenue-Lag(total_revenue,1)over(order by year_month) <0 then "Decreased"   
        else  "same"
        end as revenue_health
    from revenue_details
)
select * from previous_details;

/*For each customer, find the number of days between their consecutive orders. Return the customer,
both order dates, and days gap. Exclude the first order of each customer (no previous order to
compare). Order by customer and order date.
RETURN customer_unique_id, order_date, prev_order_date, days_between_order*/

 select c.customer_unique_id,
    strftime("%Y-%m",o.order_purchase_timestamp) as order_date
    from customers c join orders o on c.customer_id=o.customer_id
    group by customer_unique_id;
    
with customer_details AS(
    select c.customer_unique_id,
    strftime("%Y-%m-%d",o.order_purchase_timestamp) as order_date
    from customers c join orders o on c.customer_id=o.customer_id

),
previous_order AS(
    select *,Lag(order_date,1)over(partition by customer_unique_id order by order_date) as previous_order_date,
    Julianday(order_date)-Julianday(Lag(order_date,1)over(partition by customer_unique_id order by order_date))as days_between_orders
    from customer_details

)
select * from previous_order
where days_between_orders is not null;


/*Find all months where revenue dropped by more than 20% compared to the previous month. Return
the month, current revenue, previous revenue, and the percentage drop. Order by drop percentage
descending.
RETURN month, revenue, prev_revenue, pct_drop*/
with revenue_details AS(
    select strftime('%Y-%m',o.order_purchase_timestamp) as current_month,
    round(sum(op.payment_value),2) as current_revenue
    from orders o join order_payments op on o.order_id=op.order_id
    group by current_month
),
previous_details as(
    select *,
    Lag(current_revenue)over(order by current_month) as prev_revenue
    from revenue_details
)
select * ,
CASE
    WHEN prev_revenue = 0 OR prev_revenue IS NULL THEN NULL
    ELSE ROUND((prev_revenue - current_revenue) * 100.0 / prev_revenue, 2)  --Whenever we are dividing something we have to think of zero
END AS percentage_drop from previous_details
where percentage_drop>20.0 and prev_revenue is not null
order by percentage_drop desc;

/*For each order of each customer, show the next order's purchase date and the number of days until
their next order. If no next order exists, show NULL. This helps identify customers likely to churn.*/

--RETURN customer_unique_id, order_id, order_date, next_order_date, days_to_next_order
with customer_details AS(
    select c.customer_unique_id,o.order_id,
    Date(o.order_purchase_timestamp) as order_date from customers c   
    join orders o on c.customer_id=o.customer_id
),
Future_orders as (
    select *,
    Lead(order_date,1)over(partition by customer_unique_id order by order_date)as next_order_date
    from customer_details
),
Gap_between_orders as(
    select *,
    julianday(next_order_date)-julianday(order_date) as days_to_next_order
    from future_orders
)
select * from Gap_between_orders;

/*For each seller, find months where they had NO sales in the following month (i.e. LEAD revenue is
NULL or 0). These are sellers who stopped selling. Return seller_id, their last active month, and total
revenue in that month.*/
--RETURN seller_id, last_active_month, revenue_in_last_month

with seller_details AS(
    select oi.seller_id,strftime('%Y-%m',o.order_purchase_timestamp) as active_month,
    round(sum(oi.price),2)as revenue_last_month from order_items oi
    join orders o on o.order_id=oi.order_id
    group by strftime('%Y-%m',o.order_purchase_timestamp),seller_id
),
Future_details AS(
    select *,
    Lead(revenue_last_month,1)over(partition by seller_id order by active_month) as following_revenue,
    Lead(revenue_last_month,2)over(partition by seller_id order by active_month) as Next_to_next_month
    from seller_details
)
select * from future_details
where(following_revenue is null or following_revenue=0)
and next_to_next_month is not null;

/*For each month and product category, show the current revenue and next month's revenue. Classify
each row as 'Growth Expected', 'Decline Expected', or 'End of Data' based on the next month's value.
Order by category and month.*/
--RETURN category, month, current_revenue, next_month_revenue, forecast_label
with details as(
    select coalesce(p.product_category_name,"Uncategorized") as product_category_name,strftime('%Y-%m',o.order_purchase_timestamp) as current_month,
    round(sum(oi.price),2) as current_revenue from orders o join order_items oi on
    o.order_id=oi.order_id join products p on oi.product_id=p.product_id
    group by current_month,p.product_category_name
),
Future_details AS(
    select *,
    lead(current_revenue)over(partition by product_category_name order by current_month) as next_month_revenue
    from details
),
classify as(
    select *,
    CASE
    when next_month_revenue>current_revenue then "Growth expected"
    when next_month_revenue<current_revenue then "decline Expected"
    when next_month_revenue=current_revenue then "Same Sale"
    ELSE
    "End of Data"  -- to handle null
    end as Clasiify_report
    from future_details
)
select * from classify
order by product_category_name,current_month;

--"How would you show only categories that have at least 3 consecutive months of growth?"
/*Approach 1 — The Classic Gaps & Islands Pattern
The idea: assign a group number to consecutive growth months. 
Rows in the same group = consecutive streak*/

WITH details AS (
    SELECT 
        p.product_category_name AS category,
        strftime('%Y-%m', o.order_purchase_timestamp) AS month,
        ROUND(SUM(oi.price), 2) AS revenue
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    JOIN products p ON oi.product_id = p.product_id
    WHERE p.product_category_name IS NOT NULL
    GROUP BY category, month
),
with_growth AS (
    SELECT *,
        LAG(revenue) OVER (PARTITION BY category ORDER BY month) AS prev_revenue,
        -- is this month a growth month? 1 = yes, 0 = no
        CASE
            WHEN revenue > LAG(revenue) OVER (
                PARTITION BY category ORDER BY month) 
            THEN 1 ELSE 0
        END AS is_growth
    FROM details
),
with_group AS (
    SELECT *,
        -- ROW_NUMBER globally - ROW_NUMBER only on growth rows
        -- = same number for consecutive growth rows (the island trick)
        ROW_NUMBER() OVER (PARTITION BY category ORDER BY month)
        -
        ROW_NUMBER() OVER (PARTITION BY category, is_growth ORDER BY month)
        AS streak_group
    FROM with_growth
    WHERE is_growth = 1  -- only growth months
)
SELECT 
*,
    category,
    MIN(month) AS streak_start,
    MAX(month) AS streak_end,
    COUNT(*) AS consecutive_growth_months
FROM with_group
GROUP BY category, streak_group
HAVING COUNT(*) >= 3
ORDER BY consecutive_growth_months DESC;

/*Find all customers who have logged in (placed an order) for at least 3 consecutive months.
 Return the customer, the streak start month, streak end month, and the length of the streak.
A consecutive month streak means months like 2017-01, 2017-02, 2017-03 with no gap in between.
Return: customer_unique_id, streak_start, streak_end, streak_length.*/

/*For each product category, show each seller's total revenue AND the revenue of the top seller in that
category. Calculate what percentage of the top seller's revenue each seller achieves. Order by
category and percentage descending.
RETURN category, seller_id, seller_revenue, top_seller_revenue, pct_of_top*/

with seller_details AS(
    select coalesce(p.product_category_name,"Uncategorized") as product_category_name,oi.seller_id,
    sum(oi.price) as seller_revenue 
    from order_items oi join products p on 
    p.product_id=oi.product_id
    group by oi.seller_id,p.product_category_name 
),
Details AS(
    select *,
    First_value(seller_revenue)over(partition by product_category_name order by seller_revenue desc)as top_seller_revenue
    from seller_details 
    
)
select *,round(seller_revenue*100.0/top_seller_revenue,2) as pct_of_top from details
where top_seller_revenue is not null
order by product_category_name,pct_of_top desc;

WITH customer_details AS (
    SELECT
        c.customer_unique_id,
        o.order_id,
        DATE(o.order_purchase_timestamp) AS order_date,
        -- handle multiple payment rows per order
        MIN(op.payment_type) AS payment_type
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    JOIN order_payments op ON o.order_id = op.order_id
    GROUP BY c.customer_unique_id, o.order_id, o.order_purchase_timestamp
),
with_first AS (
    SELECT *,
        -- first payment type per customer by date
        FIRST_VALUE(payment_type) OVER (
            PARTITION BY customer_unique_id
            ORDER BY order_date
        ) AS first_payment_type
    FROM customer_details
)
-- NOW filter in outer query where window result is available
SELECT
    customer_unique_id,
    order_id,
    order_date,
    payment_type,
    first_payment_type
FROM with_first
WHERE payment_type != first_payment_type  -- DIFFERENT from first 
ORDER BY customer_unique_id, order_date;
/*For each seller, calculate the cumulative revenue by month. Then for each month, show how much the
cumulative revenue has grown compared to the seller's very first month's revenue. Show absolute
growth and percentage growth from their first month.*/
--RETURN seller_id, month, monthly_revenue, cumulative_revenue, first_month_revenue, pct_growth_from_start

with seller_details AS(
    select oi.seller_id,strftime('%Y-%m',o.order_purchase_timestamp) as month,
    round(sum(oi.price),2)as monthly_revenue from order_items oi join orders o on oi.order_id=o.order_id
    group by month,oi.seller_id
),
cummulative_details as(
    select *,
    sum(monthly_revenue)over(partition by seller_id order by month)as cummulative_sum
    from seller_details

),
comparison as(
    select *,
    first_value(monthly_revenue)over(partition by seller_id order by month) as first_month_revenue
    from cummulative_details
)
select *,
(cummulative_sum-first_month_revenue) as absolute_growth,
    (cummulative_sum-first_month_revenue)*100.0/first_month_revenue  as pct_growth from comparison
    where first_month_revenue is not null;

/*For each customer, show every order they placed along with the payment value of their MOST
RECENT order. This helps identify if customers are spending more or less over time compared to their
latest order. Remember the frame clause trap.*/
--RETURN customer_unique_id, order_id, order_date, order_payment, most_recent_payment

with customer_details as(
    select c.customer_unique_id,o.order_id,strftime('%Y-%m',o.order_purchase_timestamp) as order_date,
    op.payment_value from customers c join orders o on c.customer_id=o.customer_Id join order_payments op 
    on op.order_id=o.order_id 
),
Details as(
    select *,
    Last_value(payment_value)over(partition by customer_unique_id order by order_date rows between unbounded preceding and unbounded following)as most_recent_payment
    from customer_details
)
select * from details
order by customer_unique_id,order_date;
------
/*For each product category, find the first month it had any sales and the last month it had any sales. For
each month of sales, show both. Then find categories where the last month's revenue is LOWER than
the first month's revenue (declining categories).*/
--RETURN category, month, revenue, first_month_revenue, last_month_revenue, is_declining
with product_details as(
    select coalesce(p.product_category_name,"Uncategorized") as product_category_name,strftime('%Y-%m',o.order_purchase_timestamp) as order_date,
    sum(oi.price) as revenue from orders o join order_items oi on 
    o.order_id=oi.order_id join products p on oi.product_id=p.product_id
    group by p.product_category_name,order_date
),
Details AS(
    select *,
    First_value(revenue)over(partition by product_category_name order by order_date) as first_month_revenue,
    Last_value(revenue)over(partition by product_category_name order by order_date Rows between Unbounded preceding and Unbounded following) as Last_month_revenue
    from product_details

)
select * from details
where (first_month_revenue>last_month_revenue)
and first_month_revenue is not null and last_month_revenue is not null;

/*For each product category, find the 2nd highest revenue seller and the 3rd highest revenue seller. If a
category has fewer than 3 sellers, show NULL for 3rd place. Show all three positions in a single row
per category.*/
--RETURN category, top1_seller_revenue, top2_seller_revenue, top3_seller_revenue

/* whenever you want something 2nd higest third highest you can go with nthvalue*/
/* also we can use nested query*/

with product_details AS(
    select coalesce(p.product_category_name,"Uncategorised") as product_category_name,seller_id,
    sum(oi.price) as revenue from order_items oi 
    join products p on oi.product_id=p.product_id
    group by p.product_category_name,seller_id
),
details AS(
    select *,
    first_value(revenue)over(partition by product_category_name order by revenue desc) as top1_seller_revenue,
    nth_value(revenue,2)over(partition by product_category_name order by revenue desc rows between unbounded preceding and unbounded following) as top2_seller_revenue,
     nth_value(revenue,3)over(partition by product_category_name order by revenue desc rows between unbounded preceding and unbounded following) as top3_seller_revenue
    from product_details
)
select distinct product_category_name,top1_seller_revenue,top2_seller_revenue,top3_seller_revenue from details
order by product_category_name;


/*Segment all customers into 4 quartiles based on their total spending (highest spenders in quartile 1).
Label each quartile as 'Platinum', 'Gold', 'Silver', 'Bronze'. Return customer_unique_id, total_spent,
quartile_number, and tier_label.*/

with customer_details
as(
    select c.customer_unique_id,
    round(sum(op.payment_value),2) as total_spent
    from customers c join orders o on c.customer_id=o.customer_id
    join order_payments op on o.order_id=op.order_id
    group by c.customer_unique_id 
),
Details as(
    select *,
    NTILE(4)over(order by total_spent desc) as Quartile 
    from customer_details
)
select *,
case
 WHEN Quartile=1 then "Platinum"
 when Quartile=2 then "Gold"
 when Quartile=3 then "Silver"
 else "Bronze"
 end as tier_label
 from details;

----Very Good Question

/*For each product category, divide sellers into 10 deciles based on their total revenue (highest revenue
= decile 1). Find all sellers who are in decile 1 (top 10%) in AT LEAST 2 different categories. 
Return seller_id and count of categories where they are top decile.*/
--RETURN seller_id, top_decile_category_count

with product_details AS(
    select p.product_category_name,oi.seller_id,
    round(sum(oi.price),2) as total_revenue 
    from order_items oi join products p on 
    oi.product_id=p.product_id
    group by oi.seller_id,p.product_category_name
),
Details AS(
    select *,
    ntile(10)over(Partition by product_category_name order by total_revenue desc) as Quartile
    from product_details
),
Further as(
    select seller_id,count(product_category_name) as top_decile_category_count
    from details
    where quartile=1
    group by seller_id
    having count(product_category_name)>=2
)
select * from further
order by top_decile_category_count desc;

/*Step 1 → Aggregate revenue per seller per category
Step 2 → NTILE(10) per category to find deciles
Step 3 → Filter decile=1, then count categories per seller
          HAVING count >= 2*/


WITH product_details AS (
    SELECT
        p.product_category_name,
        oi.seller_id,
        ROUND(SUM(oi.price), 2) AS total_revenue
    FROM order_items oi
    JOIN products p ON oi.product_id = p.product_id
    GROUP BY oi.seller_id, p.product_category_name
),
with_decile AS (
    SELECT *,
        NTILE(10) OVER (
            PARTITION BY product_category_name
            ORDER BY total_revenue DESC  -- highest = decile 1
        ) AS decile
    FROM product_details
),
top_decile_sellers AS (
    SELECT
        seller_id,
        COUNT(DISTINCT product_category_name) AS top_decile_category_count
    FROM with_decile
    WHERE decile = 1          -- row level filter BEFORE grouping
    GROUP BY seller_id        -- group by seller not category
    HAVING COUNT(DISTINCT product_category_name) >= 2  -- at least 2 categories
)
SELECT * FROM top_decile_sellers
ORDER BY top_decile_category_count DESC;

/*For each seller, calculate their percentile rank among ALL sellers based on total revenue. Show what
percentage of sellers earn less than them. Return seller_id, total_revenue, percent_rank, and a label:
'Top 10%', 'Top 25%', 'Top 50%', or 'Bottom 50%'*/
--RETURN seller_id, total_revenue, percent_rank, performance_label

with seller_details AS(
    select oi.seller_id,round(sum(oi.price),2) as total_revenue
    from order_items oi
    group by oi.seller_id
),
Ranked as(
    select *,
    (1-percent_Rank()over(order by total_revenue desc))*100.0 as percent_rank
    from seller_details
)
select *,
case 
WHEN percent_rank>=90 then "Top 10%"
when percent_rank>=75  then "Top 25%"
when percent_rank>=50 then "Top 50%"
else "Bottom 50%"
end as performance_labe
from ranked;

/*For each product category, find sellers whose revenue percent rank is in the TOP 20% within their
category (percent_rank >= 0.8 when ordered ASC). But ALSO show their GLOBAL percent rank
among all sellers. Return category, seller_id, revenue, category_percent_rank, global_percent_rank.*/

--RETURN category, seller_id, revenue, category_pct_rank, global_pct_rank

with seller_details AS(
    select coalesce(p.product_category_name,"Uncategorised") as product_category_name,
    oi.seller_id,round(sum(oi.price),2) as total_revenue
    from order_items oi join products p ON
    oi.product_id=p.product_id
    group by oi.seller_id,p.product_category_name
),
Ranked as(
    select*,
    percent_rank()over(partition by product_category_name order by total_revenue) as category_pct_rank,
    percent_rank()over(order by total_revenue) as global_percent_rank
    from seller_details
)
select * from Ranked
where category_pct_rank>=0.8;

/*"A seller has category_pct_rank=0.95 but global_pct_rank=0.4. What does this tell you?"

They're a top performer in their category but average globally. 
This category might be less competitive — fewer sellers, lower revenue bar. 
Useful insight for business strategy.


