#!/usr/bin/env python3
"""
reset.py — 清理所有迁移创建的 Lakehouse 对象

清理范围：
  - ecommerce schema 下所有表
  - ecommerce_dwd schema 下所有表
  - ecommerce_ads schema 下所有表
  - Volume：ecommerce.ecommerce_vol
  - Schema：ecommerce / ecommerce_dwd / ecommerce_ads

用法：
  python 03_lakehouse/reset.py           # 预览将要删除的对象（dry run）
  python 03_lakehouse/reset.py --confirm # 实际执行删除
"""

import os
import sys
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

DRY_RUN = "--confirm" not in sys.argv


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


def drop(session, obj_type, schema, name):
    stmt = f"DROP {obj_type} IF EXISTS {schema}.{name}"
    if DRY_RUN:
        print(f"  [DRY RUN] {stmt}")
    else:
        session.sql(stmt).collect()
        print(f"  {stmt}")


def main():
    if DRY_RUN:
        print("=" * 60)
        print("reset.py — DRY RUN（预览模式，不实际删除）")
        print("加 --confirm 参数执行实际删除")
        print("=" * 60)
    else:
        print("=" * 60)
        print("reset.py — 清理所有迁移对象")
        print("=" * 60)

    session = make_session()
    try:
        # 删除各 schema 下的所有表
        for schema in [ods_schema, dwd_schema, ads_schema]:
            rows = session.sql(f"SHOW TABLES IN {schema}").collect()
            if rows:
                print(f"\n[{schema}] 删除 {len(rows)} 张表")
                for row in rows:
                    tname = row.as_dict().get("table_name")
                    if tname:
                        drop(session, "TABLE", schema, tname)
            else:
                print(f"\n[{schema}] 无表，跳过")

        # 删除 Volume
        print(f"\n[Volume] 删除 {SCHEMA_NAME}.{VOLUME_NAME}")
        stmt = f"DROP VOLUME IF EXISTS {SCHEMA_NAME}.{VOLUME_NAME}"
        if DRY_RUN:
            print(f"  [DRY RUN] {stmt}")
        else:
            session.sql(stmt).collect()
            print(f"  {stmt}")

        # 删除 Schema（顺序：先子 schema，再主 schema）
        for schema in [ads_schema, dwd_schema, ods_schema]:
            stmt = f"DROP SCHEMA IF EXISTS {schema}"
            if DRY_RUN:
                print(f"  [DRY RUN] {stmt}")
            else:
                session.sql(stmt).collect()
                print(f"  {stmt}")

    finally:
        session.close()

    print("\n" + "=" * 60)
    if DRY_RUN:
        print("DRY RUN 完成。运行 python 03_lakehouse/reset.py --confirm 执行实际删除")
    else:
        print("清理完成")
    print("=" * 60)


if __name__ == "__main__":
    main()
