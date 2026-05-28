-- Lakehouse DWD 层建表（CREATE TABLE 只建结构，不插入数据）
-- 数据填充见 04_dwd_transform.sql
-- 对应 01_source/sql/05_etl_workflows.sql 中的目标表定义
--   LIFECYCLE  → 删除
--   DATETIME   → TIMESTAMP

CREATE SCHEMA IF NOT EXISTS ecommerce_dwd;

-- 1. 每日销售汇总
DROP TABLE IF EXISTS ecommerce_dwd.daily_sales_summary;
CREATE TABLE ecommerce_dwd.daily_sales_summary (
    sales_date       STRING,
    total_orders     BIGINT,
    total_revenue    DOUBLE,
    total_customers  BIGINT,
    avg_order_value  DOUBLE,
    top_category     STRING,
    top_product_id   STRING
)
PARTITIONED BY (ds STRING);

-- 2. 客户分层
DROP TABLE IF EXISTS ecommerce_dwd.customer_segments;
CREATE TABLE ecommerce_dwd.customer_segments (
    customer_id           STRING,
    segment_type          STRING,
    segment_value         STRING,
    total_orders          BIGINT,
    total_spent           DOUBLE,
    avg_order_value       DOUBLE,
    days_since_last_order BIGINT,
    segment_score         DOUBLE,
    updated_date          TIMESTAMP
)
PARTITIONED BY (ds STRING);

-- 3. 商品表现
DROP TABLE IF EXISTS ecommerce_dwd.product_performance;
CREATE TABLE ecommerce_dwd.product_performance (
    product_id          STRING,
    product_name        STRING,
    category            STRING,
    total_quantity_sold BIGINT,
    total_revenue       DOUBLE,
    total_profit        DOUBLE,
    profit_margin_pct   DOUBLE,
    orders_count        BIGINT,
    unique_customers    BIGINT,
    avg_selling_price   DOUBLE,
    performance_rank    BIGINT,
    performance_tier    STRING,
    analysis_date       TIMESTAMP
)
PARTITIONED BY (ds STRING);
