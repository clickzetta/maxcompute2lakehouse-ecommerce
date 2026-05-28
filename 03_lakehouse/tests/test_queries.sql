-- Lakehouse 验证测试
-- 对应 01_source/tests/test_queries.sql
-- 迁移变更：
--   RLIKE              → REGEXP
--   schema 前缀         → ecommerce.<table>
--   日期列 CAST          → CAST(col AS TIMESTAMP) / CAST(col AS DATE)

-- =============================================
-- 基础验证测试
-- =============================================

-- Test 1: 表存在性检查
SELECT
    'Table Existence Check'                                                AS test_name,
    CASE WHEN (SELECT COUNT(*) FROM ecommerce.customers  LIMIT 1) >= 0 THEN 'PASS' ELSE 'FAIL' END AS customers_test,
    CASE WHEN (SELECT COUNT(*) FROM ecommerce.products   LIMIT 1) >= 0 THEN 'PASS' ELSE 'FAIL' END AS products_test,
    CASE WHEN (SELECT COUNT(*) FROM ecommerce.orders     LIMIT 1) >= 0 THEN 'PASS' ELSE 'FAIL' END AS orders_test;

-- Test 2: 数据行数验证
SELECT
    'Data Count Validation'                          AS test_name,
    (SELECT COUNT(*) FROM ecommerce.customers)       AS customer_count,
    (SELECT COUNT(*) FROM ecommerce.products)        AS product_count,
    (SELECT COUNT(*) FROM ecommerce.orders)          AS order_count,
    (SELECT COUNT(*) FROM ecommerce.order_items)     AS order_items_count;

-- Test 3: 主键 NULL 检查
SELECT
    'Null Key Check'                                                           AS test_name,
    (SELECT COUNT(*) FROM ecommerce.customers  WHERE customer_id IS NULL)      AS null_customer_ids,
    (SELECT COUNT(*) FROM ecommerce.products   WHERE product_id  IS NULL)      AS null_product_ids,
    (SELECT COUNT(*) FROM ecommerce.orders     WHERE order_id    IS NULL)      AS null_order_ids;

-- =============================================
-- 数据质量测试
-- =============================================

-- Test 4: Email 格式验证
SELECT
    'Email Validation'                                                                                                                AS test_name,
    COUNT(*)                                                                                                                          AS total_customers,
    COUNT(CASE WHEN email REGEXP '^[A-Za-z0-9+_.-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$' THEN 1 END)                                     AS valid_emails,
    COUNT(CASE WHEN NOT (email REGEXP '^[A-Za-z0-9+_.-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$') OR email IS NULL THEN 1 END)              AS invalid_emails
FROM ecommerce.customers;

-- Test 5: 商品价格验证
SELECT
    'Price Validation'                                                                    AS test_name,
    COUNT(*)                                                                              AS total_products,
    COUNT(CASE WHEN price > 0 AND cost > 0 AND price > cost THEN 1 END)                  AS valid_pricing,
    COUNT(CASE WHEN price <= 0 OR cost <= 0 OR price <= cost THEN 1 END)                 AS invalid_pricing
FROM ecommerce.products;

-- Test 6: 订单金额验证
SELECT
    'Order Amount Validation'                                    AS test_name,
    COUNT(*)                                                     AS total_orders,
    COUNT(CASE WHEN total_amount > 0  THEN 1 END)                AS positive_amounts,
    COUNT(CASE WHEN total_amount <= 0 THEN 1 END)                AS non_positive_amounts,
    MIN(total_amount)                                            AS min_amount,
    MAX(total_amount)                                            AS max_amount,
    AVG(total_amount)                                            AS avg_amount
FROM ecommerce.orders;

-- =============================================
-- 参照完整性测试
-- =============================================

-- Test 7: 孤立订单检查（订单无对应客户）
SELECT
    'Orphaned Orders Check'                                      AS test_name,
    COUNT(*)                                                     AS total_orders,
    COUNT(c.customer_id)                                         AS orders_with_valid_customers,
    COUNT(*) - COUNT(c.customer_id)                              AS orphaned_orders
FROM ecommerce.orders o
LEFT JOIN ecommerce.customers c ON o.customer_id = c.customer_id;

-- Test 8: 孤立订单明细检查
SELECT
    'Orphaned Order Items Check'                                 AS test_name,
    COUNT(*)                                                     AS total_order_items,
    COUNT(o.order_id)                                            AS items_with_valid_orders,
    COUNT(*) - COUNT(o.order_id)                                 AS orphaned_items
FROM ecommerce.order_items oi
LEFT JOIN ecommerce.orders o ON oi.order_id = o.order_id;

-- Test 9: 订单总额与明细一致性
WITH order_totals AS (
    SELECT
        o.order_id,
        o.total_amount                              AS order_total,
        COALESCE(SUM(oi.line_total), 0)             AS calculated_total,
        ABS(o.total_amount - COALESCE(SUM(oi.line_total), 0)) AS difference
    FROM ecommerce.orders o
    LEFT JOIN ecommerce.order_items oi ON o.order_id = oi.order_id
    GROUP BY o.order_id, o.total_amount
)
SELECT
    'Order Total Verification'                                   AS test_name,
    COUNT(*)                                                     AS total_orders,
    COUNT(CASE WHEN difference < 0.01 THEN 1 END)               AS matching_totals,
    COUNT(CASE WHEN difference >= 0.01 THEN 1 END)              AS mismatched_totals,
    MAX(difference)                                              AS max_difference
