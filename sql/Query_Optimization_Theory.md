**Q1.What is query optimization and why is it important for a data analyst role specifically?**

/*Query Optimization is the art of writing queries in such a way that it takes less time for execution,
reduce wastage of memory and reduce cost.
In a analyst we have realtime dasboard running which showing important information to business
if query take time to get executed then it will be reflected with delay in the dashboard which
can cause loss to business.
Also in Cloud warehouse company is being billed for every data scanned.So if we use include unnessary DATA
it can impact loss to the business.
Analysts present insights to managers, product teams, business heads.
If a query takes 3 minutes every time someone refreshes a report —
stakeholders lose trust in the analytics team and start questioning
the team's technical competence
Data grows every day. A query that takes 5 seconds on 1M rows
takes 500 seconds on 100M rows if not optimized.
Optimization done early protects you from future scaling pain.*/

**Q2.What is the difference between UNION and UNION ALL? When would you prefer one over the other?**

/* Union basically sort the data first then do deduplication means removes duplicates
so,For a large data it will take time to sort the large data and remove the duplicates

While Union ALL dont do sort data and deduplication just combine all.

When you want intentionally to remove duplicates then you should go with union
but if not needed then you should go with union all.The reason would be that it would take less time
for execution and impact business postively.

Real example of UNION ALL:
 Combining orders_2023 + orders_2024 (no overlap possible)

Real example of UNION:
 Getting unique emails from customers + vendors table
  (same person can appear in both)

UNION and UNION ALL both treat NULL = NULL as duplicate.
So two NULL rows → UNION keeps one, UNION ALL keeps both.
This is the ONLY place in SQL where NULL = NULL is TRUE.*/

**Q3.Explain the difference between WHERE and HAVING. Can you use aggregate functions in WHERE? Why or why not?**

Where And Having both are filtering functions but the key difference between them is
if you want to filter rows on the basis of non aggregated then we should always prefer 
where. But if we want to filter rows on the basis of aggregated column then we have to use having

We should always use where(if not aggregated column) as early as possible like
we can do first filter and store it in CTE table then after filer we can do join
this is the way to make the query optimised as this will make less rows to join or doing the work

we cannot use where in aggregate function because where filters on row basis but aggregated 
function actually groups a row on a certain condition so we have to filter on that group so we use having 
and where is used before group by.

WHERE  → filters ROWS   → runs BEFORE GROUP BY → no aggregates allowed
HAVING → filters GROUPS → runs AFTER  GROUP BY → aggregates allowed
-- WHERE filters individual rows first
-- HAVING filters groups after aggregation

SELECT customer_id, SUM(amount) AS total
FROM orders
WHERE order_status = 'delivered'    -- ← row level filter BEFORE grouping
GROUP BY customer_id
HAVING SUM(amount) > 1000;          -- ← group level filter AFTER grouping

-- Why can't we put SUM(amount) > 1000 in WHERE?
-- Because at WHERE execution time, rows haven't been grouped yet
-- SUM(amount) doesn't exist as a value — it's computed AFTER GROUP BY*/

--Can you use HAVING without GROUP BY?
Yes — in MySQL, HAVING without GROUP BY treats the entire
table as one group.


**Q4.What is a correlated subquery? Why is it generally bad for performance and how would you rewrite it?**

Definition:
A correlated subquery references a column from the outer query.
Because of this reference it cannot run once and reuse the result —
it must re-execute for every single row of the outer query.

Why it is slow:
10M rows in outer query = subquery runs 10M times.
Each execution is a separate database operation.
On large datasets this causes severe performance degradation.

How to fix:
1. Window functions — when subquery computes a per-group aggregate
   AVG() OVER(PARTITION BY department) instead of subquery per row

2. CTE + JOIN — when subquery filters rows based on aggregated condition
   Aggregate in CTE once, JOIN back to main table

Key difference from regular subquery:
Regular subquery → no outer reference → runs ONCE → fast
Correlated subquery → references outer row → runs N times → slow

-- Regular subquery — NO reference to outer query
-- Runs ONCE, result is reused
SELECT customer_id, amount
FROM orders
WHERE amount > (SELECT AVG(amount) FROM orders);
--              ↑ no reference to outer table → runs once

-- Correlated subquery — REFERENCES outer query (e1.department)
-- Runs ONCE PER ROW of outer query
SELECT name, salary,
    (SELECT AVG(salary) FROM employees e2
     WHERE e2.department = e1.department)  -- ← e1 is outer table
     as dept_avg
FROM employees e1;
--  ↑ for each row of e1, subquery runs again with that row's department

