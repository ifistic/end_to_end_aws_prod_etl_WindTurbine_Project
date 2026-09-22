# Which Terraform and which providers this config needs.

terraform {
  # 1.10 added native S3 state locking (use_lockfile in the S3 backend), which
  # the environment configs use. Older Terraform would fail to init them.
  required_version = ">= 1.10.0"

  required_providers {
    # aws: talks to AWS. Pinned to the 5.40+ line for stability.
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.40"
    }
    # local: writes the backend.hcl files onto your disk so each environment
    # knows where its state lives. Only used in bootstrap/.
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
  # This config deliberately uses LOCAL state (a terraform.tfstate file next
  # to these .tf files), because it creates the very bucket that other
  # configs will store their state in.
}

# provider "aws": the AWS provider needs to know which region to talk to.
provider "aws" {
  region = var.aws_region

  # default_tags: every taggable resource this config creates gets these tags.
  # Handy for filtering in the AWS console and cost reports.
  default_tags {
    tags = {
      Project   = var.project_name
      ManagedBy = "terraform"
      Purpose   = "terraform-state"
    }
  }
}
