-- Data Quality Checks and Cleansing for MaxCompute
-- Comprehensive data quality framework with detection, cleansing, and monitoring

-- =============================================
-- 1. DATA QUALITY RULES CONFIGURATION
-- =============================================

-- Create data quality rules configuration table
DROP TABLE IF EXISTS dq_rules;
CREATE TABLE dq_rules (
    rule_id STRING,
    table_name STRING,
    column_name STRING,
    rule_type STRING, -- NULL_CHECK, RANGE_CHECK, FORMAT_CHECK, UNIQUENESS_CHECK, REFERENTIAL_CHECK
    rule_definition STRING,
    threshold_value DOUBLE,
    severity STRING, -- CRITICAL, WARNING, INFO
    active BOOLEAN,
    created_date DATETIME
)
COMMENT 'Data quality rules configuration'
LIFECYCLE 365;

-- Insert sample data quality rules
INSERT INTO dq_rules VALUES
('DQ001', 'customers', 'customer_id', 'NULL_CHECK', 'customer_id IS NOT NULL', 0.0, 'CRITICAL', true, GETDATE()),
('DQ002', 'customers', 'email', 'FORMAT_CHECK', 'email RLIKE "^[A-Za-z0-9+_.-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"', 5.0, 'WARNING', true, GETDATE()),
('DQ003', 'customers', 'customer_id', 'UNIQUENESS_CHECK', 'COUNT(customer_id) = COUNT(DISTINCT customer_id)', 0.0, 'CRITICAL', true, GETDATE()),
('DQ004', 'orders', 'total_amount', 'RANGE_CHECK', 'total_amount > 0', 1.0, 'CRITICAL', true, GETDATE()),
('DQ005', 'products', 'price', 'RANGE_CHECK', 'price > cost', 2.0, 'WARNING', true, GETDATE()),
('DQ006', 'orders', 'customer_id', 'REFERENTIAL_CHECK', 'customer_id EXISTS IN customers', 0.0, 'CRITICAL', true, GETDATE());

-- =============================================
-- 2. DATA PROFILING FUNCTIONS
-- =============================================

-- Create data profiling results table
DROP TABLE IF EXISTS data_profile;
CREATE TABLE data_profile (
    table_name STRING,
    column_name STRING,
    data_type STRING,
    total_records BIGINT,
    null_count BIGINT,
    null_percentage DOUBLE,
    distinct_count BIGINT,
    min_value STRING,
    max_value STRING,
    avg_value DOUBLE,
    std_dev DOUBLE,
    profile_date DATETIME
)
PARTITIONED BY (ds STRING)
COMMENT 'Data profiling results'
LIFECYCLE 90;

-- Data profiling for customers table
INSERT INTO data_profile PARTITION (ds = '${bizdate}')
SELECT 
    'customers' as table_name,
    'customer_id' as column_name,
    'STRING' as data_type,
    COUNT(*) as total_records,
    COUNT(CASE WHEN customer_id IS NULL THEN 1 END) as null_count,
    (COUNT(CASE WHEN customer_id IS NULL THEN 1 END) * 100.0 / COUNT(*)) as null_percentage,
    COUNT(DISTINCT customer_id) as distinct_count,
    MIN(customer_id) as min_value,
    MAX(customer_id) as max_value,
    NULL as avg_value,
    NULL as std_dev,
    GETDATE() as profile_date
FROM customers

UNION ALL

SELECT 
    'customers' as table_name,
    'email' as column_name,
    'STRING' as data_type,
    COUNT(*) as total_records,
    COUNT(CASE WHEN email IS NULL THEN 1 END) as null_count,
    (COUNT(CASE WHEN email IS NULL THEN 1 END) * 100.0 / COUNT(*)) as null_percentage,
    COUNT(DISTINCT email) as distinct_count,
    MIN(email) as min_value,
    MAX(email) as max_value,
    NULL as avg_value,
    NULL as std_dev,
    GETDATE() as profile_date
FROM customers

UNION ALL

SELECT 
    'orders' as table_name,
    'total_amount' as column_name,
    'DOUBLE' as data_type,
    COUNT(*) as total_records,
    COUNT(CASE WHEN total_amount IS NULL THEN 1 END) as null_count,
    (COUNT(CASE WHEN total_amount IS NULL THEN 1 END) * 100.0 / COUNT(*)) as null_percentage,
    COUNT(DISTINCT total_amount) as distinct_count,
    CAST(MIN(total_amount) as STRING) as min_value,
    CAST(MAX(total_amount) as STRING) as max_value,
    AVG(total_amount) as avg_value,
    STDDEV(total_amount) as std_dev,
    GETDATE() as profile_date
