# Terraform + provider versions for the dev environment.

terraform {
  # 1.10+ for native S3 state locking (use_lockfile).
  required_version = ">= 1.10.0"

  required_providers {
    # aws: manages AWS resources.
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.40"
    }
    # random: creates the RDS password and the bucket-name suffix.
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    # archive: zips Lambda source folders on the fly.
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
  }
}

# provider "aws": region + tags every resource picks up automatically.
provider "aws" {
  region = var.aws_region

  # default_tags land on every taggable resource. Handy for cost tracking
  # and for confirming a clean destroy: filter by Project=... and expect 0.
  # The extra EMR tag is only added when EMR is enabled, because EMR's
  # managed IAM policy only allows creating resources with that tag.
  default_tags {
    tags = merge(
      var.tags,
      { Environment = var.environment },
      var.enable_emr ? { "for-use-with-amazon-emr-managed-policies" = "true" } : {}
    )
  }
}
