import os

SCHEMA_NAME        = os.environ.get("CLICKZETTA_SCHEMA", "ecommerce")
VOLUME_NAME        = os.environ.get("CLICKZETTA_VOLUME", "ecommerce_vol")
VOLUME_PATH        = f"vol://{SCHEMA_NAME}.{VOLUME_NAME}"

ods_schema         = SCHEMA_NAME
dwd_schema         = "ecommerce_dwd"
ads_schema         = "ecommerce_ads"