FROM orders;

-- =============================================
-- 3. DATA QUALITY ASSESSMENT
-- =============================================

-- Create data quality assessment results table
DROP TABLE IF EXISTS dq_assessment;
CREATE TABLE dq_assessment (
    rule_id STRING,
    table_name STRING,
    column_name STRING,
    rule_type STRING,
    total_records BIGINT,
    failed_records BIGINT,
    failure_rate DOUBLE,
    threshold_value DOUBLE,
    status STRING, -- PASS, FAIL, WARNING
    severity STRING,
    error_details STRING,
    assessment_date DATETIME
)
PARTITIONED BY (ds STRING)
COMMENT 'Data quality assessment results'
LIFECYCLE 90;

-- Execute data quality checks
INSERT INTO dq_assessment PARTITION (ds = '${bizdate}')
-- NULL checks for customer_id
SELECT 
    'DQ001' as rule_id,
    'customers' as table_name,
    'customer_id' as column_name,
    'NULL_CHECK' as rule_type,
    COUNT(*) as total_records,
    COUNT(CASE WHEN customer_id IS NULL THEN 1 END) as failed_records,
    (COUNT(CASE WHEN customer_id IS NULL THEN 1 END) * 100.0 / COUNT(*)) as failure_rate,
    0.0 as threshold_value,
    CASE 
        WHEN COUNT(CASE WHEN customer_id IS NULL THEN 1 END) = 0 THEN 'PASS'
        ELSE 'FAIL'
    END as status,
    'CRITICAL' as severity,
    CASE 
        WHEN COUNT(CASE WHEN customer_id IS NULL THEN 1 END) > 0 
        THEN CONCAT('Found ', CAST(COUNT(CASE WHEN customer_id IS NULL THEN 1 END) as STRING), ' null customer_id records')
        ELSE 'No null values found'
    END as error_details,
    GETDATE() as assessment_date
FROM customers

UNION ALL

-- Email format validation
SELECT 
    'DQ002' as rule_id,
    'customers' as table_name,
    'email' as column_name,
    'FORMAT_CHECK' as rule_type,
    COUNT(*) as total_records,
    COUNT(CASE WHEN email IS NOT NULL AND email NOT RLIKE '^[A-Za-z0-9+_.-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$' THEN 1 END) as failed_records,
    (COUNT(CASE WHEN email IS NOT NULL AND email NOT RLIKE '^[A-Za-z0-9+_.-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$' THEN 1 END) * 100.0 / COUNT(*)) as failure_rate,
    5.0 as threshold_value,
    CASE 
        WHEN (COUNT(CASE WHEN email IS NOT NULL AND email NOT RLIKE '^[A-Za-z0-9+_.-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$' THEN 1 END) * 100.0 / COUNT(*)) <= 5.0 THEN 'PASS'
        ELSE 'WARNING'
    END as status,
    'WARNING' as severity,
    CASE 
        WHEN COUNT(CASE WHEN email IS NOT NULL AND email NOT RLIKE '^[A-Za-z0-9+_.-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$' THEN 1 END) > 0 
        THEN CONCAT('Found ', CAST(COUNT(CASE WHEN email IS NOT NULL AND email NOT RLIKE '^[A-Za-z0-9+_.-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$' THEN 1 END) as STRING), ' invalid email formats')
        ELSE 'All email formats are valid'
    END as error_details,
    GETDATE() as assessment_date
FROM customers

UNION ALL

-- Uniqueness check for customer_id
SELECT 
    'DQ003' as rule_id,
    'customers' as table_name,
    'customer_id' as column_name,
    'UNIQUENESS_CHECK' as rule_type,
    COUNT(*) as total_records,
    (COUNT(*) - COUNT(DISTINCT customer_id)) as failed_records,
    ((COUNT(*) - COUNT(DISTINCT customer_id)) * 100.0 / COUNT(*)) as failure_rate,
    0.0 as threshold_value,
    CASE 
        WHEN COUNT(*) = COUNT(DISTINCT customer_id) THEN 'PASS'
        ELSE 'FAIL'
    END as status,
    'CRITICAL' as severity,
    CASE 
        WHEN COUNT(*) != COUNT(DISTINCT customer_id) 
        THEN CONCAT('Found ', CAST((COUNT(*) - COUNT(DISTINCT customer_id)) as STRING), ' duplicate customer_id records')
        ELSE 'All customer_id values are unique'
    END as error_details,
    GETDATE() as assessment_date
