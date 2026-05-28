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

1. `load_raw_data` — 加载原始 CSV 数据
2. `transform_orders` — 订单数据清洗
3. `transform_users` — 用户数据清洗
4. `build_analytics` — 构建分析层聚合表
5. `data_quality_check` — 数据质量校验

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
cz-cli task create load_raw_data      --profile ecommerce_dev
cz-cli task create transform_orders   --profile ecommerce_dev
cz-cli task create transform_users    --profile ecommerce_dev
cz-cli task create build_analytics    --profile ecommerce_dev
cz-cli task create data_quality_check --profile ecommerce_dev
```

### 4. 写入 SQL 内容

```bash
cz-cli task save-content transform_orders \
  --file 03_lakehouse/sql/04_dwd_transform.sql \
  --profile ecommerce_dev
```

### 5. 配置任务依赖

```bash
# transform_orders 依赖 load_raw_data
cz-cli task save-config transform_orders \
  --deps load_raw_data \
  --profile ecommerce_dev
```

### 6. 配置调度（对应 DataWorks 的 Cron 调度）

```bash
# 每天凌晨 2 点运行
cz-cli task save-cron load_raw_data \
  --cron "0 2 * * *" \
  --profile ecommerce_dev
```

### 7. 发布上线

```bash
cz-cli task deploy load_raw_data      --profile ecommerce_dev
cz-cli task deploy transform_orders   --profile ecommerce_dev
cz-cli task deploy transform_users    --profile ecommerce_dev
cz-cli task deploy build_analytics    --profile ecommerce_dev
cz-cli task deploy data_quality_check --profile ecommerce_dev
```

### 8. 手动触发验证

```bash
cz-cli task execute load_raw_data --profile ecommerce_dev
```

## 注意事项

- 所有 `cz-cli task` 命令必须带 `--profile ecommerce_dev`，保证操作在正确的 workspace 上下文
- 任务发布前必须先 `save-content`，否则 deploy 的是空任务
- `task undeploy` 会清除所有运行实例，不可逆，谨慎使用
- DataWorks 的 MaxCompute SQL 语法需要迁移为 Lakehouse SQL，主要差异见 `01_sql_syntax_diff.md`
