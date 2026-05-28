#!/usr/bin/env python3
"""
e2e.py — 端到端全流程验证

执行顺序：
  1. 环境校验（ENV CHECK）：环境变量、cz-cli、profile、Lakehouse 连接
  2. DWD 层建表（03_dwd_create_tables.sql）
  3. DWD 层数据填充（04_dwd_transform.sql）
  4. ADS 层转换（05_ads_transform.sql）
  5. 数据质量框架（06_data_quality.sql）
  6. 数据汇总（各层行数）
  7. 数据校验（行数断言 + 业务断言）
  8. Studio 任务触发验证

用法：
  python 03_lakehouse/e2e.py               # 增量运行
  python 03_lakehouse/e2e.py --reset       # 先清空所有表，再全量跑
  python 03_lakehouse/e2e.py --skip-sql    # 跳过 SQL 转换，只跑数据校验和 task 验证

清理环境（删除所有表、Volume、Schema、Studio 任务）：
  python 03_lakehouse/reset.py             # 预览（dry run）
  python 03_lakehouse/reset.py --confirm   # 实际执行
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

# ── Ground truth（来自实际 e2e 验证结果）────────────────────────────────────
EXPECTED_COUNTS = {
    f"{ods_schema}.customers":              10,
    f"{ods_schema}.products":               10,
    f"{ods_schema}.orders":                 10,
    f"{ods_schema}.order_items":            30,
    f"{ods_schema}.web_sessions":           20,
    f"{ods_schema}.page_views":             30,
    f"{ods_schema}.user_events":            30,
    f"{ods_schema}.suppliers":               9,
    f"{dwd_schema}.daily_sales_summary":     4,
    f"{dwd_schema}.customer_segments":      10,
    f"{dwd_schema}.product_performance":    10,
    f"{ads_schema}.web_analytics_summary":   1,
    f"{ads_schema}.customer_changes":        0,
    f"{ads_schema}.data_quality_metrics":    3,
    f"{ads_schema}.dq_rules":               6,
    f"{ads_schema}.dq_assessment":          6,
    f"{ads_schema}.data_profile":           3,
}


def step_check_env():
    """校验运行环境：环境变量、cz-cli、profile、Lakehouse 连接"""
    print("\n[ENV CHECK] 校验运行环境")
    ok = True

    # 1. 必填环境变量
    required_vars = [
        "CLICKZETTA_SERVICE",
        "CLICKZETTA_INSTANCE",
        "CLICKZETTA_WORKSPACE",
        "CLICKZETTA_USERNAME",
        "CLICKZETTA_PASSWORD",
    ]
    missing = [v for v in required_vars if not os.environ.get(v)]
    if missing:
        print(f"  FAIL 缺少环境变量: {', '.join(missing)}")
        print("       请复制 .env.example 为 .env 并填写")
        ok = False
    else:
        print(f"  OK   环境变量（{len(required_vars)} 项）")

    # 2. cz-cli 可用
    result = subprocess.run(["cz-cli", "--version"], capture_output=True, text=True)
    if result.returncode == 0:
        ver = (result.stdout.strip() or result.stderr.strip()).splitlines()[0]
        print(f"  OK   cz-cli {ver}")
    else:
        print("  FAIL cz-cli 未安装或不在 PATH 中")
        ok = False

    # 3. profile 存在
    result = subprocess.run(["cz-cli", "profile", "list"], capture_output=True, text=True)
    if PROFILE in result.stdout:
        print(f"  OK   profile '{PROFILE}' 存在")
    else:
        print(f"  WARN profile '{PROFILE}' 不存在，请先运行 python 03_lakehouse/setup.py")
        ok = False

    if not ok:
        print("\n  环境校验失败，请修复上述问题后重试")
        sys.exit(1)

    # 4. Lakehouse 连接（快速验证，独立 session）
    try:
        s = make_session()
        s.sql("SELECT 1").collect()
        s.close()
        print("  OK   Lakehouse 连接")
    except Exception as e:
        print(f"  FAIL Lakehouse 连接失败: {e}")
        sys.exit(1)

    print("  环境校验通过\n")


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
            tname = row.as_dict().get("table_name")
            if tname:
                session.sql(f"DROP TABLE IF EXISTS {schema}.{tname}").collect()
                print(f"  DROP {schema}.{tname}")


def step_transform(session):
    sql_dir = LAKEHOUSE / "sql"
    print("\n[1/4] DWD 层建表")
    run_sql_file(session, sql_dir / "03_dwd_create_tables.sql")
    print("\n[2/4] DWD 层数据填充")
    run_sql_file(session, sql_dir / "04_dwd_transform.sql")
    print("\n[3/4] ADS 层转换")
    run_sql_file(session, sql_dir / "05_ads_transform.sql")
    print("\n[4/4] 数据质量框架")
    run_sql_file(session, sql_dir / "06_data_quality.sql")


def step_summary(session):
    print("\n=== 数据汇总 ===")
    layers = {
        ods_schema: ["customers", "products", "orders", "order_items",
                     "web_sessions", "page_views", "user_events", "suppliers"],
        dwd_schema: ["daily_sales_summary", "customer_segments", "product_performance"],
        ads_schema: ["web_analytics_summary", "customer_changes", "data_quality_metrics",
                     "dq_rules", "dq_assessment", "data_profile"],
    }
    for schema, tables in layers.items():
        print(f"\n{schema}:")
        for t in tables:
            try:
                n = session.sql(f"SELECT COUNT(*) cnt FROM {schema}.{t}").collect()[0]["cnt"]
                print(f"  {t:<25} {n:>6} 行")
            except Exception:
                print(f"  {t:<25}  (不存在)")


def _check(session, label, query, expected):
    """执行单条校验，返回 (passed: bool)"""
    try:
        actual = session.sql(query).collect()[0][0]
        if actual == expected:
            print(f"  PASS  {label}  ({actual})")
            return True
        else:
            print(f"  FAIL  {label}  期望={expected}  实际={actual}")
            return False
    except Exception as e:
        print(f"  ERROR {label}  {e}")
        return False


def step_check_data(session):
    """数据校验：行数断言 + 业务断言"""
    print("\n=== 数据校验 ===")
    passed = 0
    total  = 0

    # ── 行数断言 ────────────────────────────────────────────────────────────
    print("\n[行数断言]")
    for full_table, expected_count in EXPECTED_COUNTS.items():
        total += 1
        ok = _check(
            session,
            full_table,
            f"SELECT COUNT(*) FROM {full_table}",
            expected_count,
        )
        if ok:
            passed += 1

    # ── ODS 完整性断言 ───────────────────────────────────────────────────────
    print("\n[ODS 完整性]")
    ods_checks = [
        # 主键非空
        ("customers.customer_id 无 NULL",
         f"SELECT COUNT(*) FROM {ods_schema}.customers WHERE customer_id IS NULL", 0),
        ("orders.order_id 无 NULL",
         f"SELECT COUNT(*) FROM {ods_schema}.orders WHERE order_id IS NULL", 0),
        ("order_items.order_id 无 NULL",
         f"SELECT COUNT(*) FROM {ods_schema}.order_items WHERE order_id IS NULL", 0),
        # 金额合理性：orders 中 total_amount 均为正数
        ("orders.total_amount 全部 > 0",
         f"SELECT COUNT(*) FROM {ods_schema}.orders WHERE CAST(total_amount AS DOUBLE) <= 0", 0),
        # 关联完整性：order_items 中的 order_id 都能在 orders 中找到
        ("order_items.order_id 全部存在于 orders",
         f"""SELECT COUNT(*) FROM {ods_schema}.order_items oi
             WHERE NOT EXISTS (
                 SELECT 1 FROM {ods_schema}.orders o WHERE o.order_id = oi.order_id
             )""", 0),
    ]
    for label, query, expected in ods_checks:
        total += 1
        if _check(session, label, query, expected):
            passed += 1

    # ── DWD 业务断言 ─────────────────────────────────────────────────────────
    print("\n[DWD 业务断言]")
    dwd_checks = [
        # daily_sales_summary 总收入 > 0
        ("daily_sales_summary 总收入 > 0",
         f"SELECT COUNT(*) FROM {dwd_schema}.daily_sales_summary WHERE total_revenue <= 0", 0),
        # customer_segments 覆盖全部 10 位客户
        ("customer_segments 覆盖全部客户",
         f"SELECT COUNT(DISTINCT customer_id) FROM {dwd_schema}.customer_segments", 10),
        # customer_segments 包含 3 个分层
        ("customer_segments 包含 3 个分层",
         f"SELECT COUNT(DISTINCT segment) FROM {dwd_schema}.customer_segments", 3),
        # product_performance 覆盖全部 10 个商品
        ("product_performance 覆盖全部商品",
         f"SELECT COUNT(DISTINCT product_id) FROM {dwd_schema}.product_performance", 10),
    ]
    for label, query, expected in dwd_checks:
        total += 1
        if _check(session, label, query, expected):
            passed += 1

    # ── ADS 业务断言 ─────────────────────────────────────────────────────────
    print("\n[ADS 业务断言]")
    ads_checks = [
        # dq_rules 规则名无 NULL
        ("dq_rules.rule_name 无 NULL",
         f"SELECT COUNT(*) FROM {ads_schema}.dq_rules WHERE rule_name IS NULL", 0),
        # dq_assessment 至少有 1 条 PASS
        ("dq_assessment 至少 1 条 PASS",
         f"SELECT COUNT(*) FROM {ads_schema}.dq_assessment WHERE status = 'PASS'",
         # 期望值：大于 0，用 > 0 断言
         None),
        # data_profile 覆盖 3 张表
        ("data_profile 覆盖 3 张表",
         f"SELECT COUNT(DISTINCT table_name) FROM {ads_schema}.data_profile", 3),
    ]
    for label, query, expected in ads_checks:
        total += 1
        if expected is None:
            # 特殊断言：只要 > 0 即通过
            try:
                actual = session.sql(query).collect()[0][0]
                if actual > 0:
                    print(f"  PASS  {label}  ({actual} 条)")
                    passed += 1
                else:
                    print(f"  FAIL  {label}  期望 > 0，实际 = 0")
            except Exception as e:
                print(f"  ERROR {label}  {e}")
        else:
            if _check(session, label, query, expected):
                passed += 1

    # ── 汇总 ─────────────────────────────────────────────────────────────────
    print(f"\n  校验结果：{passed}/{total} 通过", end="")
    if passed == total:
        print("  ✓ 全部通过")
    else:
        print(f"  ✗ {total - passed} 项失败")
    return passed == total


def step_tasks():
    """通过 cz-cli task 触发 Studio 任务，验证 DataWorks workflow 迁移结果。"""
    print("\n=== Studio 任务验证 ===")
    task_list_file = LAKEHOUSE / "tasks" / "task_list.txt"
    if not task_list_file.exists():
        print("  [SKIP] tasks/task_list.txt 不存在，跳过任务验证")
        print("  提示：运行 cz-cli task list --profile ecommerce_dev 查看已创建的任务")
        return

    task_names = [l.strip() for l in task_list_file.read_text().splitlines()
                  if l.strip() and not l.strip().startswith('#')]
    for task in task_names:
        result = subprocess.run(
            ["cz-cli", "task", "execute", task, "--profile", PROFILE],
            capture_output=True, text=True
        )
        if result.returncode == 0:
            print(f"  {task:<30} 触发成功")
        else:
            print(f"  {task:<30} [WARN] {result.stderr.strip()}")


def main():
    print("=" * 60)
    print("maxcompute2lakehouse-ecommerce  E2E 验证")
    mode = "RESET + 全量" if DO_RESET else "增量"
    print(f"  模式: {mode}  profile: {PROFILE}")
    print("=" * 60)

    step_check_env()

    session = make_session()
    all_passed = True
    try:
        if DO_RESET:
            step_reset(session)
            print("\n[RELOAD] 重新建表并加载数据")
            run_sql_file(session, LAKEHOUSE / "sql" / "01_create_tables.sql")
            run_sql_file(session, LAKEHOUSE / "sql" / "02_load_data.sql")

        if not SKIP_SQL:
            step_transform(session)

        step_summary(session)
        all_passed = step_check_data(session)
    finally:
        session.close()

    step_tasks()

    print("\n" + "=" * 60)
    if all_passed:
        print("E2E 完成  — 全部校验通过")
    else:
        print("E2E 完成  — 存在校验失败项，请检查上方输出")
    print("=" * 60)

    if not all_passed:
        sys.exit(1)


if __name__ == "__main__":
    main()