FROM customers

UNION ALL

-- Range check for order amounts
SELECT 
    'DQ004' as rule_id,
    'orders' as table_name,
    'total_amount' as column_name,
    'RANGE_CHECK' as rule_type,
    COUNT(*) as total_records,
    COUNT(CASE WHEN total_amount <= 0 THEN 1 END) as failed_records,
    (COUNT(CASE WHEN total_amount <= 0 THEN 1 END) * 100.0 / COUNT(*)) as failure_rate,
    1.0 as threshold_value,
    CASE 
        WHEN (COUNT(CASE WHEN total_amount <= 0 THEN 1 END) * 100.0 / COUNT(*)) <= 1.0 THEN 'PASS'
        ELSE 'FAIL'
    END as status,
    'CRITICAL' as severity,
    CASE 
        WHEN COUNT(CASE WHEN total_amount <= 0 THEN 1 END) > 0 
        THEN CONCAT('Found ', CAST(COUNT(CASE WHEN total_amount <= 0 THEN 1 END) as STRING), ' orders with non-positive amounts')
        ELSE 'All order amounts are positive'
    END as error_details,
    GETDATE() as assessment_date
FROM orders

UNION ALL

-- Price vs cost validation
SELECT 
    'DQ005' as rule_id,
    'products' as table_name,
    'price' as column_name,
    'RANGE_CHECK' as rule_type,
    COUNT(*) as total_records,
    COUNT(CASE WHEN price <= cost THEN 1 END) as failed_records,
    (COUNT(CASE WHEN price <= cost THEN 1 END) * 100.0 / COUNT(*)) as failure_rate,
    2.0 as threshold_value,
    CASE 
        WHEN (COUNT(CASE WHEN price <= cost THEN 1 END) * 100.0 / COUNT(*)) <= 2.0 THEN 'PASS'
        ELSE 'WARNING'
    END as status,
    'WARNING' as severity,
    CASE 
        WHEN COUNT(CASE WHEN price <= cost THEN 1 END) > 0 
        THEN CONCAT('Found ', CAST(COUNT(CASE WHEN price <= cost THEN 1 END) as STRING), ' products with price <= cost')
        ELSE 'All product prices are greater than cost'
    END as error_details,
    GETDATE() as assessment_date
FROM products;

-- =============================================
-- 4. DATA CLEANSING FUNCTIONS
-- =============================================

-- Create cleansed customers table
DROP TABLE IF EXISTS customers_clean;
CREATE TABLE customers_clean (
    customer_id STRING,
    first_name STRING,
    last_name STRING,
    email STRING,
    email_clean STRING,
    phone STRING,
    phone_clean STRING,
    registration_date DATETIME,
    country STRING,
    country_clean STRING,
    city STRING,
    city_clean STRING,
    age_group STRING,
    cleansing_flags STRING,
    cleansed_date DATETIME
)
COMMENT 'Cleansed customer data with quality improvements'
LIFECYCLE 365;

-- Data cleansing process
INSERT OVERWRITE TABLE customers_clean
SELECT 
    customer_id,
    TRIM(first_name) as first_name,
    TRIM(last_name) as last_name,
    email,
    
    -- Email cleansing: lowercase, trim, validate format
    CASE 
        WHEN email IS NULL THEN NULL
        WHEN email RLIKE '^[A-Za-z0-9+_.-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$' THEN LOWER(TRIM(email))
        ELSE NULL  -- Invalid emails set to NULL
    END as email_clean,
    
    phone,
    
    -- Phone cleansing: remove special characters, standardize format
    CASE 
        WHEN phone IS NULL THEN NULL
        ELSE REGEXP_REPLACE(REGEXP_REPLACE(phone, '[^0-9+]', ''), '^\\+?1?', '+1-')
    END as phone_clean,
    
    registration_date,
    country,
    
    -- Country standardization
    CASE 
        WHEN UPPER(TRIM(country)) IN ('US', 'USA', 'UNITED STATES') THEN 'USA'
        WHEN UPPER(TRIM(country)) IN ('UK', 'UNITED KINGDOM', 'BRITAIN') THEN 'UK'
        WHEN UPPER(TRIM(country)) IN ('CHINA', 'CN') THEN 'China'
        WHEN UPPER(TRIM(country)) IN ('CANADA', 'CA') THEN 'Canada'
        ELSE TRIM(country)
    END as country_clean,
    
    city,
    TRIM(INITCAP(city)) as city_clean,  -- Proper case for city names
    age_group,
    
    -- Cleansing flags to track what was cleaned
    CONCAT_WS('|',
        CASE WHEN email != LOWER(TRIM(email)) THEN 'EMAIL_FORMATTED' END,
        CASE WHEN email IS NOT NULL AND email NOT RLIKE '^[A-Za-z0-9+_.-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$' THEN 'EMAIL_INVALID' END,
        CASE WHEN phone != REGEXP_REPLACE(REGEXP_REPLACE(phone, '[^0-9+]', ''), '^\\+?1?', '+1-') THEN 'PHONE_FORMATTED' END,
        CASE WHEN country != TRIM(country) THEN 'COUNTRY_TRIMMED' END,
        CASE WHEN city != TRIM(INITCAP(city)) THEN 'CITY_FORMATTED' END
    ) as cleansing_flags,
    
    GETDATE() as cleansed_date
