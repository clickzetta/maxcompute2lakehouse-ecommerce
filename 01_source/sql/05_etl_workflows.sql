-- ETL Workflows and Data Transformation Examples for MaxCompute
-- These scripts demonstrate real-world ETL patterns and best practices

-- =============================================
-- 1. DAILY SALES SUMMARY ETL
-- =============================================

-- Create target summary table
DROP TABLE IF EXISTS daily_sales_summary;
CREATE TABLE daily_sales_summary (
    sales_date STRING,
    total_orders BIGINT,
    total_revenue DOUBLE,
    total_customers BIGINT,
    avg_order_value DOUBLE,
    top_category STRING,
    top_product_id STRING
)
PARTITIONED BY (ds STRING)
COMMENT 'Daily sales summary for reporting'
LIFECYCLE 365;

-- ETL Process: Transform raw orders into daily summary
INSERT OVERWRITE TABLE daily_sales_summary PARTITION (ds = '${bizdate}')
SELECT 
    DATE_FORMAT(o.order_date, 'yyyy-MM-dd') as sales_date,
    COUNT(DISTINCT o.order_id) as total_orders,
    SUM(o.total_amount) as total_revenue,
    COUNT(DISTINCT o.customer_id) as total_customers,
    AVG(o.total_amount) as avg_order_value,
    
    -- Find top category for the day
    (SELECT p.category 
     FROM (
         SELECT p.category, SUM(oi.line_total) as category_revenue
         FROM order_items oi
         JOIN products p ON oi.product_id = p.product_id
         JOIN orders o2 ON oi.order_id = o2.order_id
         WHERE o2.ds = '${bizdate}'
         GROUP BY p.category
         ORDER BY category_revenue DESC
         LIMIT 1
     ) cat_rank) as top_category,
    
    -- Find top product for the day
    (SELECT oi.product_id
     FROM (
         SELECT oi.product_id, SUM(oi.line_total) as product_revenue
         FROM order_items oi
         JOIN orders o2 ON oi.order_id = o2.order_id
         WHERE o2.ds = '${bizdate}'
         GROUP BY oi.product_id
         ORDER BY product_revenue DESC
         LIMIT 1
     ) prod_rank) as top_product_id

FROM orders o
WHERE o.ds = '${bizdate}' 
  AND o.order_status = 'completed'
GROUP BY DATE_FORMAT(o.order_date, 'yyyy-MM-dd');

-- =============================================
-- 2. CUSTOMER SEGMENTATION ETL
-- =============================================

-- Create customer segments table
DROP TABLE IF EXISTS customer_segments;
CREATE TABLE customer_segments (
    customer_id STRING,
    segment_type STRING,
    segment_value STRING,
    total_orders BIGINT,
    total_spent DOUBLE,
    avg_order_value DOUBLE,
    days_since_last_order BIGINT,
    segment_score DOUBLE,
    updated_date DATETIME
)
PARTITIONED BY (ds STRING)
COMMENT 'Customer segmentation analysis'
LIFECYCLE 365;

