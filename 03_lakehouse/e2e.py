#!/usr/bin/env python3
"""
e2e.py — 端到端全流程验证

执行顺序：
  1. 运行 ODS 层转换（03_lakehouse/sql/03_ods_transform.sql）
  2. 运行 DWD 层转换（03_lakehouse/sql/04_dwd_transform.sql）
  3. 运行 ADS 层转换（03_lakehouse/sql/05_ads_transform.sql）
  4. 打印各层行数汇总
  5. 通过 cz-cli task 触发 Studio 任务并验证状态

用法：
  python 03_lakehouse/e2e.py               # 增量运行
  python 03_lakehouse/e2e.py --reset       # 先清空所有表，再全量跑
  python 03_lakehouse/e2e.py --skip-sql    # 跳过 SQL 转换，只跑 task 验证
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
from includes.configuration import SCHEMA_NAME, ods_schema, dwd_schema, ads_schema

DO_RESET  = "--reset"    in sys.argv
SKIP_SQL  = "--skip-sql" in sys.argv
PROFILE   = os.environ.get("CZ_PROFILE", "ecommerce_dev")
LAKEHOUSE = Path(__file__).parent


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


def run_sql_file(session, path: Path):
    if not path.exists():
        print(f"  [SKIP] {path.name} 不存在")
        return
    sql = path.read_text()
    for stmt in [s.strip() for s in sql.split(";") if s.strip()]:
        session.sql(stmt).collect()
    print(f"  {path.name} OK")


def step_reset(session):
    print("\n[RESET] 清空所有表")
    for schema in [ods_schema, dwd_schema, ads_schema]:
        rows = session.sql(f"SHOW TABLES IN {schema}").collect()
        for row in rows:
            tname = row[1] if len(row) > 1 else row[0]
            session.sql(f"DROP TABLE IF EXISTS {schema}.{tname}").collect()
            print(f"  DROP {schema}.{tname}")


def step_transform(session):
    sql_dir = LAKEHOUSE / "sql"
    print("\n[1/3] ODS 转换")
    run_sql_file(session, sql_dir / "03_ods_transform.sql")
    print("\n[2/3] DWD 转换")
    run_sql_file(session, sql_dir / "04_dwd_transform.sql")
    print("\n[3/3] ADS 转换")
    run_sql_file(session, sql_dir / "05_ads_transform.sql")


def step_summary(session):
    print("\n=== 数据汇总 ===")
    layers = {
        ods_schema: ["customers", "products", "orders", "order_items",
                     "web_sessions", "page_views", "user_events", "suppliers"],
        dwd_schema: [],   # 迁移后补充
        ads_schema: [],   # 迁移后补充
    }
    for schema, tables in layers.items():
        if not tables:
            continue
        print(f"\n{schema}:")
        for t in tables:
            try:
                n = session.sql(f"SELECT COUNT(*) cnt FROM {schema}.{t}").collect()[0]["cnt"]
                print(f"  {t:<20} {n:>8} 行")
            except Exception:
                print(f"  {t:<20}  (不存在)")


def step_tasks():
    """通过 cz-cli task 触发 Studio 任务，验证 DataWorks workflow 迁移结果。"""
    print("\n=== Studio 任务验证 ===")
    tasks_dir = LAKEHOUSE / "tasks"
    task_list_file = tasks_dir / "task_list.txt"
    if not task_list_file.exists():
        print("  [SKIP] tasks/task_list.txt 不存在，跳过任务验证")
        print("  提示：运行 cz-cli task list --profile ecommerce_dev 查看已创建的任务")
        return

    task_names = [l.strip() for l in task_list_file.read_text().splitlines() if l.strip()]
    for task in task_names:
        print(f"\n  执行任务: {task}")
        result = subprocess.run(
            ["cz-cli", "task", "execute", task, "--profile", PROFILE],
            capture_output=True, text=True
        )
        if result.returncode == 0:
            print(f"    触发成功")
        else:
            print(f"    [WARN] {result.stderr.strip()}")


def main():
    print("=" * 60)
    print("maxcompute2lakehouse-ecommerce  E2E 验证")
    mode = "RESET + 全量" if DO_RESET else "增量"
    print(f"  模式: {mode}  profile: {PROFILE}")
    print("=" * 60)

    session = make_session()
    try:
        if DO_RESET:
            step_reset(session)

        if not SKIP_SQL:
            step_transform(session)

        step_summary(session)
    finally:
        session.close()

    step_tasks()

    print("\n" + "=" * 60)
    print("E2E 完成")
    print("=" * 60)


if __name__ == "__main__":
    main()
