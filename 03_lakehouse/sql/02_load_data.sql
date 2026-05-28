-- Lakehouse ODS 层数据加载
-- 对应 01_source/sql/02_load_data.sql
-- 使用 COPY INTO FROM VOLUME，替代 MaxCompute 的 LOAD DATA INPATH (OSS)
--
-- 前置：setup.py 已将 data/ 目录下的 CSV 上传到 Volume
-- Volume 路径：ecommerce.ecommerce_vol/raw/
--
-- 注意：COPY INTO 需要在 Volume 所在 schema 的上下文中执行
-- setup.py 连接时 schema=ecommerce，与 Volume 同 schema，可直接解析

COPY INTO ecommerce.customers
FROM VOLUME ecommerce.ecommerce_vol
USING CSV
OPTIONS ('header' = 'true')
FILES ('raw/customers.csv');

COPY INTO ecommerce.products
FROM VOLUME ecommerce.ecommerce_vol
USING CSV
OPTIONS ('header' = 'true')
FILES ('raw/products.csv');

COPY INTO ecommerce.orders PARTITION (ds = '20240115')
FROM VOLUME ecommerce.ecommerce_vol
USING CSV
OPTIONS ('header' = 'true')
FILES ('raw/orders.csv');

COPY INTO ecommerce.order_items PARTITION (ds = '20240115')
FROM VOLUME ecommerce.ecommerce_vol
USING CSV
OPTIONS ('header' = 'true')
FILES ('raw/order_items.csv');

COPY INTO ecommerce.web_sessions PARTITION (ds = '20240115')
FROM VOLUME ecommerce.ecommerce_vol
USING CSV
OPTIONS ('header' = 'true')
FILES ('raw/web_sessions.csv');

COPY INTO ecommerce.page_views PARTITION (ds = '20240115')
FROM VOLUME ecommerce.ecommerce_vol
USING CSV
OPTIONS ('header' = 'true')
FILES ('raw/page_views.csv');

COPY INTO ecommerce.user_events PARTITION (ds = '20240115')
FROM VOLUME ecommerce.ecommerce_vol
USING CSV
OPTIONS ('header' = 'true')
FILES ('raw/user_events.csv');

COPY INTO ecommerce.suppliers
FROM VOLUME ecommerce.ecommerce_vol
USING CSV
OPTIONS ('header' = 'true')
FILES ('raw/suppliers.csv');
