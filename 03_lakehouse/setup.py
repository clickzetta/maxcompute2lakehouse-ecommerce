#!/usr/bin/env python3
"""
maxcompute2lakehouse-ecommerce 一键初始化脚本

执行顺序：
  1. 创建 cz-cli profile（保证后续 task 操作在同一上下文）
  2. 连接 ClickZetta Lakehouse，创建 Schema 和 Volume
  3. 上传 data/ 目录下的 CSV 文件到 Volume
  4. 建表（ODS 层：8 张原始表）
  5. 用 COPY INTO 加载数据
  6. 创建 Studio 任务（对应 DataWorks workflow 的 5 个节点）

用法：
  pip install -r requirements.txt
  cp .env.example .env  # 填写连接信息
  python 03_lakehouse/setup.py
"""

import os
import sys
import json
import subprocess
from pathlib import Path
from dotenv import load_dotenv

load_dotenv(Path(__file__).parent.parent / ".env")

try:
    from clickzetta.zettapark.session import Session
except ImportError:
    print("请先安装依赖: pip install clickzetta-zettapark python-dotenv")
    sys.exit(1)

sys.path.insert(0, str(Path(__file__).parent))
from includes.configuration import SCHEMA_NAME, VOLUME_NAME, VOLUME_PATH, dwd_schema, ads_schema

REPO_ROOT = Path(__file__).parent.parent
DATA_DIR  = REPO_ROOT / "data"

TABLES = [
    "customers", "products", "orders", "order_items",
    "web_sessions", "page_views", "user_events", "suppliers",
]


def make_session():
    return Session.builder.configs({
        "service":   os.environ["CLICKZETTA_SERVICE"],
        "instance":  os.environ["CLICKZETTA_INSTANCE"],
        "workspace": os.environ["CLICKZETTA_WORKSPACE"],
        "schema":    SCHEMA_NAME,
        "vcluster":  os.environ.get("CLICKZETTA_VCLUSTER", "default_ap"),
        "username":  os.environ["CLICKZETTA_USERNAME"],
        "password":  os.environ["CLICKZETTA_PASSWORD"],
    }).create()


def step_profile():
    """创建 cz-cli profile，保证 task 操作与 SQL 操作在同一 workspace 上下文。"""
    profile = os.environ.get("CZ_PROFILE", "ecommerce_dev")
    print(f"\n[1/5] 创建 cz-cli profile: {profile}")
    cmd = [
        "cz-cli", "profile", "create", profile,
        "--service",   os.environ["CLICKZETTA_SERVICE"],
        "--instance",  os.environ["CLICKZETTA_INSTANCE"],
        "--workspace", os.environ["CLICKZETTA_WORKSPACE"],
        "--schema",    SCHEMA_NAME,
        "--vcluster",  os.environ.get("CLICKZETTA_VCLUSTER", "default_ap"),
        "--username",  os.environ["CLICKZETTA_USERNAME"],
        "--password",  os.environ["CLICKZETTA_PASSWORD"],
    ]
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode == 0:
        print(f"  profile '{profile}' 创建成功")
    else:
        # profile 已存在时不报错，继续
        if "already exists" in result.stderr or "already exists" in result.stdout:
            print(f"  profile '{profile}' 已存在，跳过")
        else:
            print(f"  [WARN] {result.stderr.strip()}")


def step_schemas(session):
    print(f"\n[2/6] 创建 Schema")
    for schema in [SCHEMA_NAME, dwd_schema, ads_schema]:
        session.sql(f"CREATE SCHEMA IF NOT EXISTS {schema}").collect()
        print(f"  {schema} OK")


def step_volume(session):
    print(f"\n[3/6] 创建 Volume: {SCHEMA_NAME}.{VOLUME_NAME}")
    session.sql(
        f"CREATE VOLUME IF NOT EXISTS {SCHEMA_NAME}.{VOLUME_NAME}"
    ).collect()
    print("  Volume 创建成功")

    print("  上传 data/ 文件到 Volume...")
    csv_files = list(DATA_DIR.glob("*.csv"))
    if not csv_files:
        print(f"  [ERROR] {DATA_DIR} 下没有 CSV 文件")
        sys.exit(1)
    for f in csv_files:
        session.file.put(str(f), f"{VOLUME_PATH}/raw/")
        print(f"    {f.name} -> {VOLUME_PATH}/raw/")


def step_create_tables(session):
    print(f"\n[4/6] 建表（ODS 层）")
    sql_file = Path(__file__).parent / "sql" / "01_create_tables.sql"
    if not sql_file.exists():
        print(f"  [SKIP] {sql_file} 不存在，请先创建迁移后的建表 SQL")
        return
    ddl = sql_file.read_text()
    for stmt in [s.strip() for s in ddl.split(";") if s.strip()]:
        session.sql(stmt).collect()
    print("  建表完成")


