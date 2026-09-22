"""
aws_entrypoint.py

Runs the UNMODIFIED wind_turbine_challenge_2026 pipeline (main.py + src/)
on AWS Glue 5.0 or EMR. Nothing in the repo is edited; this file adapts the
environment around it:

  1. Downloads main.py + src/ from S3 and unpacks it.
  2. Reads RDS credentials from Secrets Manager and exports them as
     POSTGRES_* environment variables (which src/utils/config.py reads).
  3. Downloads every CSV under s3://<data_bucket>/raw/ into raw_data/.
  4. Pre-creates a single-node Spark session that main.py reuses.
  5. Calls main.main() exactly as `python main.py` would.
  6. Uploads data/bronze, data/silver, data/gold back to S3.
"""

import argparse
import json
import os
import shutil
import sys
import zipfile
from datetime import datetime, timezone
from pathlib import Path

import boto3


def log(msg: str) -> None:
    print(f"[aws_entrypoint] {msg}", flush=True)


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser()
    p.add_argument("--data_bucket", required=True)
    p.add_argument("--code_s3_uri", required=True)
    p.add_argument("--secret_name", required=True)
    p.add_argument("--raw_prefix", default="raw/")
    p.add_argument("--output_prefix", default="curated/")
    p.add_argument("--work_dir", default="/tmp/wind_turbine_app")
    p.add_argument("--JOB_RUN_ID", default=None)
    args, _unknown = p.parse_known_args()
    return args


def split_s3_uri(uri: str):
    if not uri.startswith("s3://"):
        raise ValueError(f"Not an S3 URI: {uri}")
    bucket, _, key = uri[5:].partition("/")
    return bucket, key


def unpack_code(s3, code_s3_uri: str, work_dir: Path) -> None:
    if work_dir.exists():
        shutil.rmtree(work_dir)
    work_dir.mkdir(parents=True)
    bucket, key = split_s3_uri(code_s3_uri)
    bundle = work_dir.parent / "wind_turbine_app_bundle.zip"
    s3.download_file(bucket, key, str(bundle))
    with zipfile.ZipFile(bundle) as zf:
        zf.extractall(work_dir)
    bundle.unlink()
    if not (work_dir / "main.py").exists() or not (work_dir / "src").is_dir():
        raise RuntimeError(f"Bundle {code_s3_uri} must contain main.py and src/")
    log(f"Code unpacked into {work_dir}")


def export_db_credentials(secret_name: str) -> None:
    sm = boto3.client("secretsmanager")
    secret = json.loads(sm.get_secret_value(SecretId=secret_name)["SecretString"])
    os.environ["POSTGRES_HOST"] = str(secret["host"])
    os.environ["POSTGRES_PORT"] = str(secret.get("port", 5432))
    os.environ["POSTGRES_DB"] = str(secret["dbname"])
    os.environ["POSTGRES_USER"] = str(secret["username"])
    os.environ["POSTGRES_PASSWORD"] = str(secret["password"])
    log(f"DB credentials loaded for {secret['username']}@{secret['host']}/{secret['dbname']}")


def stage_raw_csvs(s3, bucket: str, prefix: str, raw_dir: Path) -> int:
    raw_dir.mkdir(parents=True, exist_ok=True)
    count = 0
    for page in s3.get_paginator("list_objects_v2").paginate(Bucket=bucket, Prefix=prefix):
        for obj in page.get("Contents", []):
            key = obj["Key"]
            if key.lower().endswith(".csv"):
                s3.download_file(bucket, key, str(raw_dir / Path(key).name))
                count += 1
    if count == 0:
        raise FileNotFoundError(f"No CSV files under s3://{bucket}/{prefix}")
    log(f"Staged {count} raw CSV file(s) into {raw_dir}")
    return count


def precreate_spark_session():
    from pyspark.sql import SparkSession
    spark = (
        SparkSession.builder
        .appName("WindTurbinePipeline")
        .master("local[*]")
        .config("spark.hadoop.fs.defaultFS", "file:///")
        .config("spark.sql.session.timeZone", "UTC")
        .config("spark.sql.parquet.outputTimestampType", "TIMESTAMP_MICROS")
        .getOrCreate()
    )
    log(f"Spark {spark.version} session ready (master={spark.sparkContext.master})")
    return spark


def check_dependency_versions() -> None:
    import pandas
    import sqlalchemy
    log(f"pandas {pandas.__version__}, SQLAlchemy {sqlalchemy.__version__}")
    if int(pandas.__version__.split(".")[0]) < 2 and int(sqlalchemy.__version__.split(".")[0]) >= 2:
        raise RuntimeError("pandas < 2 cannot write with SQLAlchemy 2.x. Rebuild wheels with sqlalchemy==1.4.54.")


def delete_prefix(s3, bucket: str, prefix: str) -> None:
    for page in s3.get_paginator("list_objects_v2").paginate(Bucket=bucket, Prefix=prefix):
        keys = [{"Key": o["Key"]} for o in page.get("Contents", [])]
        if keys:
            s3.delete_objects(Bucket=bucket, Delete={"Objects": keys})


def upload_outputs(s3, bucket: str, output_prefix: str, data_dir: Path, run_id: str) -> None:
    run_prefix = f"{output_prefix}runs/{run_id}/"
    latest_prefix = f"{output_prefix}latest/"
    delete_prefix(s3, bucket, latest_prefix)
    uploaded = 0
    for layer in ("bronze", "silver", "gold"):
        layer_dir = data_dir / layer
        if not layer_dir.exists():
            continue
        for path in layer_dir.rglob("*"):
            if path.is_dir() or path.name.endswith(".crc"):
                continue
            rel = path.relative_to(data_dir).as_posix()
            for prefix in (run_prefix, latest_prefix):
                s3.upload_file(str(path), bucket, prefix + rel)
            uploaded += 1
    log(f"Uploaded {uploaded} file(s) to s3://{bucket}/{run_prefix} and s3://{bucket}/{latest_prefix}")


def run() -> None:
    args = parse_args()
    run_id = args.JOB_RUN_ID or datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    work_dir = Path(args.work_dir)
    s3 = boto3.client("s3")
    unpack_code(s3, args.code_s3_uri, work_dir)
    export_db_credentials(args.secret_name)
    stage_raw_csvs(s3, args.data_bucket, args.raw_prefix, work_dir / "raw_data")
    check_dependency_versions()
    precreate_spark_session()
    sys.path.insert(0, str(work_dir))
    os.chdir(work_dir)
    import main as pipeline
    pipeline.main()
    upload_outputs(s3, args.data_bucket, args.output_prefix, work_dir / "data", run_id)
    log(f"Run {run_id} complete")


if __name__ == "__main__":
    run()
