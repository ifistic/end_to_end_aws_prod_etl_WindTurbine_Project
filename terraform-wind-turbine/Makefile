# Shortcuts for day-to-day Terraform commands.
# Use '>' instead of tab so the file survives copy-paste.
.RECIPEPREFIX := >

# Pick the environment; override with: make apply ENV=staging
ENV ?= dev
TF  := terraform -chdir=environments/$(ENV)

.PHONY: bootstrap build init plan apply destroy fmt validate output

bootstrap:
> terraform -chdir=bootstrap init
> terraform -chdir=bootstrap apply

build:
> bash ../aws_dropin/scripts/build.sh

init:
> $(TF) init -backend-config=backend.hcl

plan: build
> $(TF) plan

apply: build
> $(TF) apply

destroy:
> $(TF) destroy

fmt:
> terraform fmt -recursive

validate:
> $(TF) validate

output:
> $(TF) output
