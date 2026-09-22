"""
post_run Lambda

Triggered when the Glue job reaches a final state, and hourly as a safety net.
If files landed while a run was in progress, it starts one more run.
"""

import os
import boto3

s3 = boto3.client("s3")
glue = boto3.client("glue")

DATA_BUCKET = os.environ["DATA_BUCKET"]
GLUE_JOB_NAME = os.environ["GLUE_JOB_NAME"]
RERUN_MARKER = os.environ.get("RERUN_MARKER", "control/rerun_requested")


def rerun_requested() -> bool:
    try:
        s3.head_object(Bucket=DATA_BUCKET, Key=RERUN_MARKER)
        return True
    except s3.exceptions.ClientError:
        return False


def handler(event, context):
    state = event.get("detail", {}).get("state", "SCHEDULED_CHECK")
    print(f"Trigger: {state}")
    if not rerun_requested():
        return {"status": "nothing queued"}
    try:
        run_id = glue.start_job_run(JobName=GLUE_JOB_NAME)["JobRunId"]
    except glue.exceptions.ConcurrentRunsExceededException:
        return {"status": "still running; marker kept for next check"}
    s3.delete_object(Bucket=DATA_BUCKET, Key=RERUN_MARKER)
    print(f"Started queued run {run_id}")
    return {"status": "started", "run_id": run_id}
