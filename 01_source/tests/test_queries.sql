-- Test Queries for MaxCompute Practice Project
-- Run these queries to validate your setup and data

-- =============================================
-- BASIC VALIDATION TESTS
-- =============================================

-- Test 1: Check if all tables exist
SELECT 
    'Table Existence Check' as test_name,
    CASE 
        WHEN EXISTS (SELECT 1 FROM customers LIMIT 1) THEN 'PASS'
        ELSE 'FAIL'
    END as customers_test,
    CASE 
        WHEN EXISTS (SELECT 1 FROM products LIMIT 1) THEN 'PASS'
        ELSE 'FAIL'
    END as products_test,
    CASE 
        WHEN EXISTS (SELECT 1 FROM orders LIMIT 1) THEN 'PASS'
        ELSE 'FAIL'
    END as orders_test;

-- Test 2: Check data counts
SELECT 
    'Data Count Validation' as test_name,
    (SELECT COUNT(*) FROM customers) as customer_count,
    (SELECT COUNT(*) FROM products) as product_count,
    (SELECT COUNT(*) FROM orders) as order_count,
    (SELECT COUNT(*) FROM order_items) as order_items_count;

-- Test 3: Check for NULL values in key fields
SELECT 
    'NULL Value Check' as test_name,
    (SELECT COUNT(*) FROM customers WHERE customer_id IS NULL) as null_customer_ids,
    (SELECT COUNT(*) FROM products WHERE product_id IS NULL) as null_product_ids,
    (SELECT COUNT(*) FROM orders WHERE order_id IS NULL) as null_order_ids;

-- =============================================
-- DATA QUALITY TESTS
-- =============================================

-- Test 4: Email validation
SELECT 
    'Email Validation' as test_name,
    COUNT(*) as total_customers,
    COUNT(CASE WHEN email RLIKE '^[A-Za-z0-9+_.-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$' THEN 1 END) as valid_emails,
    COUNT(CASE WHEN email NOT RLIKE '^[A-Za-z0-9+_.-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$' OR email IS NULL THEN 1 END) as invalid_emails
FROM customers;

-- Test 5: Price validation for products
SELECT 
    'Price Validation' as test_name,
    COUNT(*) as total_products,
    COUNT(CASE WHEN price > 0 AND cost > 0 AND price > cost THEN 1 END) as valid_pricing,
    COUNT(CASE WHEN price <= 0 OR cost <= 0 OR price <= cost THEN 1 END) as invalid_pricing
FROM products;

-- Test 6: Order amount validation
SELECT 
    'Order Amount Validation' as test_name,
    COUNT(*) as total_orders,
    COUNT(CASE WHEN total_amount > 0 THEN 1 END) as positive_amounts,
    COUNT(CASE WHEN total_amount <= 0 THEN 1 END) as non_positive_amounts,
    MIN(total_amount) as min_amount,
    MAX(total_amount) as max_amount,
    AVG(total_amount) as avg_amount
FROM orders;

-- =============================================
-- REFERENTIAL INTEGRITY TESTS
-- =============================================

-- Test 7: Check for orphaned orders (orders without valid customers)
SELECT 
    'Orphaned Orders Check' as test_name,
    COUNT(*) as total_orders,
    COUNT(c.customer_id) as orders_with_valid_customers,
    COUNT(*) - COUNT(c.customer_id) as orphaned_orders
FROM orders o
LEFT JOIN customers c ON o.customer_id = c.customer_id;

-- Test 8: Check for orphaned order items
SELECT 
    'Orphaned Order Items Check' as test_name,
    COUNT(*) as total_order_items,
    COUNT(o.order_id) as items_with_valid_orders,
    COUNT(p.product_id) as items_with_valid_products,
    COUNT(*) - COUNT(o.order_id) as items_missing_orders,
    COUNT(*) - COUNT(p.product_id) as items_missing_products
FROM order_items oi
LEFT JOIN orders o ON oi.order_id = o.order_id
LEFT JOIN products p ON oi.product_id = p.product_id;

-- =============================================
-- BUSINESS LOGIC TESTS
-- =============================================

-- Test 9: Verify order totals match line items
WITH order_totals AS (
    SELECT 
        o.order_id,
        o.total_amount as order_total,
        COALESCE(SUM(oi.line_total), 0) as calculated_total,
        ABS(o.total_amount - COALESCE(SUM(oi.line_total), 0)) as difference
    FROM orders o
    LEFT JOIN order_items oi ON o.order_id = oi.order_id
    GROUP BY o.order_id, o.total_amount
)
SELECT 
    'Order Total Verification' as test_name,
    COUNT(*) as total_orders,
    COUNT(CASE WHEN difference < 0.01 THEN 1 END) as matching_totals,
    COUNT(CASE WHEN difference >= 0.01 THEN 1 END) as mismatched_totals,
    MAX(difference) as max_difference
FROM order_totals;

-- Test 10: Check for reasonable date ranges
SELECT 
    'Date Range Validation' as test_name,
    MIN(registration_date) as earliest_registration,
    MAX(registration_date) as latest_registration,
    MIN(order_date) as earliest_order,
    MAX(order_date) as latest_order,
    CASE 
        WHEN MIN(order_date) >= MIN(registration_date) THEN 'PASS'
        ELSE 'FAIL'
    END as date_logic_check
