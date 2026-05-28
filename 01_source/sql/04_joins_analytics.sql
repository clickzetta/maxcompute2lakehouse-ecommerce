-- Advanced JOIN Operations and Analytics in MaxCompute
-- These queries demonstrate complex data relationships and analytical functions

-- 1. Basic INNER JOIN - Orders with Customer Details
SELECT 
    o.order_id,
    o.order_date,
    o.total_amount,
    c.first_name,
    c.last_name,
    c.country
FROM orders o
INNER JOIN customers c ON o.customer_id = c.customer_id
WHERE o.ds >= '20240115'
ORDER BY o.order_date;

-- 2. LEFT JOIN - All customers with their order summary
SELECT 
    c.customer_id,
    c.first_name,
    c.last_name,
    COUNT(o.order_id) as total_orders,
    COALESCE(SUM(o.total_amount), 0) as total_spent,
    COALESCE(AVG(o.total_amount), 0) as avg_order_value
FROM customers c
LEFT JOIN orders o ON c.customer_id = o.customer_id
GROUP BY c.customer_id, c.first_name, c.last_name
ORDER BY total_spent DESC;

-- 3. Multiple JOINs - Order Details with Product Information
SELECT 
    o.order_id,
    o.order_date,
    c.first_name + ' ' + c.last_name as customer_name,
    p.product_name,
    p.category,
    oi.quantity,
    oi.unit_price,
    oi.line_total
FROM orders o
INNER JOIN customers c ON o.customer_id = c.customer_id
INNER JOIN order_items oi ON o.order_id = oi.order_id
INNER JOIN products p ON oi.product_id = p.product_id
WHERE o.ds >= '20240115'
ORDER BY o.order_date, o.order_id;

-- 4. Window Functions - Customer Ranking by Spending
SELECT 
    customer_id,
    first_name,
    last_name,
    total_spent,
    ROW_NUMBER() OVER (ORDER BY total_spent DESC) as spending_rank,
    RANK() OVER (ORDER BY total_spent DESC) as spending_rank_with_ties,
    DENSE_RANK() OVER (ORDER BY total_spent DESC) as dense_spending_rank,
    NTILE(4) OVER (ORDER BY total_spent DESC) as spending_quartile
FROM (
    SELECT 
        c.customer_id,
        c.first_name,
        c.last_name,
        COALESCE(SUM(o.total_amount), 0) as total_spent
    FROM customers c
    LEFT JOIN orders o ON c.customer_id = o.customer_id
    GROUP BY c.customer_id, c.first_name, c.last_name
) customer_spending;

-- 5. Running Totals and Moving Averages
SELECT 
    order_id,
    order_date,
    total_amount,
    SUM(total_amount) OVER (
        ORDER BY order_date 
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) as running_total,
    AVG(total_amount) OVER (
        ORDER BY order_date 
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ) as moving_avg_3_orders,
    LAG(total_amount, 1) OVER (ORDER BY order_date) as prev_order_amount,
    LEAD(total_amount, 1) OVER (ORDER BY order_date) as next_order_amount
FROM orders
WHERE ds >= '20240115'
ORDER BY order_date;

-- 6. Product Performance Analysis
SELECT 
    p.product_id,
    p.product_name,
    p.category,
    COUNT(DISTINCT o.order_id) as orders_containing_product,
    SUM(oi.quantity) as total_quantity_sold,
    SUM(oi.line_total) as total_revenue,
    AVG(oi.unit_price) as avg_selling_price,
    p.cost,
    SUM(oi.line_total) - (SUM(oi.quantity) * p.cost) as total_profit
FROM products p
LEFT JOIN order_items oi ON p.product_id = oi.product_id
LEFT JOIN orders o ON oi.order_id = o.order_id
GROUP BY 
    p.product_id, p.product_name, p.category, p.cost
HAVING SUM(oi.quantity) > 0  -- Only products that have been sold
ORDER BY total_revenue DESC;

-- 7. Customer Segmentation Analysis
WITH customer_metrics AS (
    SELECT 
        c.customer_id,
        c.first_name,
        c.last_name,
        c.registration_date,
        COUNT(o.order_id) as total_orders,
        SUM(o.total_amount) as total_spent,
        AVG(o.total_amount) as avg_order_value,
        MAX(o.order_date) as last_order_date,
        DATEDIFF(GETDATE(), MAX(o.order_date), 'dd') as days_since_last_order
    FROM customers c
    LEFT JOIN orders o ON c.customer_id = o.customer_id
    GROUP BY 
        c.customer_id, c.first_name, c.last_name, c.registration_date
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
        WHEN total_orders = 1 THEN 'New'
        ELSE 'Inactive'
    END as customer_segment,
    CASE 
        WHEN days_since_last_order IS NULL THEN 'Never Ordered'
        WHEN days_since_last_order <= 30 THEN 'Active'
        WHEN days_since_last_order <= 90 THEN 'At Risk'
        ELSE 'Churned'
    END as activity_status
FROM customer_metrics
ORDER BY total_spent DESC;

-- 8. Time-based Analysis - Monthly Trends
SELECT 
    DATE_FORMAT(order_date, 'yyyy-MM') as order_month,
    COUNT(DISTINCT order_id) as total_orders,
    COUNT(DISTINCT customer_id) as unique_customers,
    SUM(total_amount) as total_revenue,
    AVG(total_amount) as avg_order_value,
    SUM(total_amount) / COUNT(DISTINCT customer_id) as revenue_per_customer
FROM orders
WHERE ds >= '20240101'
GROUP BY DATE_FORMAT(order_date, 'yyyy-MM')
ORDER BY order_month;

-- 9. Self-JOIN - Find customers from the same city
SELECT DISTINCT
    c1.customer_id as customer1_id,
    c1.first_name + ' ' + c1.last_name as customer1_name,
    c2.customer_id as customer2_id,
    c2.first_name + ' ' + c2.last_name as customer2_name,
    c1.city,
    c1.country
FROM customers c1
INNER JOIN customers c2 ON c1.city = c2.city AND c1.country = c2.country
WHERE c1.customer_id < c2.customer_id  -- Avoid duplicates
ORDER BY c1.country, c1.city;

-- 10. Cross-tabulation - Products by Category and Price Range
SELECT 
    category,
    COUNT(CASE WHEN price < 50 THEN 1 END) as under_50,
    COUNT(CASE WHEN price >= 50 AND price < 100 THEN 1 END) as from_50_to_100,
    COUNT(CASE WHEN price >= 100 AND price < 200 THEN 1 END) as from_100_to_200,
    COUNT(CASE WHEN price >= 200 THEN 1 END) as over_200,
    COUNT(*) as total_products
FROM products
GROUP BY category
ORDER BY category;