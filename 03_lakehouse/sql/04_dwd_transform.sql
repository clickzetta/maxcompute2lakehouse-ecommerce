-- Lakehouse DWD 层数据填充
-- 对应 01_source/sql/05_etl_workflows.sql 的 INSERT 逻辑
-- 日期参数由 e2e.py 通过 Python f-string 传入，此处用 '20240115' 作为示例

-- 1. 每日销售汇总
INSERT OVERWRITE TABLE ecommerce_dwd.daily_sales_summary PARTITION (ds = '20240115')
SELECT
    DATE_FORMAT(o.order_date, 'yyyy-MM-dd') AS sales_date,
    COUNT(DISTINCT o.order_id)              AS total_orders,
    SUM(o.total_amount)                     AS total_revenue,
    COUNT(DISTINCT o.customer_id)           AS total_customers,
    AVG(o.total_amount)                     AS avg_order_value,
    top_cat.category                        AS top_category,
    top_prod.product_id                     AS top_product_id
FROM ecommerce.orders o
LEFT JOIN (
    SELECT p.category
    FROM ecommerce.order_items oi
    JOIN ecommerce.products p ON oi.product_id = p.product_id
    JOIN ecommerce.orders o2  ON oi.order_id   = o2.order_id
    WHERE o2.ds = '20240115'
    GROUP BY p.category
    ORDER BY SUM(oi.line_total) DESC
    LIMIT 1
) top_cat ON 1 = 1
LEFT JOIN (
    SELECT oi.product_id
    FROM ecommerce.order_items oi
    JOIN ecommerce.orders o2 ON oi.order_id = o2.order_id
    WHERE o2.ds = '20240115'
    GROUP BY oi.product_id
    ORDER BY SUM(oi.line_total) DESC
    LIMIT 1
) top_prod ON 1 = 1
WHERE o.ds = '20240115'
  AND o.order_status = 'completed'
GROUP BY DATE_FORMAT(o.order_date, 'yyyy-MM-dd'), top_cat.category, top_prod.product_id;

-- 2. 客户分层
INSERT OVERWRITE TABLE ecommerce_dwd.customer_segments PARTITION (ds = '20240115')
SELECT
    c.customer_id,
    'value_segment'                                          AS segment_type,
    CASE
        WHEN SUM(o.total_amount) >= 1000 THEN 'High Value'
        WHEN SUM(o.total_amount) >= 500  THEN 'Mid Value'
        ELSE 'Low Value'
    END                                                      AS segment_value,
    COUNT(DISTINCT o.order_id)                               AS total_orders,
    COALESCE(SUM(o.total_amount), 0)                         AS total_spent,
    COALESCE(AVG(o.total_amount), 0)                         AS avg_order_value,
    DATEDIFF(CURRENT_DATE(), MAX(CAST(o.order_date AS DATE))) AS days_since_last_order,
    COALESCE(SUM(o.total_amount), 0) / 100.0                 AS segment_score,
    CURRENT_TIMESTAMP()                                      AS updated_date
FROM ecommerce.customers c
LEFT JOIN ecommerce.orders o ON c.customer_id = o.customer_id
GROUP BY c.customer_id;

-- 3. 商品表现
INSERT OVERWRITE TABLE ecommerce_dwd.product_performance PARTITION (ds = '20240115')
WITH product_metrics AS (
    SELECT
        p.product_id,
        p.product_name,
        p.category,
        p.cost,
        COALESCE(SUM(oi.quantity), 0)                                    AS total_quantity_sold,
        COALESCE(SUM(oi.line_total), 0)                                  AS total_revenue,
        COALESCE(SUM(oi.line_total) - SUM(oi.quantity) * p.cost, 0)     AS total_profit,
        COUNT(DISTINCT o.order_id)                                       AS orders_count,
        COUNT(DISTINCT o.customer_id)                                    AS unique_customers,
        COALESCE(AVG(oi.unit_price), 0)                                  AS avg_selling_price
    FROM ecommerce.products p
    LEFT JOIN ecommerce.order_items oi ON p.product_id = oi.product_id
    LEFT JOIN ecommerce.orders o       ON oi.order_id  = o.order_id
    GROUP BY p.product_id, p.product_name, p.category, p.cost
),
ranked AS (
    SELECT
        *,
        CASE WHEN total_revenue > 0 THEN total_profit / total_revenue * 100 ELSE 0 END AS profit_margin_pct,
        ROW_NUMBER() OVER (ORDER BY total_revenue DESC) AS performance_rank
    FROM product_metrics
)
SELECT
    product_id,
    product_name,
    category,
    total_quantity_sold,
    total_revenue,
    total_profit,
    profit_margin_pct,
    orders_count,
    unique_customers,
    avg_selling_price,
    performance_rank,
    CASE
        WHEN performance_rank <= 5  THEN 'Top Performer'
        WHEN performance_rank <= 20 THEN 'Good Performer'
        WHEN performance_rank <= 50 THEN 'Average Performer'
        WHEN total_revenue > 0      THEN 'Under Performer'
        ELSE 'No Sales'
    END                 AS performance_tier,
    CURRENT_TIMESTAMP() AS analysis_date
FROM ranked;