**Q5.What is the difference between EXISTS, IN, and JOIN for filtering rows? Which is fastest and under what conditions?**

Exist,IN and JOIN These all are the function which we use to check on on the filter condition.
Lets break one by one

IN--> SELECT customer_id, customer_name
FROM customers
WHERE customer_id IN (
    SELECT customer_id FROM orders
    WHERE order_status = 'delivered'
); 
It runs entire sub Query first and then store the entire result of that sub query then it checks for every customer_id in that result.

problem:It leads to memory wastage as it store all the result,Also can lead to slow execution and can impact the business with extra charges due to memory and more time

when to use:When you have small database

Exist: The core difference between Exists and IN is that Exist dont store all the result of subquery.It checks for every customer_id and if it gets the first matching 
it will stop immediately so it leads to optimize the query and reduces memory wastage

Exists is preferred over IN for large dataset

JOIN-->We do join two table on the basis of particular condition.This is the most efficient way.
We use it when we want to include columns of both the table.

Why SELECT 1 and not SELECT *?
Because EXISTS only cares about existence — TRUE or FALSE. It never uses the actual values returned. Writing SELECT 1 makes this intent explicit and is standard practice


**Q6.Why is SELECT * considered bad practice in production SQL? Give at least 4 reasons.**

Select * is considered bad prcatice in production SQl

Reasons:
1.It will fetch all the columns even the columns that are not needed or we never use
which lead to memory wastage.

2.In cloud warehouse companies are charged for every data scanned so fetching all rows will lead to increase the cost.

3.It prevents covering index from working.

4.If we fetch all columns and do operations like join then unnessary unused column will come which lead to take more time to execute

5.-- Table originally has 5 columns

SELECT * FROM orders;
-- Works fine today
-- Tomorrow someone adds a sensitive column: customer_password
-- Or a huge column: product_description (10KB per row)
-- Your SELECT * now fetches it automatically
-- No error — just suddenly slower or exposing sensitive data
-- You won't even know until something breaks in production


**Q7.What is the difference between implicit and explicit type conversion in SQL? How does implicit conversion affect query performance?**

Implicit Conversion

The database converts data types automatically without you writing anything. You didn't ask for it — it just happens silently in the background.
sql-- customer_id column is INT in the table
-- You pass a STRING '1001' in the WHERE clause
WHERE customer_id = '1001'

-- Database silently converts '1001' (TEXT) to 1001 (INT)
-- OR converts every customer_id (INT) to TEXT for comparison
-- You wrote nothing to cause this — it happened automatically
-- This is IMPLICIT conversion

Explicit Conversion 

You manually tell the database to convert a data type using CAST() or CONVERT(). You are in control — nothing happens automatically.
sql-- You explicitly tell database: convert this to INT
WHERE customer_id = CAST('1001' AS INT)


How Implicit Conversion Kills Performance

sql-- Table: customer_id is stored as INT
-- Index exists on customer_id (INT)

-- Implicit conversion — index CANNOT be used
WHERE customer_id = '1001'
-- Database must convert every single customer_id INT to TEXT
-- to compare with your string '1001'
-- = full table scan = 10M rows checked = slow

--  Explicit match — index IS used
WHERE customer_id = 1001
-- INT compared to INT directly
-- Index works perfectly = fast lookup

**Q8.When would you use a temporary table instead of a CTE? What are the trade-offs between CTE,subquery, and temporary table?**

Tempoarary tables  are physically materialised ,useful for very complex multi-step analysis
Used when same intermediate result needed many times in long analysis
Use when:

Same heavy intermediate result needed 3+ times
Multi-step analysis where each step builds on previous
Result set is very large and recomputing is expensive
Sharing intermediate result across multiple queries in a session

-- Create and store result physically
CREATE TEMPORARY TABLE temp_customer_totals AS
SELECT customer_id, SUM(amount) AS total_spent
FROM orders
WHERE order_status = 'delivered'
GROUP BY customer_id;

-- Use it multiple times across different queries in same session
SELECT * FROM temp_customer_totals WHERE total_spent > 5000;
SELECT AVG(total_spent) FROM temp_customer_totals;
SELECT COUNT(*) FROM temp_customer_totals WHERE total_spent > 10000;

-- Clean up after done
DROP TEMPORARY TABLE temp_customer_totals;

Subquery are inline query.These are simple and can be used once

Simple, used exactly once
No need to reference the result again
Short and does not hurt readability

CTE are complex but it increases readability

Use when:

Complex logic needs to be broken into readable steps
Referenced once or twice within a single query
Want clean readable code that others can understand
Breaking down window functions, recursive logic