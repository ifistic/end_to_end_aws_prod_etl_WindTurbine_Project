"""
downloads_to_s3.py

Watches your Downloads folder and uploads new/changed turbine files to
s3://<bucket>/landing/, which triggers the AWS pipeline.

  python downloads_to_s3.py --bucket <data_lake_bucket>          # keep watching
  python downloads_to_s3.py --bucket <data_lake_bucket> --once   # one pass
"""

import argparse
import fnmatch
import hashlib
import json
import re
import time
from datetime import datetime, timezone
from pathlib import Path

import boto3

STATE_FILE = Path.home() / ".wind_turbine_uploader_state.json"
PARTIAL_SUFFIXES = (".crdownload", ".part", ".download", ".tmp")


def load_state() -> dict:
    return json.loads(STATE_FILE.read_text()) if STATE_FILE.exists() else {}


def save_state(state: dict) -> None:
    STATE_FILE.write_text(json.dumps(state, indent=2))


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def is_stable(path: Path, wait: float = 3.0) -> bool:
    size = path.stat().st_size
    time.sleep(wait)
    return path.exists() and path.stat().st_size == size and size > 0


def safe_name(name: str) -> str:
    return re.sub(r"[^A-Za-z0-9._-]", "_", name)


def scan_once(s3, bucket, folder, patterns, state):
    uploaded = 0
    for path in sorted(folder.iterdir()):
        if not path.is_file() or path.name.endswith(PARTIAL_SUFFIXES):
            continue
        if not any(fnmatch.fnmatch(path.name, p) for p in patterns):
            continue
        if not is_stable(path):
            print(f"Still being written, will retry: {path.name}")
            continue
        digest = sha256(path)
        if state.get(str(path)) == digest:
            continue
        stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
        key = f"landing/{stamp}_{safe_name(path.name)}"
        s3.upload_file(str(path), bucket, key)
        state[str(path)] = digest
        save_state(state)
        uploaded += 1
        print(f"Uploaded {path.name} -> s3://{bucket}/{key}")
    return uploaded


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--bucket", required=True)
    p.add_argument("--folder", default=str(Path.home() / "Downloads"))
    p.add_argument("--patterns", nargs="+", default=["data.zip", "data_group_*.csv"])
    p.add_argument("--interval", type=int, default=60)
    p.add_argument("--once", action="store_true")
    args = p.parse_args()
    s3 = boto3.client("s3")
    folder = Path(args.folder).expanduser()
    state = load_state()
    print(f"Watching {folder} for {args.patterns} -> s3://{args.bucket}/landing/")
    while True:
        try:
            scan_once(s3, args.bucket, folder, args.patterns, state)
        except Exception as exc:
            print(f"Scan failed, will retry: {exc}")
        if args.once:
            break
        time.sleep(args.interval)


if __name__ == "__main__":
    main()
