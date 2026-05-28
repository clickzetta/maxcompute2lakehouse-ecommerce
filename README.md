# maxcompute2lakehouse-ecommerce

MaxCompute + DataWorks 电商数据工程项目迁移到 ClickZetta Lakehouse 的完整实战案例。

**迁移文档**：[MaxCompute → Lakehouse 迁移实战：电商数据工程项目](https://4v2dmg3x2e.k.topthink.com/-/book/k7pl9zonpy/edit)

**原始项目**：[rcdelacruz/dataworks-maxcompute-practice](https://github.com/rcdelacruz/dataworks-maxcompute-practice)

---

## 目录结构

```
maxcompute2lakehouse-ecommerce/
├── 01_source/                        # 原始 MaxCompute 代码（原样保留）
│   ├── sql/                          # MaxCompute SQL（6 个脚本）
│   ├── workflows/daily_etl_workflow.json  # DataWorks 任务编排
│   ├── udf/                          # 原始 UDF（Java + Python）
│   ├── tests/test_queries.sql        # 原始验证测试
│   └── README.md                     # 原始项目说明
├── 02_migration/                     # 迁移说明
│   ├── 01_sql_syntax_diff.md         # MaxCompute vs Lakehouse 语法对照
│   └── 02_dataworks_to_studio.md     # DataWorks 任务 → Studio 任务映射
├── 03_lakehouse/                     # 迁移后代码
│   ├── sql/                          # Lakehouse SQL（对应 01_source/sql/）
│   │   ├── 01_create_tables.sql      # ODS 层建表
│   │   ├── 02_load_data.sql          # COPY INTO FROM VOLUME
│   │   ├── 03_basic_queries.sql      # 基础查询
│   │   ├── 04_joins_analytics.sql    # JOIN + 窗口函数
│   │   ├── 03_dwd_create_tables.sql  # DWD 层建表
│   │   ├── 04_dwd_transform.sql      # DWD 层 ETL（数据填充）
│   │   ├── 05_ads_transform.sql      # ADS 层 ETL
│   │   └── 06_data_quality.sql       # 数据质量框架
│   ├── tasks/task_list.txt           # Studio 任务列表（对应 DataWorks workflow）
│   ├── udf/                          # External Function 代码
│   │   ├── text_analytics.py         # Python UDF（适配 cz.udf）
│   │   ├── StringUtils.java          # Java UDF（适配 com.clickzetta.udf）
│   │   └── register_functions.sql    # CREATE EXTERNAL FUNCTION 注册 SQL
│   ├── tests/test_queries.sql        # 迁移后验证测试（16 个）
│   ├── includes/configuration.py     # Schema / Volume 路径常量
│   ├── setup.py                      # 一键初始化
│   └── e2e.py                        # 端到端验证
├── data/                             # 8 个 CSV 样本文件
├── .env.example                      # 连接配置模板
└── .gitignore
```

---

## 快速开始

### 1. 配置连接

```bash
cp .env.example .env
# 填写 CLICKZETTA_SERVICE / INSTANCE / WORKSPACE / USERNAME / PASSWORD
```

### 2. 初始化环境

```bash
pip install clickzetta-zettapark python-dotenv
python 03_lakehouse/setup.py
```

`setup.py` 会自动完成：
- 创建 cz-cli profile（`ecommerce_dev`）
- 创建 Schema（ecommerce / ecommerce_dwd / ecommerce_ads）
- 创建 Volume 并上传 8 个 CSV 文件
- 建表（ODS 层 8 张表）
- 加载数据（COPY INTO）

### 3. 端到端验证

```bash
# 增量运行（保留已有数据）
python 03_lakehouse/e2e.py

# 全量重跑（清空后重建）
python 03_lakehouse/e2e.py --reset
```

`e2e.py` 执行顺序：DWD 层建表 → DWD 数据填充 → ADS 层转换 → 数据质量框架 → 行数汇总 → Studio 任务触发

### 4. 清理环境（可选）

```bash
# 预览将要删除的对象（dry run，不实际执行）
python 03_lakehouse/reset.py

# 实际删除所有表、Volume、Schema
python 03_lakehouse/reset.py --confirm
```

验证通过后输出：

```
ecommerce（ODS）:
  customers / products / orders / order_items / web_sessions / page_views / user_events / suppliers

ecommerce_dwd:
  daily_sales_summary 4 行 / customer_segments 10 行 / product_performance 10 行

ecommerce_ads:
  web_analytics_summary 1 行 / customer_changes 0 行 / data_quality_metrics 3 行
  dq_rules 6 行 / dq_assessment 6 行 / data_profile 3 行

Studio 任务:  5 个任务全部触发成功
```

---

## 迁移要点

### SQL 语法（6 处改动）

| MaxCompute | Lakehouse | 说明 |
|---|---|---|
| `LIFECYCLE 365` | 删除 | Lakehouse 无此概念 |
| `DATETIME` | `STRING`（ODS）/ `TIMESTAMP`（DWD） | COPY INTO 不支持隐式转换 |
| `LOAD DATA INPATH 'oss://...'` | `COPY INTO ... FROM VOLUME ... USING CSV` | 语法结构不同 |
| `${bizdate}` | Studio 任务 SQL 中可直接使用（调度运行时替换）；Python/cz-cli 直接执行时用 f-string | — |
| `GETDATE()` | `CURRENT_TIMESTAMP()` | — |
| `RLIKE` / `CAST AS STRING` | `REGEXP` / `CAST AS VARCHAR` | — |

### DataWorks → Studio 任务

```bash
# 创建任务（必须带 --profile 保证上下文一致）
cz-cli task create <name> --type SQL --folder ecommerce_etl --profile ecommerce_dev

# 写入内容
cz-cli task save-content <name> --file <sql_file> --profile ecommerce_dev

# 配置依赖（--dep-tasks 传 JSON 数组）
cz-cli task save-config <name> \
  --deps replace \
  --dep-tasks '[{"taskId":10353489,"taskName":"data_quality_check"}]' \
  --profile ecommerce_dev
```

### UDF

Python/Java UDF 代码逻辑零改动，部署方式从"MaxCompute 引擎内执行"改为"云函数服务（阿里云 FC / 腾讯云 SCF）"。注册 SQL 见 `03_lakehouse/udf/register_functions.sql`。

---

## 踩坑记录

详见迁移文档，主要 4 个坑：

1. `COPY INTO FILE_FORMAT=(...)` 语法报错 → 改用 `USING CSV OPTIONS(...)`
2. ODS 层日期列用 `TIMESTAMP` 导致 COPY INTO 隐式转换失败 → 改用 `STRING`
3. `user_events.csv` 第 30 行 `event_data` 含逗号导致列数溢出 → Python 修复源数据
4. `cz-cli task save-config --deps` 不接受任务名 → 用 `--dep-tasks '[{"taskId":...}]'`
