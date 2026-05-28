-- Lakehouse 数据质量框架
-- 对应 01_source/sql/06_data_quality.sql
-- 迁移变更：
--   RLIKE              → REGEXP
--   GETDATE()          → CURRENT_TIMESTAMP()
--   ${bizdate}         → '20240115'（Python 层传入）
--   CAST(x AS STRING)  → CAST(x AS VARCHAR)
--   DATETIME           → TIMESTAMP
--   LIFECYCLE          → 删除
--   BOOLEAN            → BOOLEAN（Lakehouse 支持）

-- =============================================
-- 1. 数据质量规则配置表
-- =============================================

DROP TABLE IF EXISTS ecommerce_ads.dq_rules;
CREATE TABLE ecommerce_ads.dq_rules (
    rule_id         STRING,
    table_name      STRING,
    column_name     STRING,
    rule_type       STRING,
    rule_definition STRING,
    threshold_value DOUBLE,
    severity        STRING,
    active          BOOLEAN,
    created_date    TIMESTAMP
);

INSERT INTO ecommerce_ads.dq_rules VALUES
('DQ001', 'customers', 'customer_id', 'NULL_CHECK',       'customer_id IS NOT NULL',                                                    0.0, 'CRITICAL', true, CURRENT_TIMESTAMP()),
('DQ002', 'customers', 'email',       'FORMAT_CHECK',     'email REGEXP "^[A-Za-z0-9+_.-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"',           5.0, 'WARNING',  true, CURRENT_TIMESTAMP()),
('DQ003', 'customers', 'customer_id', 'UNIQUENESS_CHECK', 'COUNT(customer_id) = COUNT(DISTINCT customer_id)',                            0.0, 'CRITICAL', true, CURRENT_TIMESTAMP()),
('DQ004', 'orders',    'total_amount','RANGE_CHECK',      'total_amount > 0',                                                           1.0, 'CRITICAL', true, CURRENT_TIMESTAMP()),
('DQ005', 'products',  'price',       'RANGE_CHECK',      'price > cost',                                                               2.0, 'WARNING',  true, CURRENT_TIMESTAMP()),
('DQ006', 'orders',    'customer_id', 'REFERENTIAL_CHECK','customer_id EXISTS IN customers',                                            0.0, 'CRITICAL', true, CURRENT_TIMESTAMP());

-- =============================================
-- 2. 数据 Profiling
-- =============================================

DROP TABLE IF EXISTS ecommerce_ads.data_profile;
CREATE TABLE ecommerce_ads.data_profile (
    table_name      STRING,
    column_name     STRING,
    data_type       STRING,
    total_records   BIGINT,
    null_count      BIGINT,
    null_percentage DOUBLE,
    distinct_count  BIGINT,
    min_value       STRING,
    max_value       STRING,
    avg_value       DOUBLE,
    std_dev         DOUBLE,
    profile_date    TIMESTAMP
)
PARTITIONED BY (ds STRING);

INSERT INTO ecommerce_ads.data_profile PARTITION (ds = '20240115')
SELECT
    'customers' AS table_name, 'customer_id' AS column_name, 'STRING' AS data_type,
    COUNT(*)                                                        AS total_records,
    COUNT(CASE WHEN customer_id IS NULL THEN 1 END)                 AS null_count,
    COUNT(CASE WHEN customer_id IS NULL THEN 1 END) * 100.0 / COUNT(*) AS null_percentage,
    COUNT(DISTINCT customer_id)                                     AS distinct_count,
    MIN(customer_id)                                                AS min_value,
    MAX(customer_id)                                                AS max_value,
    NULL                                                            AS avg_value,
    NULL                                                            AS std_dev,
    CURRENT_TIMESTAMP()                                             AS profile_date
FROM ecommerce.customers

UNION ALL

SELECT
    'customers' AS table_name, 'email' AS column_name, 'STRING' AS data_type,
    COUNT(*)                                                        AS total_records,
    COUNT(CASE WHEN email IS NULL THEN 1 END)                       AS null_count,
    COUNT(CASE WHEN email IS NULL THEN 1 END) * 100.0 / COUNT(*)    AS null_percentage,
    COUNT(DISTINCT email)                                           AS distinct_count,
    NULL                                                            AS min_value,
    NULL                                                            AS max_value,
    NULL                                                            AS avg_value,
    NULL                                                            AS std_dev,
    CURRENT_TIMESTAMP()                                             AS profile_date