FROM customers c
CROSS JOIN orders o;

-- =============================================
-- PERFORMANCE TESTS
-- =============================================

-- Test 11: Partition pruning test (should be fast)
SELECT 
    'Partition Pruning Test' as test_name,
    COUNT(*) as records_in_partition,
    'Should execute quickly with partition pruning' as note
FROM orders
WHERE ds = '20240115';

-- Test 12: Index effectiveness test
SELECT 
    'Customer Lookup Test' as test_name,
    COUNT(DISTINCT customer_id) as unique_customers,
    'Should execute quickly with proper indexing' as note
FROM orders
WHERE customer_id IN ('CUST001', 'CUST002', 'CUST003');

-- =============================================
-- AGGREGATION TESTS
-- =============================================

-- Test 13: Basic aggregation consistency
WITH summary_stats AS (
    SELECT 
        COUNT(DISTINCT customer_id) as unique_customers,
        COUNT(DISTINCT order_id) as unique_orders,
        SUM(total_amount) as total_revenue,
        AVG(total_amount) as avg_order_value
    FROM orders
),
detailed_stats AS (
    SELECT 
        COUNT(DISTINCT o.customer_id) as unique_customers_detailed,
        COUNT(DISTINCT oi.order_id) as unique_orders_detailed,
        SUM(oi.line_total) as total_revenue_detailed
    FROM order_items oi
    JOIN orders o ON oi.order_id = o.order_id
)
SELECT 
    'Aggregation Consistency' as test_name,
    s.unique_customers,
    d.unique_customers_detailed,
    s.unique_orders,
    d.unique_orders_detailed,
    ROUND(s.total_revenue, 2) as order_total_revenue,
    ROUND(d.total_revenue_detailed, 2) as item_total_revenue,
    CASE 
        WHEN ABS(s.total_revenue - d.total_revenue_detailed) < 1 THEN 'PASS'
        ELSE 'FAIL'
    END as revenue_consistency_check
FROM summary_stats s
CROSS JOIN detailed_stats d;

-- =============================================
-- SAMPLE DATA VALIDATION
-- =============================================

-- Test 14: Check data distribution
SELECT 
    'Data Distribution Check' as test_name,
    'Customers by Country' as metric,
    country,
    COUNT(*) as count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) as percentage
FROM customers
GROUP BY country
ORDER BY count DESC;

-- Test 15: Product category distribution
SELECT 
    'Product Category Distribution' as test_name,
    category,
    COUNT(*) as product_count,
    ROUND(AVG(price), 2) as avg_price,
    ROUND(MIN(price), 2) as min_price,
    ROUND(MAX(price), 2) as max_price
FROM products
GROUP BY category
ORDER BY product_count DESC;

-- =============================================
-- FINAL SUMMARY TEST
-- =============================================

-- Test 16: Overall data health summary
WITH health_metrics AS (
    SELECT 
        'customers' as table_name,
        COUNT(*) as total_records,
        COUNT(CASE WHEN customer_id IS NOT NULL THEN 1 END) as records_with_key,
        COUNT(CASE WHEN email RLIKE '^[A-Za-z0-9+_.-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$' THEN 1 END) as quality_records
    FROM customers
    
    UNION ALL
    
    SELECT 
        'products' as table_name,
        COUNT(*) as total_records,
        COUNT(CASE WHEN product_id IS NOT NULL THEN 1 END) as records_with_key,
        COUNT(CASE WHEN price > 0 AND cost > 0 THEN 1 END) as quality_records
    FROM products
    
    UNION ALL
    
    SELECT 
        'orders' as table_name,
        COUNT(*) as total_records,
        COUNT(CASE WHEN order_id IS NOT NULL THEN 1 END) as records_with_key,
        COUNT(CASE WHEN total_amount > 0 THEN 1 END) as quality_records
    FROM orders
)
SELECT 
    table_name,
    total_records,
    records_with_key,
    quality_records,
    ROUND(records_with_key * 100.0 / total_records, 2) as key_completeness_pct,
    ROUND(quality_records * 100.0 / total_records, 2) as data_quality_pct,
    CASE 
        WHEN records_with_key * 100.0 / total_records >= 95 
         AND quality_records * 100.0 / total_records >= 90 THEN 'EXCELLENT'
        WHEN records_with_key * 100.0 / total_records >= 90 
         AND quality_records * 100.0 / total_records >= 80 THEN 'GOOD'
        WHEN records_with_key * 100.0 / total_records >= 80 
         AND quality_records * 100.0 / total_records >= 70 THEN 'FAIR'
        ELSE 'NEEDS_IMPROVEMENT'
    END as overall_health
FROM health_metrics
ORDER BY table_name;

-- =============================================
-- INSTRUCTIONS FOR RUNNING TESTS
-- =============================================

/*
How to run these tests:

1. Ensure all tables are created and populated
2. Run tests individually or all at once
3. Check results for any FAIL statuses
4. Investigate and fix any issues found

Expected results for a healthy dataset:
- All existence checks should PASS
- Data quality scores should be > 90%
- No orphaned records
- Order totals should match line items
- Date ranges should be logical

If any tests fail:
1. Check the troubleshooting guide
2. Review your data loading process
3. Verify table schemas match the sample data
4. Check for data corruption during upload
*/