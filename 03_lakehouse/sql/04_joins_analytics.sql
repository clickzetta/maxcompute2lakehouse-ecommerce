-- Lakehouse JOIN + 分析查询
-- 对应 01_source/sql/04_joins_analytics.sql
-- 迁移变更：
--   c.first_name + ' ' + c.last_name  → CONCAT(c.first_name, ' ', c.last_name)
--   DATEDIFF(GETDATE(), col, 'dd')    → DATEDIFF(CURRENT_DATE(), CAST(col AS DATE))
--   GETDATE()                          → CURRENT_TIMESTAMP()
--   schema 前缀                         → ecommerce.<table>

-- 1. INNER JOIN — 订单 + 客户信息
SELECT
    o.order_id,
    o.order_date,
    o.total_amount,
    c.first_name,
    c.last_name,
    c.country
FROM ecommerce.orders o
INNER JOIN ecommerce.customers c ON o.customer_id = c.customer_id
WHERE o.ds >= '20240115'
ORDER BY o.order_date;

-- 2. LEFT JOIN — 所有客户及其订单汇总
SELECT
    c.customer_id,
    c.first_name,
    c.last_name,
    COUNT(o.order_id)                  AS total_orders,
    COALESCE(SUM(o.total_amount), 0)   AS total_spent,
    COALESCE(AVG(o.total_amount), 0)   AS avg_order_value
FROM ecommerce.customers c
LEFT JOIN ecommerce.orders o ON c.customer_id = o.customer_id
GROUP BY c.customer_id, c.first_name, c.last_name
ORDER BY total_spent DESC;

-- 3. 多表 JOIN — 订单明细 + 商品信息
SELECT
    o.order_id,
    o.order_date,
    CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
    p.product_name,
    p.category,
    oi.quantity,
    oi.unit_price,
    oi.line_total
FROM ecommerce.orders o
INNER JOIN ecommerce.customers c  ON o.customer_id  = c.customer_id
INNER JOIN ecommerce.order_items oi ON o.order_id   = oi.order_id
INNER JOIN ecommerce.products p   ON oi.product_id  = p.product_id
WHERE o.ds >= '20240115'
ORDER BY o.order_date, o.order_id;

-- 4. 窗口函数 — 客户消费排名
SELECT
    customer_id,
    first_name,
    last_name,
    total_spent,
    ROW_NUMBER()  OVER (ORDER BY total_spent DESC) AS spending_rank,
    RANK()        OVER (ORDER BY total_spent DESC) AS spending_rank_with_ties,
    DENSE_RANK()  OVER (ORDER BY total_spent DESC) AS dense_spending_rank,
    NTILE(4)      OVER (ORDER BY total_spent DESC) AS spending_quartile
FROM (
    SELECT
        c.customer_id,
        c.first_name,
        c.last_name,
        COALESCE(SUM(o.total_amount), 0) AS total_spent
    FROM ecommerce.customers c
    LEFT JOIN ecommerce.orders o ON c.customer_id = o.customer_id
    GROUP BY c.customer_id, c.first_name, c.last_name
) customer_spending;

