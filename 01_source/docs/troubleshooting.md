# Troubleshooting Guide

This guide covers common issues you might encounter while learning DataWorks and MaxCompute.

## Connection and Authentication Issues

### Issue: "Access Denied" when connecting to MaxCompute

**Symptoms:**
- Cannot connect using MaxCompute CLI
- "ODPS-0410051: Invalid credentials" error
- Authentication failures in DataWorks

**Solutions:**

1. **Check Access Keys**
   ```bash
   # Verify your access key ID and secret are correct
   # Check in Alibaba Cloud Console > AccessKey Management
   ```

2. **Verify Project Permissions**
   - Ensure your account has access to the MaxCompute project
   - Check project-level permissions in MaxCompute console
   - Verify you're using the correct project name

3. **Check Endpoint Configuration**
   ```ini
   # Common endpoints by region:
   # China (Hangzhou): http://service.odps.aliyun.com/api
   # Singapore: http://service.ap-southeast-1.odps.aliyun.com/api
   # US West: http://service.us-west-1.odps.aliyun.com/api
   ```

### Issue: "Project not found" error

**Solutions:**
1. Double-check project name spelling
2. Ensure project exists in the correct region
3. Verify your account has access to the project

## Data Loading Issues

### Issue: CSV files won't load properly

**Symptoms:**
- Data appears corrupted after loading
- Incorrect number of records
- Special characters not displaying correctly

**Solutions:**

1. **Check File Encoding**
   ```bash
   # Convert file to UTF-8 if necessary
   iconv -f ISO-8859-1 -t UTF-8 input.csv > output_utf8.csv
   ```

2. **Verify CSV Format**
   ```sql
   -- Use proper LOAD DATA syntax
   LOAD DATA INPATH 'oss://bucket/path/file.csv'
   INTO TABLE table_name
   FIELDS TERMINATED BY ','
   LINES TERMINATED BY '\n'
   STORED AS TEXTFILE;
   ```

3. **Handle Special Characters**
   - Ensure CSV is properly quoted
   - Escape special characters in data
   - Use STORED AS TEXTFILE for simple CSV

### Issue: "Table not found" during data loading

**Solutions:**
1. Create table first using DDL scripts
2. Check table name spelling
3. Verify you're in the correct schema/project

## SQL Query Issues

### Issue: "Column not found" in JOIN queries

**Symptoms:**
- Ambiguous column reference errors
- Column not found in complex JOINs

**Solutions:**

1. **Use Table Aliases**
   ```sql
   -- Good practice
   SELECT 
       c.customer_id,
       o.order_date
   FROM customers c
   JOIN orders o ON c.customer_id = o.customer_id;
   
   -- Avoid
   SELECT 
       customer_id,  -- Ambiguous!
       order_date
   FROM customers
   JOIN orders ON customers.customer_id = orders.customer_id;
   ```

2. **Fully Qualify Column Names**
   ```sql
   SELECT 
       customers.customer_id,
       orders.order_date
   FROM customers
   JOIN orders ON customers.customer_id = orders.customer_id;
   ```

### Issue: Poor query performance

**Symptoms:**
- Queries taking very long time
- High compute costs
- Timeout errors

**Solutions:**

1. **Use Partition Pruning**
   ```sql
   -- Good: Uses partition pruning
   SELECT * FROM orders WHERE ds = '20240115';
   
   -- Bad: Scans all partitions
   SELECT * FROM orders WHERE order_date = '2024-01-15';
   ```

2. **Optimize JOINs**
   ```sql
   -- Put smaller table first in JOIN
   SELECT *
   FROM small_table s
   JOIN large_table l ON s.id = l.id
   WHERE s.status = 'active';  -- Filter early
   ```

3. **Use LIMIT for Testing**
   ```sql
   -- Add LIMIT when testing queries
   SELECT * FROM large_table LIMIT 100;
   ```

## DataWorks Workflow Issues

### Issue: Workflow nodes failing

**Symptoms:**
- Nodes showing red/failed status
- Dependency issues
- Scheduling problems

**Solutions:**

1. **Check Node Dependencies**
   - Verify all upstream nodes completed successfully
   - Check for circular dependencies
   - Ensure proper dependency configuration

2. **Review Error Logs**
   ```bash
   # In DataWorks, check:
   # 1. Operation Center > Task O&M
   # 2. Click on failed node
   # 3. Review error logs
   ```

3. **Validate SQL Syntax**
   - Test SQL in MaxCompute CLI first
   - Check for MaxCompute-specific syntax
   - Verify table and column names

### Issue: Data synchronization failures

**Solutions:**

1. **Check Source Connectivity**
   - Verify source database is accessible
   - Check network connectivity
   - Validate credentials

2. **Review Sync Configuration**
   - Check column mappings
   - Verify data type compatibility
   - Ensure target table exists

## UDF (User Defined Function) Issues

### Issue: UDF compilation errors

**For Java UDFs:**

1. **Check Java Version**
   ```bash
   # Use Java 8 for compatibility
   java -version
   ```

