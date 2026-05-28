-- Lakehouse ADS 层转换（05_etl_workflows.sql 剩余部分）
-- 对应 01_source/sql/05_etl_workflows.sql 中的：
--   4. WEB ANALYTICS ETL
--   5. INCREMENTAL PROCESSING
--   6. DATA QUALITY MONITORING
-- 迁移变更：
--   ${bizdate}       → 字面量 '20240115'（Python 层动态传入）
--   GETDATE()        → CURRENT_TIMESTAMP()
--   DATETIME         → TIMESTAMP
--   LIFECYCLE        → 删除
--   BOOLEAN          → BOOLEAN
--   INSERT INTO      → INSERT INTO（增量）/ INSERT OVERWRITE（全量）

CREATE SCHEMA IF NOT EXISTS ecommerce_ads;

-- =============================================
-- 4. WEB ANALYTICS ETL
-- =============================================

DROP TABLE IF EXISTS ecommerce_ads.web_analytics_summary;
CREATE TABLE ecommerce_ads.web_analytics_summary (
    analysis_date        STRING,
    total_sessions       BIGINT,
    unique_users         BIGINT,
    total_page_views     BIGINT,
    avg_session_duration DOUBLE,
    bounce_rate          DOUBLE,
    conversion_rate      DOUBLE,
    top_traffic_source   STRING,
    top_page             STRING,
    mobile_percentage    DOUBLE
)
PARTITIONED BY (ds STRING);

INSERT OVERWRITE TABLE ecommerce_ads.web_analytics_summary PARTITION (ds = '20240115')
WITH daily_sessions AS (
    SELECT
        ws.*,
        CASE WHEN ws.page_views = 1 THEN 1 ELSE 0 END AS is_bounce
    FROM ecommerce.web_sessions ws
    WHERE ws.ds = '20240115'
),
page_view_stats AS (
    SELECT
        page_url,
        COUNT(DISTINCT session_id)                          AS sessions_with_views,
        COUNT(*)                                            AS total_views,
        ROW_NUMBER() OVER (ORDER BY COUNT(*) DESC)          AS page_rank
    FROM ecommerce.page_views
    WHERE ds = '20240115'
    GROUP BY page_url
),
conversion_data AS (
    SELECT
        COUNT(DISTINCT ws.session_id)                                                          AS total_sessions_count,
        COUNT(DISTINCT CASE WHEN o.order_id IS NOT NULL THEN ws.session_id END)                AS converted_sessions
    FROM daily_sessions ws
    LEFT JOIN ecommerce.orders o
        ON DATE_FORMAT(CAST(ws.session_start AS TIMESTAMP), 'yyyy-MM-dd')
         = DATE_FORMAT(CAST(o.order_date    AS TIMESTAMP), 'yyyy-MM-dd')
)
SELECT
    '20240115'                                                                  AS analysis_date,
    COUNT(DISTINCT ds.session_id)                                               AS total_sessions,
    COUNT(DISTINCT ds.user_id)                                                  AS unique_users,
    SUM(ds.page_views)                                                          AS total_page_views,
    AVG(ds.session_duration_seconds)                                            AS avg_session_duration,
    (SUM(ds.is_bounce) * 100.0 / COUNT(*))                                      AS bounce_rate,
    (cd.converted_sessions * 100.0 / cd.total_sessions_count)                  AS conversion_rate,
    (SELECT traffic_source
     FROM (
         SELECT traffic_source, COUNT(*) AS source_count
         FROM daily_sessions
         GROUP BY traffic_source
         ORDER BY source_count DESC
         LIMIT 1
     ) top_source)                                                              AS top_traffic_source,
    (SELECT page_url FROM page_view_stats WHERE page_rank = 1)                  AS top_page,
    (COUNT(CASE WHEN ds.device_type = 'mobile' THEN 1 END) * 100.0 / COUNT(*)) AS mobile_percentage
FROM daily_sessions ds
CROSS JOIN conversion_data cd
GROUP BY cd.converted_sessions, cd.total_sessions_count;

-- =============================================
-- 5. INCREMENTAL PROCESSING（变更检测）
-- =============================================