-- 5. 累计总额 + 移动平均
SELECT
    order_id,
    order_date,
    total_amount,
    SUM(total_amount) OVER (
        ORDER BY order_date
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS running_total,
    AVG(total_amount) OVER (
        ORDER BY order_date
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ) AS moving_avg_3_orders,
    LAG(total_amount, 1)  OVER (ORDER BY order_date) AS prev_order_amount,
    LEAD(total_amount, 1) OVER (ORDER BY order_date) AS next_order_amount
FROM ecommerce.orders
WHERE ds >= '20240115'
ORDER BY order_date;

-- 6. 商品销售表现
SELECT
    p.product_id,
    p.product_name,
    p.category,
    COUNT(DISTINCT o.order_id)                          AS orders_containing_product,
    SUM(oi.quantity)                                    AS total_quantity_sold,
    SUM(oi.line_total)                                  AS total_revenue,
    AVG(oi.unit_price)                                  AS avg_selling_price,
    p.cost,
    SUM(oi.line_total) - (SUM(oi.quantity) * p.cost)   AS total_profit
FROM ecommerce.products p
LEFT JOIN ecommerce.order_items oi ON p.product_id = oi.product_id
LEFT JOIN ecommerce.orders o       ON oi.order_id  = o.order_id
GROUP BY p.product_id, p.product_name, p.category, p.cost
HAVING SUM(oi.quantity) > 0
ORDER BY total_revenue DESC;

-- 7. 客户分层分析
WITH customer_metrics AS (
    SELECT
        c.customer_id,
        c.first_name,
        c.last_name,
        c.registration_date,
        COUNT(o.order_id)                                          AS total_orders,
        SUM(o.total_amount)                                        AS total_spent,
        AVG(o.total_amount)                                        AS avg_order_value,
        MAX(o.order_date)                                          AS last_order_date,
        DATEDIFF(CURRENT_DATE(), CAST(MAX(o.order_date) AS DATE))  AS days_since_last_order
    FROM ecommerce.customers c
    LEFT JOIN ecommerce.orders o ON c.customer_id = o.customer_id
    GROUP BY c.customer_id, c.first_name, c.last_name, c.registration_date
)
SELECT
    customer_id,
    first_name,
    last_name,
    total_orders,
    total_spent,
    avg_order_value,
    days_since_last_order,
    CASE
        WHEN total_spent > 200 AND total_orders > 2 THEN 'VIP'
        WHEN total_spent > 100 AND total_orders > 1 THEN 'Regular'
        WHEN total_orders = 1                        THEN 'New'
        ELSE 'Inactive'
    END AS customer_segment,
    CASE
        WHEN days_since_last_order IS NULL  THEN 'Never Ordered'
        WHEN days_since_last_order <= 30    THEN 'Active'
        WHEN days_since_last_order <= 90    THEN 'At Risk'
        ELSE 'Churned'
    END AS activity_status
FROM customer_metrics
ORDER BY total_spent DESC;

-- 8. 月度趋势分析
SELECT
    DATE_FORMAT(CAST(order_date AS TIMESTAMP), 'yyyy-MM')   AS order_month,
    COUNT(DISTINCT order_id)                                 AS total_orders,
    COUNT(DISTINCT customer_id)                              AS unique_customers,
    SUM(total_amount)                                        AS total_revenue,
    AVG(total_amount)                                        AS avg_order_value,
    SUM(total_amount) / COUNT(DISTINCT customer_id)          AS revenue_per_customer
FROM ecommerce.orders
WHERE ds >= '20240101'
GROUP BY DATE_FORMAT(CAST(order_date AS TIMESTAMP), 'yyyy-MM')
ORDER BY order_month;

-- 9. 自连接 — 同城客户
SELECT DISTINCT
    c1.customer_id                                    AS customer1_id,
    CONCAT(c1.first_name, ' ', c1.last_name)          AS customer1_name,
    c2.customer_id                                    AS customer2_id,
    CONCAT(c2.first_name, ' ', c2.last_name)          AS customer2_name,
    c1.city,
    c1.country
FROM ecommerce.customers c1
INNER JOIN ecommerce.customers c2
    ON c1.city = c2.city AND c1.country = c2.country
WHERE c1.customer_id < c2.customer_id
ORDER BY c1.country, c1.city;

-- 10. 交叉表 — 商品按类别和价格区间
SELECT
    category,
    COUNT(CASE WHEN price < 50                        THEN 1 END) AS under_50,
    COUNT(CASE WHEN price >= 50  AND price < 100      THEN 1 END) AS from_50_to_100,
    COUNT(CASE WHEN price >= 100 AND price < 200      THEN 1 END) AS from_100_to_200,
    COUNT(CASE WHEN price >= 200                      THEN 1 END) AS over_200,
    COUNT(*)                                                       AS total_products
FROM ecommerce.products
GROUP BY category
ORDER BY category;
