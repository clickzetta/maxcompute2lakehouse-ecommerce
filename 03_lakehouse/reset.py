#!/usr/bin/env python3
"""
reset.py — 清理所有迁移创建的 Lakehouse 对象

清理范围：
  - Studio 任务（ecommerce_etl 文件夹下的 5 个任务）
  - Studio 任务文件夹：ecommerce_etl
  - ecommerce schema 下所有表
  - ecommerce_dwd schema 下所有表
  - ecommerce_ads schema 下所有表
  - Volume：ecommerce.ecommerce_vol
  - Schema：ecommerce / ecommerce_dwd / ecommerce_ads
  - External Functions（如已通过 register_functions.sql 注册）
  - API Connection：ecommerce_fc_conn（如已创建）
  - cz-cli profile：ecommerce_dev

用法：
  python 03_lakehouse/reset.py           # 预览将要删除的对象（dry run）
  python 03_lakehouse/reset.py --confirm # 实际执行删除
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
from includes.configuration import SCHEMA_NAME, VOLUME_NAME, ods_schema, dwd_schema, ads_schema

DRY_RUN     = "--confirm" not in sys.argv
PROFILE     = os.environ.get("CZ_PROFILE", "ecommerce_dev")
TASK_FOLDER = "ecommerce_etl"

# External Functions 注册在 ecommerce schema 下（register_functions.sql）
EXTERNAL_FUNCTIONS = [
    "ecommerce.text_sentiment",
    "ecommerce.text_keywords",
    "ecommerce.text_similarity",
    "ecommerce.text_word_count",
    "ecommerce.text_language_detect",
    "ecommerce.text_clean",
    "ecommerce.string_utils",
    "ecommerce.string_title_case",
    "ecommerce.string_mask_email",
]
API_CONNECTION = "ecommerce_fc_conn"

TASKS = [
    "data_quality_check",
    "customer_segmentation",
    "product_performance_etl",
    "web_analytics_etl",
    "daily_sales_summary",
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


def run_cz(args, label):
    cmd = ["cz-cli"] + args + ["--profile", PROFILE]
    if DRY_RUN:
        print(f"  [DRY RUN] cz-cli {' '.join(args)}")
        return True
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode == 0:
        print(f"  OK  {label}")
        return True
    else:
        # 任务不存在时不报错，继续
        err = result.stderr.strip() or result.stdout.strip()
        if "not found" in err.lower() or "does not exist" in err.lower():
            print(f"  SKIP {label}（不存在）")
            return True
        print(f"  WARN {label}: {err[:120]}")
        return False


def drop_sql(session, stmt):
    if DRY_RUN:
        print(f"  [DRY RUN] {stmt}")
    else:
        session.sql(stmt).collect()
        print(f"  {stmt}")


def drop_sql_direct(stmt):
    """不依赖已有 session，自建临时 session 执行单条 DROP。"""
    if DRY_RUN:
        print(f"  [DRY RUN] {stmt}")
        return
    try:
        s = make_session()
        s.sql(stmt).collect()
        s.close()
        print(f"  {stmt}")
    except Exception as e:
        err = str(e)
        if "not found" in err.lower() or "does not exist" in err.lower():
            print(f"  SKIP（不存在）: {stmt.split()[2]}")
        else:
            print(f"  WARN {stmt}: {err[:120]}")


def main():
    mode = "DRY RUN（预览模式，不实际删除）" if DRY_RUN else "清理所有迁移对象"
    print("=" * 60)
    print(f"reset.py — {mode}")
    if DRY_RUN:
        print("加 --confirm 参数执行实际删除")
    print("=" * 60)

    # ── Studio 任务 ──────────────────────────────────────────
    print(f"\n[Studio 任务] undeploy + delete（folder: {TASK_FOLDER}）")
    for task in TASKS:
        # 已发布的任务必须先 undeploy 才能 delete
        run_cz(["task", "undeploy", task, "-y"], f"undeploy {task}")
        run_cz(["task", "delete", task, "-y"], f"delete {task}")

    print(f"\n[Studio 文件夹] delete-folder {TASK_FOLDER}")
    run_cz(["task", "delete-folder", TASK_FOLDER, "-y"], f"delete-folder {TASK_FOLDER}")

    # ── Lakehouse 对象 ────────────────────────────────────────
    session = make_session()
    try:
        for schema in [ods_schema, dwd_schema, ads_schema]:
            rows = session.sql(f"SHOW TABLES IN {schema}").collect()
            if rows:
                print(f"\n[{schema}] 删除 {len(rows)} 张表")
                for row in rows:
                    tname = row.as_dict().get("table_name")
                    if tname:
                        drop_sql(session, f"DROP TABLE IF EXISTS {schema}.{tname}")
            else:
                print(f"\n[{schema}] 无表，跳过")

        print(f"\n[Volume] 删除 {SCHEMA_NAME}.{VOLUME_NAME}")
        drop_sql(session, f"DROP VOLUME IF EXISTS {SCHEMA_NAME}.{VOLUME_NAME}")

        print(f"\n[Schema] 删除 {ads_schema} / {dwd_schema} / {ods_schema}")
        for schema in [ads_schema, dwd_schema, ods_schema]:
            drop_sql(session, f"DROP SCHEMA IF EXISTS {schema}")

    finally:
        session.close()

    # ── External Functions（可选，如已通过 register_functions.sql 注册）──────
    print(f"\n[External Functions] 删除（如已注册）")
    for fn in EXTERNAL_FUNCTIONS:
        drop_sql_direct(f"DROP FUNCTION IF EXISTS {fn}")

    print(f"\n[API Connection] 删除 {API_CONNECTION}（如已创建）")
    drop_sql_direct(f"DROP API CONNECTION IF EXISTS {API_CONNECTION}")

    # ── cz-cli profile ────────────────────────────────────────────────────────
    print(f"\n[cz-cli profile] 删除 {PROFILE}")
    if DRY_RUN:
        print(f"  [DRY RUN] cz-cli profile delete {PROFILE}")
    else:
        result = subprocess.run(
            ["cz-cli", "profile", "delete", PROFILE],
            capture_output=True, text=True
        )
        err = result.stderr.strip() or result.stdout.strip()
        if result.returncode == 0:
            print(f"  OK  profile '{PROFILE}' 已删除")
        elif "not found" in err.lower() or "does not exist" in err.lower():
            print(f"  SKIP profile '{PROFILE}'（不存在）")
        else:
            print(f"  WARN {err[:120]}")

    print("\n" + "=" * 60)
    if DRY_RUN:
        print("DRY RUN 完成。运行 python 03_lakehouse/reset.py --confirm 执行实际删除")
    else:
        print("清理完成")
    print("=" * 60)


if __name__ == "__main__":
    main()
