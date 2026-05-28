-- Data Loading Scripts for MaxCompute
-- These scripts show different ways to load data into MaxCompute tables

-- Method 1: Load from local files using DataWorks interface
-- Upload CSV files to DataWorks and use the data import wizard
-- This method is good for initial setup and small datasets

-- Method 2: Load using LOAD DATA command (for files in OSS)
-- First upload your CSV files to Object Storage Service (OSS)
-- Then use LOAD DATA to import into MaxCompute

/*
LOAD DATA INPATH 'oss://your-bucket/data/customers.csv'
INTO TABLE customers;

LOAD DATA INPATH 'oss://your-bucket/data/products.csv'
INTO TABLE products;
*/

-- Method 3: Insert sample data directly (for testing)
-- Use this method to quickly create test data

-- Insert sample customers
INSERT INTO customers VALUES
('CUST001', 'John', 'Smith', 'john.smith@email.com', '+1-555-0101', 
 CAST('2023-01-15 00:00:00' AS DATETIME), 'USA', 'New York', '25-34'),
('CUST002', 'Sarah', 'Johnson', 'sarah.j@email.com', '+1-555-0102', 
 CAST('2023-01-16 00:00:00' AS DATETIME), 'USA', 'Los Angeles', '35-44'),
('CUST003', 'Michael', 'Brown', 'm.brown@email.com', '+44-20-7946-0958', 
 CAST('2023-01-17 00:00:00' AS DATETIME), 'UK', 'London', '25-34');

-- Insert sample products
INSERT INTO products VALUES
('PROD001', 'Wireless Headphones', 'Electronics', 'Audio', 'TechBrand', 
 99.99, 45.00, 'SUP001', CAST('2022-06-15 00:00:00' AS DATETIME)),
('PROD002', 'Running Shoes', 'Fashion', 'Footwear', 'SportMax', 
 129.99, 65.00, 'SUP002', CAST('2022-08-20 00:00:00' AS DATETIME)),
('PROD003', 'Coffee Maker', 'Home', 'Kitchen', 'HomeEssentials', 
 79.99, 35.00, 'SUP003', CAST('2022-05-10 00:00:00' AS DATETIME));

-- Insert sample orders (with partition)
INSERT INTO orders PARTITION (ds='20240115') VALUES
('ORD001', 'CUST001', CAST('2024-01-15 10:30:00' AS DATETIME), 
 'completed', 159.98, 9.99, 'credit_card', '123 Main St New York NY 10001'),
('ORD002', 'CUST002', CAST('2024-01-15 11:45:00' AS DATETIME), 
 'completed', 129.99, 0.00, 'paypal', '456 Oak Ave Los Angeles CA 90210');

INSERT INTO orders PARTITION (ds='20240116') VALUES
('ORD003', 'CUST003', CAST('2024-01-16 09:15:00' AS DATETIME), 
 'shipped', 79.99, 12.50, 'credit_card', '789 High St London W1A 1AA'),
('ORD004', 'CUST001', CAST('2024-01-16 14:20:00' AS DATETIME), 
 'processing', 99.99, 9.99, 'credit_card', '123 Main St New York NY 10001');

-- Insert sample order items
INSERT INTO order_items PARTITION (ds='20240115') VALUES
('ITEM001', 'ORD001', 'PROD001', 1, 99.99, 0.00, 99.99),
('ITEM002', 'ORD001', 'PROD004', 2, 24.99, 0.00, 49.99),
('ITEM003', 'ORD002', 'PROD002', 1, 129.99, 0.00, 129.99);

INSERT INTO order_items PARTITION (ds='20240116') VALUES
('ITEM004', 'ORD003', 'PROD003', 1, 79.99, 0.00, 79.99),
('ITEM005', 'ORD004', 'PROD001', 1, 99.99, 0.00, 99.99);

-- Verify data loading
SELECT 'customers' as table_name, COUNT(*) as record_count FROM customers
UNION ALL
SELECT 'products' as table_name, COUNT(*) as record_count FROM products
UNION ALL
SELECT 'orders' as table_name, COUNT(*) as record_count FROM orders
UNION ALL
SELECT 'order_items' as table_name, COUNT(*) as record_count FROM order_items;