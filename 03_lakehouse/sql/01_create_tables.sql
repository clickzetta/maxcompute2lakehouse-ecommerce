-- Lakehouse ODS 层建表
-- 对应 01_source/sql/01_create_tables.sql
-- 主要差异：去掉 LIFECYCLE，去掉 COMMENT（可选），分区语法保持不变

CREATE SCHEMA IF NOT EXISTS ecommerce;

DROP TABLE IF EXISTS ecommerce.customers;
CREATE TABLE ecommerce.customers (
    customer_id   STRING,
    first_name    STRING,
    last_name     STRING,
    email         STRING,
    phone         STRING,
    registration_date TIMESTAMP,
    country       STRING,
    city          STRING,
    age_group     STRING
);

DROP TABLE IF EXISTS ecommerce.products;
CREATE TABLE ecommerce.products (
    product_id    STRING,
    product_name  STRING,
    category      STRING,
    sub_category  STRING,
    brand         STRING,
    price         DOUBLE,
    cost          DOUBLE,
    supplier_id   STRING,
    launch_date   TIMESTAMP
);

DROP TABLE IF EXISTS ecommerce.orders;
CREATE TABLE ecommerce.orders (
    order_id         STRING,
    customer_id      STRING,
    order_date       TIMESTAMP,
    order_status     STRING,
    total_amount     DOUBLE,
    shipping_cost    DOUBLE,
    payment_method   STRING,
    shipping_address STRING
)
PARTITIONED BY (ds STRING);

DROP TABLE IF EXISTS ecommerce.order_items;
CREATE TABLE ecommerce.order_items (
    order_item_id   STRING,
    order_id        STRING,
    product_id      STRING,
    quantity        BIGINT,
    unit_price      DOUBLE,
    discount_amount DOUBLE,
    line_total      DOUBLE
)
PARTITIONED BY (ds STRING);

DROP TABLE IF EXISTS ecommerce.web_sessions;
CREATE TABLE ecommerce.web_sessions (
    session_id               STRING,
    user_id                  STRING,
    session_start            TIMESTAMP,
    session_end              TIMESTAMP,
    page_views               BIGINT,
    session_duration_seconds BIGINT,
    traffic_source           STRING,
    device_type              STRING,
    browser                  STRING,
    country                  STRING
)
PARTITIONED BY (ds STRING);

DROP TABLE IF EXISTS ecommerce.page_views;
CREATE TABLE ecommerce.page_views (
    view_id      STRING,
    session_id   STRING,
    user_id      STRING,
    page_url     STRING,
    view_time    TIMESTAMP,
    time_on_page BIGINT,
    referrer_url STRING
)
PARTITIONED BY (ds STRING);

DROP TABLE IF EXISTS ecommerce.user_events;
CREATE TABLE ecommerce.user_events (
    event_id    STRING,
    user_id     STRING,
    event_type  STRING,
    event_time  TIMESTAMP,
    page_url    STRING,
    element_id  STRING,
    event_value STRING
)
PARTITIONED BY (ds STRING);

DROP TABLE IF EXISTS ecommerce.suppliers;
CREATE TABLE ecommerce.suppliers (
    supplier_id      STRING,
    supplier_name    STRING,
    contact_name     STRING,
    email            STRING,
    phone            STRING,
    country          STRING,
    city             STRING,
    product_category STRING,
    rating           DOUBLE
);