FROM customers;

-- =============================================
-- 5. OUTLIER DETECTION
-- =============================================

-- Create outliers detection table
DROP TABLE IF EXISTS data_outliers;
CREATE TABLE data_outliers (
    table_name STRING,
    column_name STRING,
    record_id STRING,
    value_found STRING,
    outlier_type STRING, -- STATISTICAL, BUSINESS_RULE, PATTERN
    z_score DOUBLE,
    percentile_rank DOUBLE,
    expected_range STRING,
    detection_method STRING,
    severity STRING,
    detected_date DATETIME
)
PARTITIONED BY (ds STRING)
COMMENT 'Outlier detection results'
LIFECYCLE 90;

-- Statistical outlier detection for order amounts
INSERT INTO data_outliers PARTITION (ds = '${bizdate}')
WITH order_stats AS (
    SELECT 
        order_id,
        total_amount,
        AVG(total_amount) OVER() as mean_amount,
        STDDEV(total_amount) OVER() as stddev_amount,
        PERCENTILE(total_amount, 0.25) OVER() as q1,
        PERCENTILE(total_amount, 0.75) OVER() as q3,
        PERCENT_RANK() OVER(ORDER BY total_amount) as percentile_rank
    FROM orders
    WHERE total_amount IS NOT NULL
),
outlier_detection AS (
    SELECT 
        *,
        (total_amount - mean_amount) / stddev_amount as z_score,
        q3 + 1.5 * (q3 - q1) as upper_fence,
        q1 - 1.5 * (q3 - q1) as lower_fence
    FROM order_stats
)
SELECT 
    'orders' as table_name,
    'total_amount' as column_name,
    order_id as record_id,
    CAST(total_amount as STRING) as value_found,
    CASE 
        WHEN ABS(z_score) > 3 THEN 'STATISTICAL'
        WHEN total_amount > upper_fence OR total_amount < lower_fence THEN 'IQR_OUTLIER'
        ELSE 'BUSINESS_RULE'
    END as outlier_type,
    z_score,
    percentile_rank,
    CONCAT('Expected range: ', CAST(ROUND(lower_fence, 2) as STRING), ' - ', CAST(ROUND(upper_fence, 2) as STRING)) as expected_range,
    'Z-Score and IQR Analysis' as detection_method,
    CASE 
        WHEN ABS(z_score) > 3 THEN 'HIGH'
        WHEN ABS(z_score) > 2 THEN 'MEDIUM'
        ELSE 'LOW'
    END as severity,
    GETDATE() as detected_date
FROM outlier_detection
WHERE ABS(z_score) > 2 OR total_amount > upper_fence OR total_amount < lower_fence;

-- =============================================
-- 6. DATA QUALITY DASHBOARD QUERIES
-- =============================================

-- Overall data quality score by table
SELECT 
    table_name,
    COUNT(*) as total_rules,
    COUNT(CASE WHEN status = 'PASS' THEN 1 END) as passed_rules,
    COUNT(CASE WHEN status = 'FAIL' THEN 1 END) as failed_rules,
    COUNT(CASE WHEN status = 'WARNING' THEN 1 END) as warning_rules,
    ROUND((COUNT(CASE WHEN status = 'PASS' THEN 1 END) * 100.0 / COUNT(*)), 2) as quality_score_pct
FROM dq_assessment
WHERE ds = '${bizdate}'
GROUP BY table_name
ORDER BY quality_score_pct DESC;

-- Data quality trends over time
SELECT 
    ds,
    COUNT(*) as total_checks,
    COUNT(CASE WHEN status = 'PASS' THEN 1 END) as passed_checks,
    ROUND((COUNT(CASE WHEN status = 'PASS' THEN 1 END) * 100.0 / COUNT(*)), 2) as daily_quality_score
