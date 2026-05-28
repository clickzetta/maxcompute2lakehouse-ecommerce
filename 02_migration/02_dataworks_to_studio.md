# DataWorks 任务迁移到 Studio 任务

## 概念映射

| DataWorks 概念 | Studio 对应 | cz-cli 操作 |
|---|---|---|
| 任务节点（Node） | Studio 任务 | `cz-cli task create <name>` |
| 工作流（Workflow） | 任务 + 依赖配置 | `cz-cli task save-config <task>` |
| 调度配置（Cron） | 任务 Cron | `cz-cli task save-cron <task>` |
| 手动触发运行 | 任务执行 | `cz-cli task execute <task>` |
| 发布上线 | 任务部署 | `cz-cli task deploy <task>` |

## 本项目的 DataWorks Workflow

源文件：`01_source/workflows/daily_etl_workflow.json`

原始 workflow 包含以下节点（按依赖顺序）：

1. `data_quality_check` — 数据质量校验（入口，无依赖）
2. `customer_segmentation` — 客户分层分析（依赖 data_quality_check）
3. `product_performance` — 商品表现分析（依赖 data_quality_check）
4. `web_analytics_summary` — Web 流量分析（依赖 data_quality_check）
5. `daily_sales_summary` — 每日销售汇总（依赖 customer_segmentation + product_performance）

迁移后 Studio 任务名：

| DataWorks 节点 | Studio 任务名 | 对应 SQL 文件 |
|---|---|---|
| data_quality_check | `data_quality_check` | `03_lakehouse/sql/06_data_quality.sql` |
| customer_segmentation | `customer_segmentation` | `03_lakehouse/sql/04_dwd_transform.sql` |
| product_performance | `product_performance_etl` | `03_lakehouse/sql/04_dwd_transform.sql` |
| web_analytics_summary | `web_analytics_etl` | `03_lakehouse/sql/05_ads_transform.sql` |
| daily_sales_summary | `daily_sales_summary` | `03_lakehouse/sql/04_dwd_transform.sql` |

## 迁移步骤

### 1. 创建 profile（保证所有操作在同一 workspace 上下文）

```bash
cz-cli profile create ecommerce_dev \
  --service   <service> \
  --instance  <instance> \
  --workspace <workspace> \
  --schema    ecommerce \
  --vcluster  default_ap \
  --username  <username> \
  --password  <password>
```

### 2. 创建任务文件夹

```bash
cz-cli task create-folder ecommerce_etl --profile ecommerce_dev
```

### 3. 创建各任务节点

```bash
cz-cli task create data_quality_check    --type SQL --folder ecommerce_etl --profile ecommerce_dev
cz-cli task create customer_segmentation --type SQL --folder ecommerce_etl --profile ecommerce_dev
cz-cli task create product_performance_etl --type SQL --folder ecommerce_etl --profile ecommerce_dev
cz-cli task create web_analytics_etl    --type SQL --folder ecommerce_etl --profile ecommerce_dev
cz-cli task create daily_sales_summary  --type SQL --folder ecommerce_etl --profile ecommerce_dev
```

### 4. 写入 SQL 内容

```bash
cz-cli task save-content data_quality_check \
  --file 03_lakehouse/sql/06_data_quality.sql --profile ecommerce_dev

cz-cli task save-content customer_segmentation \
  --file 03_lakehouse/sql/03_dwd_create_tables.sql --profile ecommerce_dev

cz-cli task save-content product_performance_etl \
  --file 03_lakehouse/sql/04_dwd_transform.sql --profile ecommerce_dev

cz-cli task save-content web_analytics_etl \
  --file 03_lakehouse/sql/05_ads_transform.sql --profile ecommerce_dev

cz-cli task save-content daily_sales_summary \
  --file 03_lakehouse/sql/04_dwd_transform.sql --profile ecommerce_dev
```

### 5. 配置任务依赖

先用 `cz-cli task list --profile ecommerce_dev` 获取各任务的 task_id，再配置依赖：

```bash
# 获取 data_quality_check 的 task_id
cz-cli task list --profile ecommerce_dev

# customer_segmentation 依赖 data_quality_check（替换 <DQC_ID> 为实际 task_id）
cz-cli task save-config customer_segmentation \
  --deps replace \
  --dep-tasks '[{"taskId":<DQC_ID>,"taskName":"data_quality_check"}]' \
  --profile ecommerce_dev

# product_performance_etl 依赖 data_quality_check
cz-cli task save-config product_performance_etl \
  --deps replace \
  --dep-tasks '[{"taskId":<DQC_ID>,"taskName":"data_quality_check"}]' \
  --profile ecommerce_dev

# web_analytics_etl 依赖 data_quality_check
cz-cli task save-config web_analytics_etl \
  --deps replace \
  --dep-tasks '[{"taskId":<DQC_ID>,"taskName":"data_quality_check"}]' \
  --profile ecommerce_dev

# daily_sales_summary 依赖 customer_segmentation + product_performance_etl
cz-cli task save-config daily_sales_summary \
  --deps replace \
  --dep-tasks '[{"taskId":<CS_ID>,"taskName":"customer_segmentation"},{"taskId":<PP_ID>,"taskName":"product_performance_etl"}]' \
  --profile ecommerce_dev
```

### 6. 配置调度（每天 02:00 触发入口任务）

```bash
cz-cli task save-cron data_quality_check \
  --cron "0 2 * * *" --profile ecommerce_dev
```

### 7. 发布上线

```bash
cz-cli task deploy data_quality_check    --profile ecommerce_dev
cz-cli task deploy customer_segmentation --profile ecommerce_dev
cz-cli task deploy product_performance_etl --profile ecommerce_dev
cz-cli task deploy web_analytics_etl    --profile ecommerce_dev
cz-cli task deploy daily_sales_summary  --profile ecommerce_dev
```

### 8. 手动触发验证

```bash
cz-cli task execute data_quality_check --profile ecommerce_dev
```

## 注意事项

- 所有 `cz-cli task` 命令必须带 `--profile ecommerce_dev`，保证操作在正确的 workspace 上下文
- 任务发布前必须先 `save-content`，否则 deploy 的是空任务
- `task undeploy` 会清除所有运行实例，不可逆，谨慎使用
- DataWorks 的 MaxCompute SQL 语法需要迁移为 Lakehouse SQL，主要差异见 `01_sql_syntax_diff.md`