FROM order_totals;

-- Test 10: 日期范围合理性
SELECT
    'Date Range Validation'                                                                AS test_name,
    MIN(registration_date)                                                                 AS earliest_registration,
    MAX(registration_date)                                                                 AS latest_registration,
    MIN(o.order_date)                                                                      AS earliest_order,
    MAX(o.order_date)                                                                      AS latest_order,
    CASE WHEN MIN(o.order_date) >= MIN(c.registration_date) THEN 'PASS' ELSE 'FAIL' END   AS date_logic_check
FROM ecommerce.customers c
CROSS JOIN ecommerce.orders o;

-- =============================================
-- 性能测试
-- =============================================

-- Test 11: 分区裁剪测试
SELECT
    'Partition Pruning Test'                                     AS test_name,
    COUNT(*)                                                     AS records_in_partition,
    'Should execute quickly with partition pruning'              AS note
FROM ecommerce.orders
WHERE ds = '20240115';

-- Test 12: 客户查找测试
SELECT
    'Customer Lookup Test'                                       AS test_name,
    COUNT(DISTINCT customer_id)                                  AS unique_customers,
    'Should execute quickly with proper indexing'                AS note
FROM ecommerce.orders
WHERE customer_id IN ('CUST001', 'CUST002', 'CUST003');

-- =============================================
-- 聚合一致性测试
-- =============================================

-- Test 13: 聚合一致性
WITH summary_stats AS (
    SELECT
        COUNT(DISTINCT customer_id)  AS unique_customers,
        COUNT(DISTINCT order_id)     AS unique_orders,
        SUM(total_amount)            AS total_revenue,
        AVG(total_amount)            AS avg_order_value
    FROM ecommerce.orders
),
detailed_stats AS (
    SELECT
        COUNT(DISTINCT o.customer_id)  AS unique_customers_detailed,
        COUNT(DISTINCT oi.order_id)    AS unique_orders_detailed,
        SUM(oi.line_total)             AS total_revenue_detailed
    FROM ecommerce.order_items oi
    JOIN ecommerce.orders o ON oi.order_id = o.order_id
)
SELECT
    'Aggregation Consistency'                                                              AS test_name,
    s.unique_customers,
    d.unique_customers_detailed,
    s.unique_orders,
    d.unique_orders_detailed,
    ROUND(s.total_revenue, 2)                                                              AS order_total_revenue,
    ROUND(d.total_revenue_detailed, 2)                                                     AS item_total_revenue,
    CASE WHEN ABS(s.total_revenue - d.total_revenue_detailed) < 1 THEN 'PASS' ELSE 'FAIL' END AS revenue_consistency_check
FROM summary_stats s
CROSS JOIN detailed_stats d;

-- =============================================
-- 样本数据验证
-- =============================================

-- Test 14: 数据分布检查
SELECT
    'Data Distribution Check'                                    AS test_name,
    'Customers by Country'                                       AS metric,
    country,
    COUNT(*)                                                     AS count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2)           AS percentage
FROM ecommerce.customers
GROUP BY country
ORDER BY count DESC;

-- Test 15: 商品类别分布
SELECT
    'Product Category Distribution'                              AS test_name,
    category,
    COUNT(*)                                                     AS product_count,
    ROUND(AVG(price), 2)                                         AS avg_price,
    ROUND(MIN(price), 2)                                         AS min_price,
    ROUND(MAX(price), 2)                                         AS max_price
FROM ecommerce.products
GROUP BY category
ORDER BY product_count DESC;

-- Test 16: 整体数据健康汇总
WITH health_metrics AS (
    SELECT
        'customers'  AS table_name,
        COUNT(*)     AS total_records,
        COUNT(CASE WHEN customer_id IS NOT NULL THEN 1 END) AS records_with_key,
        COUNT(CASE WHEN email REGEXP '^[A-Za-z0-9+_.-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$' THEN 1 END) AS quality_records
    FROM ecommerce.customers

    UNION ALL

    SELECT
        'products'   AS table_name,
        COUNT(*)     AS total_records,
        COUNT(CASE WHEN product_id IS NOT NULL THEN 1 END) AS records_with_key,
        COUNT(CASE WHEN price > 0 AND cost > 0 THEN 1 END) AS quality_records
    FROM ecommerce.products

    UNION ALL

    SELECT
        'orders'     AS table_name,
        COUNT(*)     AS total_records,
        COUNT(CASE WHEN order_id IS NOT NULL THEN 1 END)   AS records_with_key,
        COUNT(CASE WHEN total_amount > 0 THEN 1 END)       AS quality_records
    FROM ecommerce.orders
)
SELECT
    table_name,
    total_records,
    records_with_key,
    quality_records,
    ROUND(records_with_key  * 100.0 / total_records, 2) AS key_completeness_pct,
    ROUND(quality_records   * 100.0 / total_records, 2) AS data_quality_pct,
    CASE
        WHEN records_with_key * 100.0 / total_records >= 95
         AND quality_records  * 100.0 / total_records >= 90 THEN 'EXCELLENT'
        WHEN records_with_key * 100.0 / total_records >= 90
         AND quality_records  * 100.0 / total_records >= 80 THEN 'GOOD'
        WHEN records_with_key * 100.0 / total_records >= 80
         AND quality_records  * 100.0 / total_records >= 70 THEN 'FAIR'
        ELSE 'NEEDS_IMPROVEMENT'
    END AS overall_health
FROM health_metrics
ORDER BY table_name;