FROM dq_assessment
WHERE ds >= DATE_SUB('${bizdate}', 7)  -- Last 7 days
GROUP BY ds
ORDER BY ds;

-- Critical issues requiring immediate attention
SELECT 
    rule_id,
    table_name,
    column_name,
    rule_type,
    failed_records,
    failure_rate,
    error_details,
    assessment_date
FROM dq_assessment
WHERE ds = '${bizdate}'
  AND severity = 'CRITICAL'
  AND status = 'FAIL'
ORDER BY failure_rate DESC;

-- =============================================
-- 7. AUTOMATED DATA QUALITY REPORTING
-- =============================================

-- Create data quality summary report
DROP TABLE IF EXISTS dq_daily_report;
CREATE TABLE dq_daily_report (
    report_date STRING,
    overall_quality_score DOUBLE,
    total_tables_checked BIGINT,
    total_rules_executed BIGINT,
    critical_issues BIGINT,
    warning_issues BIGINT,
    top_issue_table STRING,
    top_issue_description STRING,
    outliers_detected BIGINT,
    records_processed BIGINT,
    recommendations STRING
)
PARTITIONED BY (ds STRING)
COMMENT 'Daily data quality summary report'
LIFECYCLE 365;

-- Generate daily quality report
INSERT OVERWRITE TABLE dq_daily_report PARTITION (ds = '${bizdate}')
WITH quality_summary AS (
    SELECT 
        COUNT(DISTINCT table_name) as tables_checked,
        COUNT(*) as rules_executed,
        COUNT(CASE WHEN status = 'PASS' THEN 1 END) as passed_rules,
        COUNT(CASE WHEN severity = 'CRITICAL' AND status = 'FAIL' THEN 1 END) as critical_issues,
        COUNT(CASE WHEN severity = 'WARNING' AND status != 'PASS' THEN 1 END) as warning_issues
    FROM dq_assessment
    WHERE ds = '${bizdate}'
),
top_issue AS (
    SELECT 
        table_name,
        error_details,
        failure_rate,
        ROW_NUMBER() OVER (ORDER BY failure_rate DESC) as rn
    FROM dq_assessment
    WHERE ds = '${bizdate}' AND status = 'FAIL'
),
outlier_count AS (
    SELECT COUNT(*) as outliers_detected
    FROM data_outliers
    WHERE ds = '${bizdate}'
)
SELECT 
    '${bizdate}' as report_date,
    ROUND((qs.passed_rules * 100.0 / qs.rules_executed), 2) as overall_quality_score,
    qs.tables_checked as total_tables_checked,
    qs.rules_executed as total_rules_executed,
    qs.critical_issues,
    qs.warning_issues,
    COALESCE(ti.table_name, 'None') as top_issue_table,
    COALESCE(ti.error_details, 'No critical issues found') as top_issue_description,
    COALESCE(oc.outliers_detected, 0) as outliers_detected,
    (SELECT SUM(total_records) FROM dq_assessment WHERE ds = '${bizdate}') as records_processed,
    CASE 
        WHEN qs.critical_issues > 0 THEN 'Address critical data quality issues immediately'
        WHEN qs.warning_issues > 5 THEN 'Review warning issues and update cleansing rules'
        WHEN COALESCE(oc.outliers_detected, 0) > 10 THEN 'Investigate unusual data patterns'
        ELSE 'Data quality is within acceptable thresholds'
    END as recommendations
FROM quality_summary qs
CROSS JOIN outlier_count oc
LEFT JOIN top_issue ti ON ti.rn = 1;

-- =============================================
-- 8. DATA QUALITY ALERTING
-- =============================================

-- Create alerts for critical data quality issues
SELECT 
    'CRITICAL DATA QUALITY ALERT' as alert_type,
    CONCAT('Table: ', table_name, ', Column: ', column_name) as affected_object,
    error_details as issue_description,
    CONCAT(CAST(failure_rate as STRING), '% failure rate') as severity_info,
    'Immediate action required' as recommendation
FROM dq_assessment
WHERE ds = '${bizdate}'
  AND severity = 'CRITICAL'
  AND status = 'FAIL'
  AND failure_rate > 5.0;  -- Alert threshold

-- Usage Instructions:
-- 1. Run data profiling daily to understand data characteristics
-- 2. Execute quality checks as part of ETL process
-- 3. Review daily quality reports and address critical issues
-- 4. Use cleansed data tables for analytics and reporting
-- 5. Monitor trends and adjust quality rules as needed
-- 6. Set up email alerts for critical quality failures in DataWorks