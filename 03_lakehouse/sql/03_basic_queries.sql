-- Lakehouse 基础查询
-- 对应 01_source/sql/03_basic_queries.sql
-- 迁移变更：
--   GETDATE()                        → CURRENT_TIMESTAMP()
--   DATEDIFF(GETDATE(), col, 'dd')   → DATEDIFF(CURRENT_DATE(), CAST(col AS DATE))
--   schema 前缀                       → ecommerce.<table>

-- 1. 简单 SELECT + WHERE
SELECT customer_id, first_name, last_name, city
FROM ecommerce.customers
WHERE country = 'USA'
ORDER BY city;

-- 2. GROUP BY 聚合
SELECT country, COUNT(*) AS customer_count
FROM ecommerce.customers
GROUP BY country
ORDER BY customer_count DESC;

-- 3. 内置函数 — 商品上架天数
SELECT
    product_id,
    product_name,
    launch_date,
    DATEDIFF(CURRENT_DATE(), CAST(launch_date AS DATE)) AS days_since_launch
FROM ecommerce.products
WHERE launch_date IS NOT NULL
ORDER BY days_since_launch;

-- 4. 分区表查询（分区裁剪）
SELECT
    order_id,
    customer_id,
    total_amount,
    order_status
FROM ecommerce.orders
WHERE ds = '20240115'
ORDER BY total_amount DESC;

-- 5. 字符串函数 + 模式匹配
SELECT
    product_id,
    product_name,
    brand,
    UPPER(brand) AS brand_upper
FROM ecommerce.products
WHERE LOWER(brand) LIKE '%tech%';

-- 6. 日期时间操作
SELECT
    order_id,
    order_date,
    YEAR(CAST(order_date AS TIMESTAMP))                    AS order_year,
    MONTH(CAST(order_date AS TIMESTAMP))                   AS order_month,
    DAYOFWEEK(CAST(order_date AS TIMESTAMP))               AS day_of_week,
    DATE_FORMAT(CAST(order_date AS TIMESTAMP), 'yyyy-MM-dd') AS order_date_formatted
FROM ecommerce.orders
WHERE ds >= '20240115'
LIMIT 10;

-- 7. 数学运算 + CASE
SELECT
    product_id,
    product_name,
    price,
    cost,
    ROUND((price - cost), 2)                          AS profit,
    ROUND(((price - cost) / price * 100), 2)          AS profit_margin_pct,
    CASE
        WHEN ((price - cost) / price * 100) > 50 THEN 'High Margin'
        WHEN ((price - cost) / price * 100) > 25 THEN 'Medium Margin'
        ELSE 'Low Margin'
    END AS margin_category
FROM ecommerce.products
WHERE price > 0 AND cost > 0
ORDER BY profit_margin_pct DESC;

-- 8. 子查询 + EXISTS
SELECT
    c.customer_id,
    c.first_name,
    c.last_name,
    c.country
FROM ecommerce.customers c
WHERE EXISTS (
    SELECT 1
    FROM ecommerce.orders o
    WHERE o.customer_id = c.customer_id
);

-- 9. LIMIT + OFFSET 分页
SELECT
    product_id,
    product_name,
    category,
    price
FROM ecommerce.products
ORDER BY product_id
LIMIT 5 OFFSET 5;

-- 10. NULL 处理 + COALESCE
SELECT
    customer_id,
    COALESCE(first_name, 'Unknown') AS first_name,
    COALESCE(last_name, 'Unknown')  AS last_name,
    COALESCE(phone, 'No Phone')     AS phone,
    CASE
        WHEN email IS NULL THEN 'No Email'
        WHEN email = ''   THEN 'Empty Email'
        ELSE email
    END AS email_status
FROM ecommerce.customers;
