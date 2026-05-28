-- Basic MaxCompute SQL Queries for Practice
-- These queries demonstrate fundamental operations and MaxCompute-specific features

-- 1. Simple SELECT with WHERE clause
-- Find all customers from USA
SELECT customer_id, first_name, last_name, city
FROM customers
WHERE country = 'USA'
ORDER BY city;

-- 2. Aggregation with GROUP BY
-- Count customers by country
SELECT country, COUNT(*) as customer_count
FROM customers
GROUP BY country
ORDER BY customer_count DESC;

-- 3. Using built-in functions
-- Calculate age of products in days
SELECT 
    product_id,
    product_name,
    launch_date,
    DATEDIFF(GETDATE(), launch_date, 'dd') as days_since_launch
FROM products
WHERE launch_date IS NOT NULL
ORDER BY days_since_launch;

-- 4. Working with partitioned tables
-- Query orders from specific date partition
SELECT 
    order_id,
    customer_id,
    total_amount,
    order_status
FROM orders
WHERE ds = '20240115'  -- Partition pruning for better performance
ORDER BY total_amount DESC;

-- 5. String functions and pattern matching
-- Find products with 'tech' in brand name (case insensitive)
SELECT 
    product_id,
    product_name,
    brand,
    UPPER(brand) as brand_upper
FROM products
WHERE LOWER(brand) LIKE '%tech%';

-- 6. Date/Time operations
-- Extract date parts from order_date
SELECT 
    order_id,
    order_date,
    YEAR(order_date) as order_year,
    MONTH(order_date) as order_month,
    DAYOFWEEK(order_date) as day_of_week,
    DATE_FORMAT(order_date, 'yyyy-MM-dd') as order_date_formatted
FROM orders
WHERE ds >= '20240115'
LIMIT 10;

-- 7. Mathematical operations and CASE statements
-- Calculate profit margin for products
SELECT 
    product_id,
    product_name,
    price,
    cost,
    ROUND((price - cost), 2) as profit,
    ROUND(((price - cost) / price * 100), 2) as profit_margin_pct,
    CASE 
        WHEN ((price - cost) / price * 100) > 50 THEN 'High Margin'
        WHEN ((price - cost) / price * 100) > 25 THEN 'Medium Margin'
        ELSE 'Low Margin'
    END as margin_category
FROM products
WHERE price > 0 AND cost > 0
ORDER BY profit_margin_pct DESC;

-- 8. Subqueries and EXISTS
-- Find customers who have placed orders
SELECT 
    c.customer_id,
    c.first_name,
    c.last_name,
    c.country
FROM customers c
WHERE EXISTS (
    SELECT 1 
    FROM orders o 
    WHERE o.customer_id = c.customer_id
);

-- 9. Using LIMIT and OFFSET for pagination
-- Get second page of products (assuming 5 products per page)
SELECT 
    product_id,
    product_name,
    category,
    price
FROM products
ORDER BY product_id
LIMIT 5 OFFSET 5;  -- Skip first 5, get next 5

-- 10. NULL handling and COALESCE
-- Handle potential NULL values in data
SELECT 
    customer_id,
    COALESCE(first_name, 'Unknown') as first_name,
    COALESCE(last_name, 'Unknown') as last_name,
    COALESCE(phone, 'No Phone') as phone,
    CASE 
        WHEN email IS NULL THEN 'No Email'
        WHEN email = '' THEN 'Empty Email'
        ELSE email
    END as email_clean
FROM customers;