-- MaxCompute Table Creation Scripts
-- Run these scripts in order to set up your practice environment

-- 1. Create Customers Table
DROP TABLE IF EXISTS customers;
CREATE TABLE customers (
    customer_id STRING,
    first_name STRING,
    last_name STRING,
    email STRING,
    phone STRING,
    registration_date DATETIME,
    country STRING,
    city STRING,
    age_group STRING
)
COMMENT 'Customer master data'
LIFECYCLE 365; -- Data retention: 1 year

-- 2. Create Products Table  
DROP TABLE IF EXISTS products;
CREATE TABLE products (
    product_id STRING,
    product_name STRING,
    category STRING,
    sub_category STRING,
    brand STRING,
    price DOUBLE,
    cost DOUBLE,
    supplier_id STRING,
    launch_date DATETIME
)
COMMENT 'Product catalog'
LIFECYCLE 365;

-- 3. Create Orders Table
DROP TABLE IF EXISTS orders;
CREATE TABLE orders (
    order_id STRING,
    customer_id STRING,
    order_date DATETIME,
    order_status STRING,
    total_amount DOUBLE,
    shipping_cost DOUBLE,
    payment_method STRING,
    shipping_address STRING
)
PARTITIONED BY (ds STRING) -- Partition by date for better performance
COMMENT 'Order transactions'
LIFECYCLE 365;

-- 4. Create Order Items Table
DROP TABLE IF EXISTS order_items;
CREATE TABLE order_items (
    order_item_id STRING,
    order_id STRING,
    product_id STRING,
    quantity BIGINT,
    unit_price DOUBLE,
    discount_amount DOUBLE,
    line_total DOUBLE
)
PARTITIONED BY (ds STRING)
COMMENT 'Order line items detail'
LIFECYCLE 365;

-- 5. Create Web Sessions Table for Analytics
DROP TABLE IF EXISTS web_sessions;
CREATE TABLE web_sessions (
    session_id STRING,
    user_id STRING,
    session_start DATETIME,
    session_end DATETIME,
    page_views BIGINT,
    session_duration_seconds BIGINT,
    traffic_source STRING,
    device_type STRING,
    browser STRING,
    country STRING
)
PARTITIONED BY (ds STRING)
COMMENT 'Web analytics session data'
LIFECYCLE 90; -- Shorter retention for web data