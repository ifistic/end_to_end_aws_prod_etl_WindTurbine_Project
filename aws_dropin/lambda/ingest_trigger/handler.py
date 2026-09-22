"""
ingest_trigger Lambda

Triggered by EventBridge on s3://<bucket>/landing/. Validates the file, moves
CSVs to raw/, moves the original to archive/ (or quarantine/), and starts Glue.
"""

import os
import re
import urllib.parse
import zipfile
from pathlib import PurePosixPath

import boto3

s3 = boto3.client("s3")
glue = boto3.client("glue")
sns = boto3.client("sns")

GLUE_JOB_NAME = os.environ["GLUE_JOB_NAME"]
SNS_TOPIC_ARN = os.environ["SNS_TOPIC_ARN"]
RAW_PREFIX = os.environ.get("RAW_PREFIX", "raw/")
RERUN_MARKER = os.environ.get("RERUN_MARKER", "control/rerun_requested")

EXPECTED_COLUMNS = {"timestamp", "turbine_id", "wind_speed", "wind_direction", "power_output"}
UPLOAD_STAMP = re.compile(r"^\d{8}T\d{6}Z_")


def header_ok(first_line: bytes) -> bool:
    cols = {c.strip().strip('"').lower() for c in first_line.decode("utf-8-sig").strip().split(",")}
    return EXPECTED_COLUMNS.issubset(cols)


def raw_name(filename: str) -> str:
    return UPLOAD_STAMP.sub("", PurePosixPath(filename).name)


def alert(subject: str, message: str) -> None:
    sns.publish(TopicArn=SNS_TOPIC_ARN, Subject=subject[:99], Message=message)


def move(bucket: str, key: str, new_prefix: str) -> None:
    s3.copy_object(Bucket=bucket, Key=new_prefix + key, CopySource={"Bucket": bucket, "Key": key})
    s3.delete_object(Bucket=bucket, Key=key)


def process_zip(bucket: str, key: str):
    local = "/tmp/landed.zip"
    s3.download_file(bucket, key, local)
    accepted, rejected = [], []
    with zipfile.ZipFile(local) as zf:
        for member in zf.namelist():
            name = PurePosixPath(member).name
            if not name.lower().endswith(".csv") or member.startswith("__MACOSX") or name.startswith("._"):
                continue
            with zf.open(member) as fh:
                ok = header_ok(fh.readline())
            if not ok:
                rejected.append(member)
                continue
            with zf.open(member) as fh:
                s3.upload_fileobj(fh, bucket, RAW_PREFIX + raw_name(name))
            accepted.append(raw_name(name))
    os.remove(local)
    return accepted, rejected


def process_csv(bucket: str, key: str):
    first = s3.get_object(Bucket=bucket, Key=key, Range="bytes=0-4095")["Body"].read()
    if not header_ok(first.split(b"\n", 1)[0]):
        return [], [key]
    target = RAW_PREFIX + raw_name(key)
    s3.copy_object(Bucket=bucket, Key=target, CopySource={"Bucket": bucket, "Key": key})
    return [raw_name(key)], []


def start_pipeline(bucket: str) -> str:
    try:
        run_id = glue.start_job_run(JobName=GLUE_JOB_NAME)["JobRunId"]
        return f"started {run_id}"
    except glue.exceptions.ConcurrentRunsExceededException:
        s3.put_object(Bucket=bucket, Key=RERUN_MARKER, Body=b"1")
        return "run already in progress; rerun queued"


def handler(event, context):
    bucket = event["detail"]["bucket"]["name"]
    key = urllib.parse.unquote_plus(event["detail"]["object"]["key"])
    print(f"Landed: s3://{bucket}/{key}")
    lower = key.lower()
    if lower.endswith(".zip"):
        accepted, rejected = process_zip(bucket, key)
    elif lower.endswith(".csv"):
        accepted, rejected = process_csv(bucket, key)
    else:
        accepted, rejected = [], [key]
    if not accepted:
        move(bucket, key, "quarantine/")
        alert("Wind turbine pipeline: file rejected",
              f"s3://{bucket}/{key} had no valid turbine CSVs; moved to quarantine/.\n"
              f"Expected header columns: {sorted(EXPECTED_COLUMNS)}")
        return {"status": "quarantined", "key": key}
    if rejected:
        alert("Wind turbine pipeline: some files skipped",
              f"From s3://{bucket}/{key}, these had unexpected headers and were skipped: {rejected}")
    move(bucket, key, "archive/")
    status = start_pipeline(bucket)
    print(f"Accepted {accepted}; {status}")
    return {"status": status, "accepted": accepted, "rejected": rejected}
