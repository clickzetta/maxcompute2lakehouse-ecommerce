-- Lakehouse ODS 层数据加载
-- 对应 01_source/sql/02_load_data.sql
-- 使用 COPY INTO FROM VOLUME，替代 MaxCompute 的 LOAD DATA INPATH (OSS)

-- 前置：setup.py 已将 data/ 目录下的 CSV 上传到 Volume
-- Volume 路径：vol://ecommerce.ecommerce_vol/raw/

COPY INTO ecommerce.customers
FROM VOLUME ecommerce.ecommerce_vol
FILES = ('raw/customers.csv')
FILE_FORMAT = (
    TYPE = 'CSV'
    FIELD_DELIMITER = ','
    SKIP_HEADER = 1
    NULL_IF = ('', 'NULL', 'null')
);

COPY INTO ecommerce.products
FROM VOLUME ecommerce.ecommerce_vol
FILES = ('raw/products.csv')
FILE_FORMAT = (
    TYPE = 'CSV'
    FIELD_DELIMITER = ','
    SKIP_HEADER = 1
    NULL_IF = ('', 'NULL', 'null')
);

COPY INTO ecommerce.orders
PARTITION (ds = '20240115')
FROM VOLUME ecommerce.ecommerce_vol
FILES = ('raw/orders.csv')
FILE_FORMAT = (
    TYPE = 'CSV'
    FIELD_DELIMITER = ','
    SKIP_HEADER = 1
    NULL_IF = ('', 'NULL', 'null')
);

COPY INTO ecommerce.order_items
PARTITION (ds = '20240115')
FROM VOLUME ecommerce.ecommerce_vol
FILES = ('raw/order_items.csv')
FILE_FORMAT = (
    TYPE = 'CSV'
    FIELD_DELIMITER = ','
    SKIP_HEADER = 1
    NULL_IF = ('', 'NULL', 'null')
);

COPY INTO ecommerce.web_sessions
PARTITION (ds = '20240115')
FROM VOLUME ecommerce.ecommerce_vol
FILES = ('raw/web_sessions.csv')
FILE_FORMAT = (
    TYPE = 'CSV'
    FIELD_DELIMITER = ','
    SKIP_HEADER = 1
    NULL_IF = ('', 'NULL', 'null')
);

COPY INTO ecommerce.page_views
PARTITION (ds = '20240115')
FROM VOLUME ecommerce.ecommerce_vol
FILES = ('raw/page_views.csv')
FILE_FORMAT = (
    TYPE = 'CSV'
    FIELD_DELIMITER = ','
    SKIP_HEADER = 1
    NULL_IF = ('', 'NULL', 'null')
);

COPY INTO ecommerce.user_events
PARTITION (ds = '20240115')
FROM VOLUME ecommerce.ecommerce_vol
FILES = ('raw/user_events.csv')
FILE_FORMAT = (
    TYPE = 'CSV'
    FIELD_DELIMITER = ','
    SKIP_HEADER = 1
    NULL_IF = ('', 'NULL', 'null')
);

COPY INTO ecommerce.suppliers
FROM VOLUME ecommerce.ecommerce_vol
FILES = ('raw/suppliers.csv')
FILE_FORMAT = (
    TYPE = 'CSV'
    FIELD_DELIMITER = ','
    SKIP_HEADER = 1
    NULL_IF = ('', 'NULL', 'null')
);
