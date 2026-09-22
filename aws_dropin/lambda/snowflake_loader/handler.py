"""
snowflake_loader Lambda

Triggered when the Glue job SUCCEEDS. Reloads Snowflake tables from
s3://<bucket>/curated/latest/ inside one transaction per table.
"""

import json
import os
import boto3
import snowflake.connector
from cryptography.hazmat.primitives import serialization

SECRET_NAME = os.environ["SNOWFLAKE_SECRET_NAME"]
STAGE = os.environ.get("SNOWFLAKE_STAGE", "WIND_TURBINE_CURATED_STAGE")

TABLES = {
    "SILVER_TURBINE_READINGS": "silver/",
    "GOLD_SUMMARY_STATISTICS": "gold/summary_statistics/",
    "GOLD_ANOMALIES": "gold/anomalies/",
}


def connect():
    secret = json.loads(boto3.client("secretsmanager").get_secret_value(SecretId=SECRET_NAME)["SecretString"])
    key = serialization.load_pem_private_key(secret["private_key"].encode(), password=None)
    key_der = key.private_bytes(
        encoding=serialization.Encoding.DER,
        format=serialization.PrivateFormat.PKCS8,
        encryption_algorithm=serialization.NoEncryption(),
    )
    return snowflake.connector.connect(
        account=secret["account"], user=secret["user"], private_key=key_der,
        role=secret["role"], warehouse=secret["warehouse"],
        database=secret["database"], schema=secret["schema"],
    )


def handler(event, context):
    run_id = event.get("detail", {}).get("jobRunId", "manual")
    results = {}
    conn = connect()
    try:
        cur = conn.cursor()
        for table, folder in TABLES.items():
            cur.execute("BEGIN")
            cur.execute(f"DELETE FROM {table}")
            cur.execute(f"""
                COPY INTO {table}
                FROM @{STAGE}/{folder}
                FILE_FORMAT = (TYPE = PARQUET)
                MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE
                PATTERN = '.*[.]parquet'
                FORCE = TRUE
                ON_ERROR = ABORT_STATEMENT
            """)
            cur.execute("COMMIT")
            cur.execute(f"SELECT COUNT(*) FROM {table}")
            results[table] = cur.fetchone()[0]
    except Exception:
        conn.cursor().execute("ROLLBACK")
        raise
    finally:
        conn.close()
    print(f"Glue run {run_id} loaded into Snowflake: {results}")
    return results
