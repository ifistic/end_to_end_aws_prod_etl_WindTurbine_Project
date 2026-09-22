# Remote state in S3 with native locking. Settings come from backend.hcl,
# which the bootstrap config wrote for you. Init with:
#   terraform init -backend-config=backend.hcl

terraform {
  backend "s3" {}
}
