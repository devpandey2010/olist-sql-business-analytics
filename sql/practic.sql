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
select * ,CASE
    WHEN prev_revenue = 0 OR prev_revenue IS NULL THEN NULL
    ELSE ROUND((prev_revenue - current_revenue) * 100.0 / prev_revenue, 2)
END AS percentage_drop from previous_details
where percentage_drop>20.0 and prev_revenue is not null
order by percentage_drop desc;


