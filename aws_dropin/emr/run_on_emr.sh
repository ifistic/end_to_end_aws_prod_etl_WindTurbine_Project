#!/usr/bin/env bash
# Runs aws_entrypoint.py on a transient single-node EMR cluster that terminates
# itself when the step finishes. Only used if you turn on enable_emr in Terraform.
set -euo pipefail

TF_DIR="$(git rev-parse --show-toplevel)/terraform-wind-turbine/environments/${ENV:-dev}"
S="$(terraform -chdir="$TF_DIR" output -json emr_settings)"
if [[ "$S" == "null" ]]; then
  echo "EMR is disabled. Set enable_emr = true in environments/${ENV:-dev}/terraform.tfvars and apply." >&2
  exit 1
fi
get() { python3 -c "import json,sys; print(json.loads(sys.argv[1])[sys.argv[2]])" "$S" "$1"; }

DATA_BUCKET="$(get data_bucket)"
SCRIPTS_BUCKET="$(get scripts_bucket)"

STEP_CMD="aws s3 cp s3://$SCRIPTS_BUCKET/entrypoint/aws_entrypoint.py /home/hadoop/aws_entrypoint.py && \
spark-submit --deploy-mode client --master local[*] /home/hadoop/aws_entrypoint.py \
--data_bucket $DATA_BUCKET --code_s3_uri s3://$SCRIPTS_BUCKET/app/app.zip --secret_name $(get db_secret_name)"

STEPS_FILE="$(mktemp)"
python3 - "$STEP_CMD" > "$STEPS_FILE" <<'PY'
import json, sys
print(json.dumps([{
    "Type": "CUSTOM_JAR", "Name": "wind-turbine-pipeline",
    "ActionOnFailure": "TERMINATE_CLUSTER", "Jar": "command-runner.jar",
    "Args": ["bash", "-c", sys.argv[1]],
}]))
PY

aws emr create-cluster \
  --name wind-turbine-pipeline-emr \
  --release-label emr-7.5.0 \
  --applications Name=Spark \
  --instance-type m5.xlarge --instance-count 1 \
  --service-role "$(get service_role)" \
  --ec2-attributes "InstanceProfile=$(get instance_profile),SubnetId=$(get subnet_id),EmrManagedMasterSecurityGroup=$(get master_sg),EmrManagedSlaveSecurityGroup=$(get core_sg),ServiceAccessSecurityGroup=$(get service_access_sg),AdditionalMasterSecurityGroups=$(get additional_sg)" \
  --bootstrap-actions "Path=s3://$SCRIPTS_BUCKET/emr/bootstrap.sh,Name=install-deps" \
  --log-uri "s3://$DATA_BUCKET/emr-logs/" \
  --tags Project=wind-turbine-pipeline for-use-with-amazon-emr-managed-policies=true \
  --steps "file://$STEPS_FILE" \
  --auto-terminate