def step_load_data(session):
    print(f"\n[5/6] 加载数据（COPY INTO）")
    sql_file = Path(__file__).parent / "sql" / "02_load_data.sql"
    if not sql_file.exists():
        print(f"  [SKIP] {sql_file} 不存在，请先创建迁移后的加载 SQL")
        return
    sql = sql_file.read_text()
    for stmt in [s.strip() for s in sql.split(";") if s.strip()]:
        session.sql(stmt).collect()
    print("  数据加载完成")


def step_studio_tasks():
    """创建 Studio 任务，对应 DataWorks daily_etl_workflow 的 5 个节点。"""
    profile = os.environ.get("CZ_PROFILE", "ecommerce_dev")
    folder  = "ecommerce_etl"
    sql_dir = Path(__file__).parent / "sql"

    # 任务定义：name → SQL 文件
    tasks = [
        ("data_quality_check",    "06_data_quality.sql"),
        ("customer_segmentation", "04_dwd_transform.sql"),
        ("product_performance_etl", "04_dwd_transform.sql"),
        ("web_analytics_etl",     "05_ads_transform.sql"),
        ("daily_sales_summary",   "04_dwd_transform.sql"),
    ]
    # 依赖关系：task → [upstream_task_names]
    deps = {
        "customer_segmentation":   ["data_quality_check"],
        "product_performance_etl": ["data_quality_check"],
        "web_analytics_etl":       ["data_quality_check"],
        "daily_sales_summary":     ["customer_segmentation", "product_performance_etl"],
    }

    print(f"\n[6/6] 创建 Studio 任务（folder: {folder}）")

    def cz(*args):
        result = subprocess.run(
            ["cz-cli"] + list(args) + ["--profile", profile],
            capture_output=True, text=True
        )
        return result

    # 创建文件夹（已存在时忽略）
    cz("task", "create-folder", folder)

    # 第一轮：创建任务 + 写入 SQL 内容
    for name, sql_file in tasks:
        r = cz("task", "create", name, "--type", "SQL", "--folder", folder)
        if r.returncode == 0:
            print(f"  创建 {name}")
        else:
            err = r.stderr.strip() or r.stdout.strip()
            if "already exists" in err.lower() or "exist" in err.lower():
                print(f"  {name} 已存在，跳过创建")
            else:
                print(f"  [WARN] 创建 {name}: {err[:100]}")

        sql_path = sql_dir / sql_file
        if sql_path.exists():
            r2 = cz("task", "save-content", name, "--file", str(sql_path))
            if r2.returncode != 0:
                print(f"  [WARN] save-content {name}: {(r2.stderr or r2.stdout).strip()[:100]}")

    # 第二轮：获取 taskId 映射，配置依赖
    r = cz("task", "list", "--page-size", "100")
    task_id_map = {}
    if r.returncode == 0:
        try:
            data = json.loads(r.stdout)
            for t in data.get("data", []):
                task_id_map[t["task_name"]] = t["task_id"]
        except (json.JSONDecodeError, KeyError):
            pass

    for name, upstreams in deps.items():
        dep_tasks = [
            {"taskId": task_id_map[u], "taskName": u}
            for u in upstreams if u in task_id_map
        ]
        if not dep_tasks:
            print(f"  [WARN] {name} 找不到上游 taskId，跳过依赖配置")
            continue
        r = cz("task", "save-config", name,
                "--deps", "replace",
                "--dep-tasks", json.dumps(dep_tasks))
        if r.returncode == 0:
            print(f"  依赖配置 {name} ← {[u['taskName'] for u in dep_tasks]}")
        else:
            print(f"  [WARN] save-config {name}: {(r.stderr or r.stdout).strip()[:100]}")

    # 配置入口任务的 cron（每天 02:00）
    cz("task", "save-cron", "data_quality_check", "--cron", "0 2 * * *")

    # 发布所有任务
    for name, _ in tasks:
        r = cz("task", "deploy", name)
        if r.returncode == 0:
            print(f"  deploy {name} OK")
        else:
            print(f"  [WARN] deploy {name}: {(r.stderr or r.stdout).strip()[:100]}")

    print("  Studio 任务创建完成")


def main():
    print("=" * 60)
    print("maxcompute2lakehouse-ecommerce  初始化")
    print("=" * 60)

    step_profile()

    session = make_session()
    try:
        step_schemas(session)
        step_volume(session)
        step_create_tables(session)
        step_load_data(session)
    finally:
        session.close()

    step_studio_tasks()

    print("\n" + "=" * 60)
    print("初始化完成。下一步：")
    print("  python 03_lakehouse/e2e.py")
    print("=" * 60)


if __name__ == "__main__":
    main()
