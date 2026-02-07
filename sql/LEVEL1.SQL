--Q1.
select count(*) as total_orders from orders;

--If asked only completed orders
SELECT COUNT(*) AS total_completed_orders
FROM orders
WHERE  field3= 'delivered';

--Q2.How many unique customers have placed at least one order?
select count(distinct field2) as unique_customers from orders;

--Unique customers with delivered orders only:
SELECT COUNT(DISTINCT field2)
FROM orders
WHERE field3='delivered';

--Unique customers in a specific year:
SELECT COUNT(DISTINCT field2) as unique_customers
FROM orders
WHERE strftime('%Y', field4) = '2018';

--What is the total revenue generated from all completed orders?
select round(sum(op.payment_value),2) as total_payments from order_payments op
join orders o on op.order_id=o.order_id
where order_status='delivered';

--Revenue by month
select strftime('%Y-%m',order_purchase_timestamp) as MONTH,
round(sum(op.payment_value)) as revenue
from orders o
join order_payments op on o.order_id=op.order_id
where o.order_status='delivered'
group by MONTH
order by month;

--Revenue vs installments

SELECT 
    payment_installments,
    SUM(payment_value) AS revenue
FROM order_payments
GROUP BY payment_installments
ORDER BY revenue desc;

-- AOV actually higher?
SELECT
    payment_installments,
    AVG(payment_value) AS avg_order_value
FROM order_payments
GROUP BY payment_installments
order by avg_order_value desc;

--Monthly AOV (Delivered orders only)
select strftime('%Y-%m',o.order_purchase_timestamp) as month,
sum(p.payment_value)*1.0/count(distinct o.order_id) as AOV
from orders o
join order_payments p on o.order_id=p.order_id
where o.order_status='delivered'
group by MONTH
order by AOV desc;

--5 How many orders were placed each month? Show year-month and order count.
select count(o.order_id) as number_of_orders,
strftime('%Y-%m',o.order_purchase_timestamp) as month from orders o
group by strftime('%Y-%m',o.order_purchase_timestamp)
order by month;

-- By using Lead and lag we can find which month no of orders are decreased or increased from previous
with order_details AS(
    select strftime('%Y-%m',o.order_purchase_timestamp) as month,
    count(o.order_id) as total_orders
    from orders o
    group by month
    order by month
    
)
select 
*,
lag(total_orders)over(order by month) as previous_month_orders,
total_orders-lag(total_orders)over(order by month) as change_in_order,
case 
when total_orders-lag(total_orders)over(order by month)>0 then "Increased"
when total_orders-lag(total_orders)over(order by month)<0 then "Decreased"
else "same"
end as trend
from order_details;

--Which top 10 cities have the highest number of customers?
select c.customer_city,count(distinct c.customer_id) as number_of_customers
from customers c
group by c.customer_city
order by number_of_customers desc
LIMIT 10;

--------

with customer_detail AS(
    select 
  c.customer_city,count(distinct c.customer_id) as number_of_customers
from customers c
group by c.customer_city
),
ranked AS(
    SELECT *,
        ROW_NUMBER() OVER (ORDER BY number_of_customers DESC) AS rn
    FROM customer_detail
)
select * from ranked 
where rn<=10;

--Which cities generate highest revenue but have low customer count?

WITH revenue_details AS (
    SELECT
        c.customer_city,
        COUNT(DISTINCT c.customer_id) AS number_of_customers,
        SUM(op.payment_value) AS total_revenue
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    JOIN order_payments op ON o.order_id = op.order_id
    GROUP BY c.customer_city
),
ranked AS (
    SELECT *,
        RANK() OVER (ORDER BY total_revenue DESC) AS revenue_rank,
        RANK() OVER (ORDER BY number_of_customers ASC) AS customer_rank
    FROM revenue_details
)

SELECT *
FROM ranked
WHERE revenue_rank <= 10
AND customer_rank <= 10;

--Top cities contributing to 80% revenue
WITH revenue_details AS (
    SELECT
        c.customer_city,
        SUM(op.payment_value) AS total_revenue
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    JOIN order_payments op ON o.order_id = op.order_id
    GROUP BY c.customer_city
),
-- if you will not write over then it will loose the city-level-detail
grand_revenue AS(
    select *,
    sum(total_revenue) over()as grand_total_revenue
    from revenue_details  
),
percent_co AS(
    select *,
    total_revenue*100/grand_total_revenue as percent_contribution 
    from grand_revenue
),
cummulative AS(
    select *,
    sum(percent_contribution)over(order by total_revenue desc) as cummulative_sum
    from percent_co
)
select * from cummulative
where cummulative_sum<=80;


--How many sellers are registered on the platform?
select count(seller_id) as total_registered from sellers;
--Active sellers
select count(distinct s.seller_id) as total_active_sellers from sellers s
join order_items ot on s.seller_id=ot.seller_id;


SELECT COUNT(DISTINCT s.seller_id) AS active_sellers
FROM sellers s
JOIN order_items oi ON s.seller_id = oi.seller_id
JOIN orders o ON oi.order_id = o.order_id
WHERE o.order_purchase_timestamp >= (
    SELECT
    date(MAX(order_purchase_timestamp),'-6 months')
    from orders
);

-----Very IMportant Question(For Details Refer to notes)

---Sellers selling consistently every month
--We need to:
--Step 1

--Convert orders → Month level
--Step 2

--Find total months in dataset

---Step 3

--Count months each seller sold

--Step 4

--Match sellers where seller_active_months = total_dataset_months

with seller_monthly_sales AS(
    select oi.seller_id,
    strftime('%Y-%m',o.order_purchase_timestamp) as sale_month
    from order_items oi
    join orders o on oi.order_id=o.order_id
    group by oi.seller_id,sale_month
),
total_months AS (
    SELECT COUNT(DISTINCT strftime('%Y-%m', order_purchase_timestamp)) AS total_m
    FROM orders
),
seller_active_months AS (
    SELECT 
        seller_id,
        COUNT(DISTINCT sale_month) AS active_months
    FROM seller_monthly_sales
    GROUP BY seller_id
)
SELECT COUNT(*) AS consistent_sellers
FROM seller_active_months sam
JOIN total_months tm
ON sam.active_months = tm.total_m;


---sellers churn over the past six month from the latest date
with latest_date as(
    select max(order_purchase_timestamp) as max_date
    from orders
),
current_sellers AS(
    select distinct oi.seller_id
    from order_items oi
    join orders o on oi.order_id=o.order_id
    where strftime('%y-%m',o.order_purchase_timestamp)=(select strftime('%Y-%m',max_date)from latest_date)

),
past_sellers AS(
    select distinct oi.seller_id
    from order_items oi join orders o on oi.order_id=o.order_id
    where o.order_purchase_timestamp>=(select date(max_date,'-6 months')from latest_date)
    AND strftime('%Y-%m', o.order_purchase_timestamp) <
          (SELECT strftime('%Y-%m', max_date) FROM latest_date)
)
SELECT 
    COUNT(DISTINCT p.seller_id) AS churned_sellers
FROM past_sellers p
LEFT JOIN current_sellers c
ON p.seller_id = c.seller_id
WHERE c.seller_id IS NULL;


