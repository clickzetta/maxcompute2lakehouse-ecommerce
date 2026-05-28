# MaxCompute → Lakehouse SQL 语法差异

## 快速对照表

| 场景 | MaxCompute | Lakehouse |
|---|---|---|
| 表生命周期 | `LIFECYCLE 365` | 不支持，直接删除 |
| 日期时间类型 | `DATETIME` | `TIMESTAMP` |
| 当前时间函数 | `GETDATE()` | `CURRENT_TIMESTAMP()` |
| 分区写入 | `INSERT OVERWRITE TABLE t PARTITION (ds='${bizdate}')` | Studio 任务 SQL 中可保留 `${bizdate}`；Python 直接执行时用 f-string |
| 参数变量 | `${bizdate}` | Studio 任务 SQL 支持（调度运行时替换）；Python/cz-cli 直接执行时用 f-string |
| 数据加载 | `LOAD DATA INPATH 'oss://...'` | `COPY INTO ... FROM VOLUME ...` |
| 表注释 | `COMMENT '...'` | 支持（可选） |
| 分区语法 | `PARTITIONED BY (ds STRING)` | 相同 |
| CTE | `WITH ... AS (...)` | 相同 |
| 窗口函数 | `ROW_NUMBER() OVER (...)` | 相同 |
| 字符串拼接 | `CONCAT(a, b)` | 相同 |
| NULL 处理 | `COALESCE(a, b)` | 相同 |
| 日期格式化 | `DATE_FORMAT(dt, 'yyyy-MM-dd')` | `DATE_FORMAT(dt, 'yyyy-MM-dd')` 相同 |

## 重点差异说明

### 1. LIFECYCLE → 无

MaxCompute 用 `LIFECYCLE` 控制数据保留天数，Lakehouse 没有对应概念，直接删除该子句。

```sql
-- MaxCompute
CREATE TABLE orders (...) LIFECYCLE 365;

-- Lakehouse
CREATE TABLE orders (...);
```

### 2. DATETIME → TIMESTAMP

MaxCompute 的 `DATETIME` 对应 Lakehouse 的 `TIMESTAMP`。

```sql
-- MaxCompute
order_date DATETIME

-- Lakehouse
order_date TIMESTAMP
```

### 3. ${bizdate} 参数变量

**Studio 任务 SQL** 中可以直接使用 `${bizdate}`，调度运行时由系统替换，与 DataWorks 行为一致。

**Python/cz-cli 直接执行**时 `${bizdate}` 不会被替换，需要用 f-string 动态拼接：

- **Studio 任务 SQL**：保留 `${bizdate}` 不变
- **Python 直接执行**：用 f-string 传入字面量日期

```python
# Python 中动态传入日期
bizdate = "20240115"
session.sql(f"""
    INSERT OVERWRITE TABLE ecommerce_dwd.daily_sales
    PARTITION (ds = '{bizdate}')
    SELECT ...
""").collect()
```

### 4. LOAD DATA INPATH → COPY INTO FROM VOLUME

MaxCompute 从 OSS 加载数据用 `LOAD DATA INPATH`，Lakehouse 用 `COPY INTO FROM VOLUME`。

```sql
-- MaxCompute
LOAD DATA INPATH 'oss://bucket/data/customers.csv' INTO TABLE customers;

-- Lakehouse
COPY INTO ecommerce.customers
FROM VOLUME ecommerce_vol
USING CSV
OPTIONS ('header' = 'true')
FILES ('raw/customers.csv');
```

### 5. INSERT OVERWRITE 分区写入

两者语法基本相同，主要差异是去掉 `TABLE` 关键字（Lakehouse 可选）和参数变量替换。

```sql
-- MaxCompute
INSERT OVERWRITE TABLE daily_sales_summary PARTITION (ds = '${bizdate}')
SELECT ...;

-- Lakehouse
INSERT OVERWRITE TABLE ecommerce_dwd.daily_sales_summary PARTITION (ds = '20240115')
SELECT ...;
```

### 6. GETDATE() → CURRENT_TIMESTAMP()

```sql
-- MaxCompute
GETDATE()

-- Lakehouse
CURRENT_TIMESTAMP()
```
