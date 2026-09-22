#!/usr/bin/env bash
# Builds artefacts Terraform uploads to S3. No AWS calls here.
#   bash aws_dropin/scripts/build.sh
# Then: cd terraform-wind-turbine && make apply
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
BUILD="$REPO_ROOT/aws_dropin/build"
SQLALCHEMY_VERSION="${SQLALCHEMY_VERSION:-2.0.36}"

rm -rf "$BUILD/wheels" "$BUILD/app.zip" "$BUILD/snowflake_layer" "$BUILD/snowflake_layer.zip"
mkdir -p "$BUILD/wheels"

git -C "$REPO_ROOT" archive -o "$BUILD/app.zip" HEAD main.py src
echo "app.zip built from commit $(git -C "$REPO_ROOT" rev-parse --short HEAD)"

python3 -m pip download --quiet \
  --only-binary=:all: --platform manylinux2014_x86_64 \
  --python-version 3.11 --implementation cp \
  -d "$BUILD/wheels" \
  "python-dotenv==1.1.1" "sqlalchemy==$SQLALCHEMY_VERSION" "psycopg2-binary==2.9.10"
echo "wheels: $(ls "$BUILD/wheels" | tr '\n' ' ')"

if [[ "${BUILD_SNOWFLAKE_LAYER:-0}" == "1" ]]; then
  python3 -m pip install --quiet \
    --only-binary=:all: --platform manylinux2014_x86_64 \
    --python-version 3.12 --implementation cp \
    --target "$BUILD/snowflake_layer/python" \
    snowflake-connector-python
  (cd "$BUILD/snowflake_layer" && zip -qr ../snowflake_layer.zip python)
  echo "snowflake_layer.zip built"
fi

echo "Build complete. Next: cd terraform-wind-turbine && make apply ENV=dev"
