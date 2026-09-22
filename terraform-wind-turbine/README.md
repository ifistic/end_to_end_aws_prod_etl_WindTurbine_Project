# Wind turbine pipeline on AWS

Terraform for the pipeline. Flow:
S3 -> EventBridge -> Lambda -> Glue -> RDS PostgreSQL (optional Snowflake and EMR).

## Layout

- Makefile                shortcuts
- bootstrap/              one-time state bucket
- environments/dev/       wires the modules together
- modules/                one folder per concern

## First-time setup

1. Fill in environments/dev/terraform.tfvars
2. make bootstrap
3. make init
4. make apply

## Everyday use

- make plan
- make apply
- make output
- make destroy

## Never commit

- .terraform/ folders
- *.tfstate files
- terraform.tfvars
- backend.hcl
- aws_dropin/build/