FROM ecommerce.customers

UNION ALL

SELECT
    'orders' AS table_name, 'total_amount' AS column_name, 'DOUBLE' AS data_type,
    COUNT(*)                                                        AS total_records,
    COUNT(CASE WHEN total_amount IS NULL THEN 1 END)                AS null_count,
    COUNT(CASE WHEN total_amount IS NULL THEN 1 END) * 100.0 / COUNT(*) AS null_percentage,
    COUNT(DISTINCT total_amount)                                    AS distinct_count,
    CAST(MIN(total_amount) AS VARCHAR)                              AS min_value,
    CAST(MAX(total_amount) AS VARCHAR)                              AS max_value,
    AVG(total_amount)                                               AS avg_value,
    STDDEV(total_amount)                                            AS std_dev,
    CURRENT_TIMESTAMP()                                             AS profile_date
FROM ecommerce.orders;

-- =============================================
-- 3. 数据质量评估
-- =============================================

DROP TABLE IF EXISTS ecommerce_ads.dq_assessment;
CREATE TABLE ecommerce_ads.dq_assessment (
    rule_id         STRING,
    table_name      STRING,
    column_name     STRING,
    rule_type       STRING,
    total_records   BIGINT,
    failed_records  BIGINT,
    failure_rate    DOUBLE,
    threshold_value DOUBLE,
    status          STRING,
    severity        STRING,
    error_details   STRING,
    assessment_date TIMESTAMP
)
PARTITIONED BY (ds STRING);

INSERT INTO ecommerce_ads.dq_assessment PARTITION (ds = '20240115')
SELECT
    'DQ001' AS rule_id, 'customers' AS table_name, 'customer_id' AS column_name,
    'NULL_CHECK' AS rule_type,
    COUNT(*) AS total_records,
    COUNT(CASE WHEN customer_id IS NULL THEN 1 END) AS failed_records,
    COUNT(CASE WHEN customer_id IS NULL THEN 1 END) * 100.0 / COUNT(*) AS failure_rate,
    0.0 AS threshold_value,
    CASE WHEN COUNT(CASE WHEN customer_id IS NULL THEN 1 END) = 0 THEN 'PASS' ELSE 'FAIL' END AS status,
    'CRITICAL' AS severity,
    CASE WHEN COUNT(CASE WHEN customer_id IS NULL THEN 1 END) > 0
         THEN CONCAT('Found ', CAST(COUNT(CASE WHEN customer_id IS NULL THEN 1 END) AS VARCHAR), ' null customer_id records')
         ELSE 'No null values found' END AS error_details,
    CURRENT_TIMESTAMP() AS assessment_date
FROM ecommerce.customers

UNION ALL

SELECT
    'DQ002' AS rule_id, 'customers' AS table_name, 'email' AS column_name,
    'FORMAT_CHECK' AS rule_type,
    COUNT(*) AS total_records,
    COUNT(CASE WHEN email IS NOT NULL AND NOT (email REGEXP '^[A-Za-z0-9+_.-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$') THEN 1 END) AS failed_records,
    COUNT(CASE WHEN email IS NOT NULL AND NOT (email REGEXP '^[A-Za-z0-9+_.-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$') THEN 1 END) * 100.0 / COUNT(*) AS failure_rate,
    5.0 AS threshold_value,
    CASE WHEN COUNT(CASE WHEN email IS NOT NULL AND NOT (email REGEXP '^[A-Za-z0-9+_.-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$') THEN 1 END) * 100.0 / COUNT(*) <= 5.0 THEN 'PASS' ELSE 'WARNING' END AS status,
    'WARNING' AS severity,
    CASE WHEN COUNT(CASE WHEN email IS NOT NULL AND NOT (email REGEXP '^[A-Za-z0-9+_.-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$') THEN 1 END) > 0
         THEN CONCAT('Found ', CAST(COUNT(CASE WHEN email IS NOT NULL AND NOT (email REGEXP '^[A-Za-z0-9+_.-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$') THEN 1 END) AS VARCHAR), ' invalid email formats')
         ELSE 'All email formats are valid' END AS error_details,
    CURRENT_TIMESTAMP() AS assessment_date
FROM ecommerce.customers

UNION ALL