DROP TABLE IF EXISTS ecommerce_ads.customer_changes;
CREATE TABLE ecommerce_ads.customer_changes (
    customer_id      STRING,
    change_type      STRING,
    old_data         STRING,
    new_data         STRING,
    change_timestamp TIMESTAMP,
    processed        BOOLEAN
)
PARTITIONED BY (ds STRING);

-- 增量写入：检测客户变更（与前一天对比）
-- 实际使用时 '20240114' 和 '20240115' 由 Python 层传入
INSERT INTO ecommerce_ads.customer_changes PARTITION (ds = '20240115')
SELECT
    COALESCE(c_cur.customer_id, c_pre.customer_id) AS customer_id,
    CASE
        WHEN c_pre.customer_id IS NULL THEN 'INSERT'
        WHEN c_cur.customer_id IS NULL THEN 'DELETE'
        ELSE 'UPDATE'
    END AS change_type,
    CASE
        WHEN c_pre.customer_id IS NOT NULL
        THEN CONCAT('{"first_name":"', COALESCE(c_pre.first_name,''), '","email":"', COALESCE(c_pre.email,''), '"}')
        ELSE NULL
    END AS old_data,
    CASE
        WHEN c_cur.customer_id IS NOT NULL
        THEN CONCAT('{"first_name":"', COALESCE(c_cur.first_name,''), '","email":"', COALESCE(c_cur.email,''), '"}')
        ELSE NULL
    END AS new_data,
    CURRENT_TIMESTAMP() AS change_timestamp,
    false               AS processed
FROM ecommerce.customers c_cur
FULL OUTER JOIN ecommerce.customers c_pre
    ON c_cur.customer_id = c_pre.customer_id
WHERE
    c_pre.customer_id IS NULL
    OR c_cur.customer_id IS NULL
    OR c_cur.first_name != c_pre.first_name
    OR c_cur.last_name  != c_pre.last_name
    OR c_cur.email      != c_pre.email;

-- =============================================
-- 6. DATA QUALITY MONITORING
-- =============================================

DROP TABLE IF EXISTS ecommerce_ads.data_quality_metrics;
CREATE TABLE ecommerce_ads.data_quality_metrics (
    table_name       STRING,
    metric_name      STRING,
    metric_value     DOUBLE,
    threshold_value  DOUBLE,
    status           STRING,
    check_timestamp  TIMESTAMP
)
PARTITIONED BY (ds STRING);

INSERT INTO ecommerce_ads.data_quality_metrics PARTITION (ds = '20240115')
SELECT 'customers' AS table_name, 'null_email_rate'    AS metric_name,
       (COUNT(CASE WHEN email IS NULL THEN 1 END) * 100.0 / COUNT(*)) AS metric_value,
       5.0 AS threshold_value,
       CASE WHEN (COUNT(CASE WHEN email IS NULL THEN 1 END) * 100.0 / COUNT(*)) <= 5.0 THEN 'PASS' ELSE 'FAIL' END AS status,
       CURRENT_TIMESTAMP() AS check_timestamp
FROM ecommerce.customers

UNION ALL

SELECT 'orders' AS table_name, 'negative_amount_rate' AS metric_name,
       (COUNT(CASE WHEN total_amount <= 0 THEN 1 END) * 100.0 / COUNT(*)) AS metric_value,
       0.0 AS threshold_value,
       CASE WHEN COUNT(CASE WHEN total_amount <= 0 THEN 1 END) = 0 THEN 'PASS' ELSE 'FAIL' END AS status,
       CURRENT_TIMESTAMP() AS check_timestamp
FROM ecommerce.orders

UNION ALL

SELECT 'products' AS table_name, 'price_below_cost_rate' AS metric_name,
       (COUNT(CASE WHEN price <= cost THEN 1 END) * 100.0 / COUNT(*)) AS metric_value,
       2.0 AS threshold_value,
       CASE WHEN (COUNT(CASE WHEN price <= cost THEN 1 END) * 100.0 / COUNT(*)) <= 2.0 THEN 'PASS' ELSE 'WARNING' END AS status,
       CURRENT_TIMESTAMP() AS check_timestamp
FROM ecommerce.products;
