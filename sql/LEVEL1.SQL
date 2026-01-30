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