2. **Verify Dependencies**
   ```xml
   <!-- In pom.xml, use correct MaxCompute SDK version -->
   <dependency>
       <groupId>com.aliyun.odps</groupId>
       <artifactId>odps-sdk-udf</artifactId>
       <version>0.47.4-public</version>
   </dependency>
   ```

3. **Check Package Structure**
   ```java
   package com.company.maxcompute.udf;  // Must match directory structure
   
   import com.aliyun.odps.udf.UDF;
   
   public class MyUDF extends UDF {
       // Implementation
   }
   ```

**For Python UDFs:**

1. **Check Python Version**
   - MaxCompute supports Python 2.7 and 3.6+
   - Use appropriate syntax for your Python version

2. **Verify Imports**
   ```python
   from odps.udf import annotate
   from odps.udf import BaseUDF
   ```

### Issue: UDF registration failures

**Solutions:**

1. **Check Resource Upload**
   ```sql
   -- Upload JAR file as resource first
   ADD JAR my_udf.jar;
   
   -- Then create function
   CREATE FUNCTION my_function AS 'com.company.MyUDF' USING 'my_udf.jar';
   ```

2. **Verify Class Path**
   - Ensure fully qualified class name is correct
   - Check JAR file contains the compiled class

## Cost and Performance Issues

### Issue: Unexpectedly high costs

**Symptoms:**
- Bills higher than expected
- Resource consumption warnings

**Solutions:**

1. **Monitor Resource Usage**
   ```sql
   -- Check your recent job costs
   SHOW INSTANCES;
   
   -- Review specific instance details
   DESC INSTANCE instance_id;
   ```

2. **Optimize Queries**
   - Use partition pruning
   - Avoid SELECT * on large tables
   - Use appropriate data types
   - Consider using external tables for infrequent access

3. **Set Up Cost Alerts**
   - Configure billing alerts in Alibaba Cloud Console
   - Monitor daily/monthly usage
   - Set budget limits

### Issue: Quota exceeded errors

**Solutions:**

1. **Check Current Quotas**
   ```sql
   -- Check project quotas
   SHOW QUOTA;
   ```

2. **Request Quota Increase**
   - Contact Alibaba Cloud support
   - Provide justification for increased limits
   - Consider upgrading service plan

## Common Error Messages and Solutions

### ODPS-0130131: Table not found

**Cause:** Table doesn't exist or incorrect name

**Solution:**
```sql
-- Check available tables
SHOW TABLES;

-- Check in specific schema
SHOW TABLES IN schema_name;
```

### ODPS-0110061: Failed to read data

**Cause:** Data format issues or corrupted files

**Solutions:**
1. Check source file format
2. Verify file encoding
3. Use different data loading method

### ODPS-0420111: Authorization failed

**Cause:** Insufficient permissions

**Solutions:**
1. Check table-level permissions
2. Verify project access rights
3. Contact project administrator

## Debug and Monitoring Tips

### Enable Detailed Logging

1. **MaxCompute CLI Logging**
   ```bash
   # Add to odps_config.ini
   logview_host=http://logview.odps.aliyun.com
   log_level=DEBUG
   ```

2. **DataWorks Monitoring**
   - Use Operation Center for real-time monitoring
   - Set up email alerts for failures
   - Check resource usage regularly

### Performance Profiling

```sql
-- Use EXPLAIN to understand query execution
EXPLAIN 
SELECT COUNT(*) 
FROM large_table 
WHERE ds = '20240115';

-- Check execution plan for optimization opportunities
```

### Best Practices for Troubleshooting

1. **Start Simple**
   - Test with small datasets first
   - Isolate issues by testing components separately
   - Use LIMIT clauses during development

2. **Keep Logs**
   - Save error messages and codes
   - Document solutions that work
   - Maintain troubleshooting notes

3. **Use Version Control**
   - Track changes to SQL scripts
   - Maintain backup copies of working configurations
   - Document environment-specific settings

4. **Test Incrementally**
   - Build complex queries step by step
   - Test each JOIN separately
   - Validate data at each transformation step

## Getting Additional Help

### Official Support Channels

1. **Alibaba Cloud Support**
   - Submit tickets for technical issues
   - Use live chat for quick questions
   - Check service health status

2. **Documentation and Forums**
   - [MaxCompute Documentation](https://www.alibabacloud.com/help/maxcompute)
   - [DataWorks Documentation](https://www.alibabacloud.com/help/dataworks)
   - Alibaba Cloud Developer Forums

3. **Community Resources**
   - Stack Overflow (tag: alibaba-cloud)
   - GitHub repositories and examples
   - Technical blogs and tutorials

### Before Contacting Support

Prepare the following information:

1. **Error Details**
   - Complete error message
   - Error code (ODPS-xxxxxx)
   - Timestamp when error occurred

2. **Environment Information**
   - MaxCompute project name
   - DataWorks workspace name
   - Region/endpoint being used

3. **Steps to Reproduce**
   - Exact SQL statements or workflow configuration
   - Sample data (if applicable)
   - Expected vs actual results

Remember: Most issues have been encountered before, so searching existing documentation and forums often provides quick solutions!