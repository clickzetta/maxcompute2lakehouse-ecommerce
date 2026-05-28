#!/usr/bin/env python3
"""
maxcompute2lakehouse-ecommerce 一键初始化脚本

执行顺序：
  1. 创建 cz-cli profile（保证后续 task 操作在同一上下文）
  2. 连接 ClickZetta Lakehouse，创建 Schema 和 Volume
  3. 上传 data/ 目录下的 CSV 文件到 Volume
  4. 建表（ODS 层：8 张原始表）
  5. 用 COPY INTO 加载数据

用法：
  pip install clickzetta-zettapark python-dotenv
  cp .env.example .env  # 填写连接信息
  python 03_lakehouse/setup.py
"""

import os
import sys
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
    print(f"\n[2/5] 创建 Schema")
    for schema in [SCHEMA_NAME, dwd_schema, ads_schema]:
        session.sql(f"CREATE SCHEMA IF NOT EXISTS {schema}").collect()
        print(f"  {schema} OK")


def step_volume(session):
    print(f"\n[3/5] 创建 Volume: {SCHEMA_NAME}.{VOLUME_NAME}")
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
    print(f"\n[4/5] 建表（ODS 层）")
    sql_file = Path(__file__).parent / "sql" / "01_create_tables.sql"
    if not sql_file.exists():
        print(f"  [SKIP] {sql_file} 不存在，请先创建迁移后的建表 SQL")
        return
    ddl = sql_file.read_text()
    for stmt in [s.strip() for s in ddl.split(";") if s.strip()]:
        session.sql(stmt).collect()
    print("  建表完成")


def step_load_data(session):
    print(f"\n[5/5] 加载数据（COPY INTO）")
    sql_file = Path(__file__).parent / "sql" / "02_load_data.sql"
    if not sql_file.exists():
        print(f"  [SKIP] {sql_file} 不存在，请先创建迁移后的加载 SQL")
        return
    sql = sql_file.read_text()
    for stmt in [s.strip() for s in sql.split(";") if s.strip()]:
        session.sql(stmt).collect()
    print("  数据加载完成")


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

    print("\n" + "=" * 60)
    print("初始化完成。下一步：")
    print("  python 03_lakehouse/e2e.py")
    print("=" * 60)


if __name__ == "__main__":
    main()