SELECT
    'DQ003' AS rule_id, 'customers' AS table_name, 'customer_id' AS column_name,
    'UNIQUENESS_CHECK' AS rule_type,
    COUNT(*) AS total_records,
    (COUNT(*) - COUNT(DISTINCT customer_id)) AS failed_records,
    (COUNT(*) - COUNT(DISTINCT customer_id)) * 100.0 / COUNT(*) AS failure_rate,
    0.0 AS threshold_value,
    CASE WHEN COUNT(*) = COUNT(DISTINCT customer_id) THEN 'PASS' ELSE 'FAIL' END AS status,
    'CRITICAL' AS severity,
    CASE WHEN COUNT(*) != COUNT(DISTINCT customer_id)
         THEN CONCAT('Found ', CAST((COUNT(*) - COUNT(DISTINCT customer_id)) AS VARCHAR), ' duplicate customer_id records')
         ELSE 'No duplicates found' END AS error_details,
    CURRENT_TIMESTAMP() AS assessment_date
FROM ecommerce.customers

UNION ALL

SELECT
    'DQ004' AS rule_id, 'orders' AS table_name, 'total_amount' AS column_name,
    'RANGE_CHECK' AS rule_type,
    COUNT(*) AS total_records,
    COUNT(CASE WHEN total_amount <= 0 THEN 1 END) AS failed_records,
    COUNT(CASE WHEN total_amount <= 0 THEN 1 END) * 100.0 / COUNT(*) AS failure_rate,
    1.0 AS threshold_value,
    CASE WHEN COUNT(CASE WHEN total_amount <= 0 THEN 1 END) * 100.0 / COUNT(*) <= 1.0 THEN 'PASS' ELSE 'FAIL' END AS status,
    'CRITICAL' AS severity,
    CASE WHEN COUNT(CASE WHEN total_amount <= 0 THEN 1 END) > 0
         THEN CONCAT('Found ', CAST(COUNT(CASE WHEN total_amount <= 0 THEN 1 END) AS VARCHAR), ' orders with non-positive amounts')
         ELSE 'All order amounts are positive' END AS error_details,
    CURRENT_TIMESTAMP() AS assessment_date
FROM ecommerce.orders

UNION ALL

SELECT
    'DQ005' AS rule_id, 'products' AS table_name, 'price' AS column_name,
    'RANGE_CHECK' AS rule_type,
    COUNT(*) AS total_records,
    COUNT(CASE WHEN price <= cost THEN 1 END) AS failed_records,
    COUNT(CASE WHEN price <= cost THEN 1 END) * 100.0 / COUNT(*) AS failure_rate,
    2.0 AS threshold_value,
    CASE WHEN COUNT(CASE WHEN price <= cost THEN 1 END) * 100.0 / COUNT(*) <= 2.0 THEN 'PASS' ELSE 'WARNING' END AS status,
    'WARNING' AS severity,
    CASE WHEN COUNT(CASE WHEN price <= cost THEN 1 END) > 0
         THEN CONCAT('Found ', CAST(COUNT(CASE WHEN price <= cost THEN 1 END) AS VARCHAR), ' products where price <= cost')
         ELSE 'All product prices are above cost' END AS error_details,
    CURRENT_TIMESTAMP() AS assessment_date
FROM ecommerce.products

UNION ALL

SELECT
    'DQ006' AS rule_id, 'orders' AS table_name, 'customer_id' AS column_name,
    'REFERENTIAL_CHECK' AS rule_type,
    COUNT(*) AS total_records,
    COUNT(CASE WHEN c.customer_id IS NULL THEN 1 END) AS failed_records,
    COUNT(CASE WHEN c.customer_id IS NULL THEN 1 END) * 100.0 / COUNT(*) AS failure_rate,
    0.0 AS threshold_value,
    CASE WHEN COUNT(CASE WHEN c.customer_id IS NULL THEN 1 END) = 0 THEN 'PASS' ELSE 'FAIL' END AS status,
    'CRITICAL' AS severity,
    CASE WHEN COUNT(CASE WHEN c.customer_id IS NULL THEN 1 END) > 0
         THEN CONCAT('Found ', CAST(COUNT(CASE WHEN c.customer_id IS NULL THEN 1 END) AS VARCHAR), ' orders with invalid customer_id')
         ELSE 'All orders have valid customer references' END AS error_details,
    CURRENT_TIMESTAMP() AS assessment_date
FROM ecommerce.orders o
LEFT JOIN ecommerce.customers c ON o.customer_id = c.customer_id;