-- ETL Process: Customer RFM Analysis
INSERT OVERWRITE TABLE customer_segments PARTITION (ds = '${bizdate}')
WITH customer_metrics AS (
    SELECT 
        c.customer_id,
        c.first_name,
        c.last_name,
        c.registration_date,
        COUNT(o.order_id) as total_orders,
        COALESCE(SUM(o.total_amount), 0) as total_spent,
        COALESCE(AVG(o.total_amount), 0) as avg_order_value,
        COALESCE(MAX(o.order_date), c.registration_date) as last_order_date,
        DATEDIFF(GETDATE(), COALESCE(MAX(o.order_date), c.registration_date), 'dd') as days_since_last_order
    FROM customers c
    LEFT JOIN orders o ON c.customer_id = o.customer_id
    GROUP BY c.customer_id, c.first_name, c.last_name, c.registration_date
),
rfm_scores AS (
    SELECT 
        *,
        -- Recency Score (1-5, lower days = higher score)
        CASE 
            WHEN days_since_last_order <= 30 THEN 5
            WHEN days_since_last_order <= 60 THEN 4
            WHEN days_since_last_order <= 90 THEN 3
            WHEN days_since_last_order <= 180 THEN 2
            ELSE 1
        END as recency_score,
        
        -- Frequency Score (1-5, more orders = higher score)
        CASE 
            WHEN total_orders >= 10 THEN 5
            WHEN total_orders >= 5 THEN 4
            WHEN total_orders >= 3 THEN 3
            WHEN total_orders >= 2 THEN 2
            ELSE 1
        END as frequency_score,
        
        -- Monetary Score (1-5, higher spent = higher score)
        CASE 
            WHEN total_spent >= 1000 THEN 5
            WHEN total_spent >= 500 THEN 4
            WHEN total_spent >= 200 THEN 3
            WHEN total_spent >= 100 THEN 2
            ELSE 1
        END as monetary_score
    FROM customer_metrics
)
SELECT 
    customer_id,
    'RFM' as segment_type,
    CASE 
        WHEN (recency_score + frequency_score + monetary_score) >= 12 THEN 'Champions'
        WHEN (recency_score + frequency_score + monetary_score) >= 10 THEN 'Loyal Customers'
        WHEN (recency_score + frequency_score + monetary_score) >= 8 THEN 'Potential Loyalists'
        WHEN (recency_score + frequency_score + monetary_score) >= 6 THEN 'At Risk'
        WHEN (recency_score + frequency_score + monetary_score) >= 4 THEN 'Cannot Lose'
        ELSE 'Lost Customers'
    END as segment_value,
    total_orders,
    total_spent,
    avg_order_value,
    days_since_last_order,
    CAST((recency_score + frequency_score + monetary_score) as DOUBLE) / 3.0 as segment_score,
    GETDATE() as updated_date
FROM rfm_scores;

-- =============================================
-- 3. PRODUCT PERFORMANCE ETL
-- =============================================

-- Create product performance table
DROP TABLE IF EXISTS product_performance;
CREATE TABLE product_performance (
    product_id STRING,
    product_name STRING,
    category STRING,
    total_quantity_sold BIGINT,
    total_revenue DOUBLE,
    total_profit DOUBLE,
    profit_margin_pct DOUBLE,
    orders_count BIGINT,
    unique_customers BIGINT,
    avg_selling_price DOUBLE,
    performance_rank BIGINT,
    performance_tier STRING,
    analysis_date DATETIME
)
PARTITIONED BY (ds STRING)
COMMENT 'Product performance analysis'
LIFECYCLE 365;

-- ETL Process: Product Performance Analysis
INSERT OVERWRITE TABLE product_performance PARTITION (ds = '${bizdate}')
WITH product_metrics AS (
    SELECT 
        p.product_id,
        p.product_name,
        p.category,
        p.cost,
        COALESCE(SUM(oi.quantity), 0) as total_quantity_sold,
        COALESCE(SUM(oi.line_total), 0) as total_revenue,
        COALESCE(SUM(oi.line_total) - (SUM(oi.quantity) * p.cost), 0) as total_profit,
        COUNT(DISTINCT o.order_id) as orders_count,
        COUNT(DISTINCT o.customer_id) as unique_customers,
        COALESCE(AVG(oi.unit_price), 0) as avg_selling_price
    FROM products p
    LEFT JOIN order_items oi ON p.product_id = oi.product_id
    LEFT JOIN orders o ON oi.order_id = o.order_id
    GROUP BY p.product_id, p.product_name, p.category, p.cost
),
ranked_products AS (
    SELECT 
        *,
        CASE 
            WHEN total_revenue > 0 THEN (total_profit / total_revenue) * 100
            ELSE 0
        END as profit_margin_pct,
        ROW_NUMBER() OVER (ORDER BY total_revenue DESC) as performance_rank
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
        WHEN performance_rank <= 5 THEN 'Top Performer'
        WHEN performance_rank <= 20 THEN 'Good Performer'
        WHEN performance_rank <= 50 THEN 'Average Performer'
        WHEN total_revenue > 0 THEN 'Under Performer'
        ELSE 'No Sales'
    END as performance_tier,
    GETDATE() as analysis_date
FROM ranked_products;

-- =============================================
-- 4. WEB ANALYTICS ETL
-- =============================================

-- Create web analytics summary table
DROP TABLE IF EXISTS web_analytics_summary;
CREATE TABLE web_analytics_summary (
    analysis_date STRING,
    total_sessions BIGINT,
    unique_users BIGINT,
    total_page_views BIGINT,
    avg_session_duration DOUBLE,
    bounce_rate DOUBLE,
    conversion_rate DOUBLE,
    top_traffic_source STRING,
    top_page STRING,
    mobile_percentage DOUBLE
)
PARTITIONED BY (ds STRING)
COMMENT 'Web analytics daily summary'
LIFECYCLE 90;

-- ETL Process: Web Analytics Summary
INSERT OVERWRITE TABLE web_analytics_summary PARTITION (ds = '${bizdate}')
WITH daily_sessions AS (
    SELECT 
        ws.*,
        CASE WHEN ws.page_views = 1 THEN 1 ELSE 0 END as is_bounce
    FROM web_sessions ws
    WHERE ws.ds = '${bizdate}'
),
page_view_stats AS (
    SELECT 
        COUNT(DISTINCT session_id) as sessions_with_views,
        COUNT(*) as total_views,
        page_url,
        ROW_NUMBER() OVER (ORDER BY COUNT(*) DESC) as page_rank
    FROM page_views pv
    WHERE pv.ds = '${bizdate}'
    GROUP BY page_url
),
conversion_data AS (
    SELECT 
        COUNT(DISTINCT ws.session_id) as total_sessions_count,
        COUNT(DISTINCT CASE WHEN o.order_id IS NOT NULL THEN ws.session_id END) as converted_sessions
    FROM daily_sessions ws
    LEFT JOIN orders o ON DATE_FORMAT(ws.session_start, 'yyyy-MM-dd') = DATE_FORMAT(o.order_date, 'yyyy-MM-dd')
)
SELECT 
    '${bizdate}' as analysis_date,
    COUNT(DISTINCT ds.session_id) as total_sessions,
    COUNT(DISTINCT ds.user_id) as unique_users,
    SUM(ds.page_views) as total_page_views,
    AVG(ds.session_duration_seconds) as avg_session_duration,
    (SUM(ds.is_bounce) * 100.0 / COUNT(*)) as bounce_rate,
    (cd.converted_sessions * 100.0 / cd.total_sessions_count) as conversion_rate,
    
    -- Top traffic source
    (SELECT traffic_source 
     FROM (
         SELECT traffic_source, COUNT(*) as source_count
         FROM daily_sessions
         GROUP BY traffic_source
         ORDER BY source_count DESC
         LIMIT 1
     ) top_source) as top_traffic_source,
    
    -- Top page
    (SELECT page_url
     FROM page_view_stats
     WHERE page_rank = 1) as top_page,
    
    -- Mobile percentage
    (COUNT(CASE WHEN ds.device_type = 'mobile' THEN 1 END) * 100.0 / COUNT(*)) as mobile_percentage

FROM daily_sessions ds
CROSS JOIN conversion_data cd
GROUP BY cd.converted_sessions, cd.total_sessions_count;

-- =============================================
-- 5. INCREMENTAL DATA PROCESSING
-- =============================================

-- Example of incremental processing with change detection
-- This pattern is useful for large datasets where full refresh is expensive

-- Create change tracking table
DROP TABLE IF EXISTS customer_changes;
CREATE TABLE customer_changes (
    customer_id STRING,
    change_type STRING, -- INSERT, UPDATE, DELETE
    old_data STRING,   -- JSON representation of old data
    new_data STRING,   -- JSON representation of new data
    change_timestamp DATETIME,
    processed BOOLEAN
)
PARTITIONED BY (ds STRING)
COMMENT 'Customer change tracking for incremental processing'
LIFECYCLE 30;

-- Incremental processing example - detect customer changes
INSERT INTO customer_changes PARTITION (ds = '${bizdate}')
SELECT 
    COALESCE(c_current.customer_id, c_previous.customer_id) as customer_id,
    CASE 
        WHEN c_previous.customer_id IS NULL THEN 'INSERT'
        WHEN c_current.customer_id IS NULL THEN 'DELETE'
        ELSE 'UPDATE'
    END as change_type,
    
    CASE 
        WHEN c_previous.customer_id IS NOT NULL THEN 
            CONCAT('{"first_name":"', c_previous.first_name, '","last_name":"', c_previous.last_name, '","email":"', c_previous.email, '"}')
        ELSE NULL
    END as old_data,
    
    CASE 
        WHEN c_current.customer_id IS NOT NULL THEN 
            CONCAT('{"first_name":"', c_current.first_name, '","last_name":"', c_current.last_name, '","email":"', c_current.email, '"}')
        ELSE NULL
    END as new_data,
    
    GETDATE() as change_timestamp,
    false as processed

FROM (
    SELECT * FROM customers -- Current data
) c_current
FULL OUTER JOIN (
    SELECT * FROM customers_snapshot WHERE ds = DATE_SUB('${bizdate}', 1) -- Previous day snapshot
) c_previous ON c_current.customer_id = c_previous.customer_id

WHERE (
    c_previous.customer_id IS NULL OR  -- New customers
    c_current.customer_id IS NULL OR   -- Deleted customers
    c_current.first_name != c_previous.first_name OR  -- Changed data
    c_current.last_name != c_previous.last_name OR
    c_current.email != c_previous.email
);

-- =============================================
-- 6. DATA QUALITY MONITORING
-- =============================================

-- Create data quality metrics table
DROP TABLE IF EXISTS data_quality_metrics;
CREATE TABLE data_quality_metrics (
    table_name STRING,
    metric_name STRING,
    metric_value DOUBLE,
    threshold_value DOUBLE,
    status STRING, -- PASS, FAIL, WARNING
    check_timestamp DATETIME
)
PARTITIONED BY (ds STRING)
COMMENT 'Data quality monitoring metrics'
LIFECYCLE 90;

-- ETL Process: Data Quality Checks
INSERT INTO data_quality_metrics PARTITION (ds = '${bizdate}')
SELECT 'customers' as table_name, 'null_email_rate' as metric_name, 
       (COUNT(CASE WHEN email IS NULL THEN 1 END) * 100.0 / COUNT(*)) as metric_value,
       5.0 as threshold_value,
       CASE WHEN (COUNT(CASE WHEN email IS NULL THEN 1 END) * 100.0 / COUNT(*)) <= 5.0 THEN 'PASS' ELSE 'FAIL' END as status,
       GETDATE() as check_timestamp
FROM customers

UNION ALL

SELECT 'orders' as table_name, 'negative_amount_rate' as metric_name,
       (COUNT(CASE WHEN total_amount <= 0 THEN 1 END) * 100.0 / COUNT(*)) as metric_value,
       1.0 as threshold_value,
       CASE WHEN (COUNT(CASE WHEN total_amount <= 0 THEN 1 END) * 100.0 / COUNT(*)) <= 1.0 THEN 'PASS' ELSE 'FAIL' END as status,
       GETDATE() as check_timestamp
FROM orders
WHERE ds = '${bizdate}'

UNION ALL

SELECT 'products' as table_name, 'price_cost_consistency' as metric_name,
       (COUNT(CASE WHEN price <= cost THEN 1 END) * 100.0 / COUNT(*)) as metric_value,
       2.0 as threshold_value,
       CASE WHEN (COUNT(CASE WHEN price <= cost THEN 1 END) * 100.0 / COUNT(*)) <= 2.0 THEN 'PASS' ELSE 'FAIL' END as status,
       GETDATE() as check_timestamp
FROM products;

-- =============================================
-- 7. ETL ORCHESTRATION PATTERNS
-- =============================================

-- Example of dependency-aware ETL processing
-- This shows how to structure ETL jobs with proper dependencies

-- Step 1: Validate source data
-- (Run data quality checks first)

-- Step 2: Process dimension tables
-- (Customer segments, product performance - can run in parallel)

-- Step 3: Process fact tables
-- (Sales summary - depends on dimensions being ready)

-- Step 4: Generate reports and alerts
-- (Business reports - depends on all previous steps)

-- Sample orchestration metadata table
DROP TABLE IF EXISTS etl_job_status;
CREATE TABLE etl_job_status (
    job_name STRING,
    job_type STRING,
    start_time DATETIME,
    end_time DATETIME,
    status STRING, -- RUNNING, SUCCESS, FAILED
    records_processed BIGINT,
    error_message STRING
)
PARTITIONED BY (ds STRING)
COMMENT 'ETL job execution tracking'
LIFECYCLE 30;

-- Log ETL job completion
INSERT INTO etl_job_status PARTITION (ds = '${bizdate}')
VALUES 
('daily_sales_summary', 'FACT_TABLE', '${start_time}', GETDATE(), 'SUCCESS', 
 (SELECT COUNT(*) FROM daily_sales_summary WHERE ds = '${bizdate}'), NULL);

-- Usage Examples:
-- 1. Schedule these scripts in DataWorks with proper dependencies
-- 2. Use ${bizdate} parameter for date-based processing
-- 3. Add error handling and retry logic
-- 4. Monitor data quality metrics and set up alerts
-- 5. Implement incremental processing for large datasets