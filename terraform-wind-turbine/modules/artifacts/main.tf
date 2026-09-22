# Uploads the artefacts build.sh produced into the scripts S3 bucket.
# Run build.sh BEFORE terraform apply; if it hasn't run, the precondition
# on aws_s3_object.app will refuse the plan with a helpful message.

locals {
  build_dir = "${var.dropin_dir}/build"
  app_zip   = "${local.build_dir}/app.zip"

  # fileset() lists every .whl file build.sh downloaded into build/wheels/.
  # We iterate over this set to upload each wheel to S3.
  wheel_files = fileset("${local.build_dir}/wheels", "*.whl")
}

# app.zip = your unmodified main.py + src/, packaged by `git archive`.
resource "aws_s3_object" "app" {
  bucket = var.scripts_bucket
  key    = "app/app.zip"
  source = local.app_zip
  # etag changes whenever the file's contents change, so terraform will
  # detect and re-upload when app.zip is rebuilt.
  etag = fileexists(local.app_zip) ? filemd5(local.app_zip) : null

  lifecycle {
    # Refuses to plan if build outputs are missing, with a message telling
    # you exactly what to do about it.
    precondition {
      condition     = fileexists(local.app_zip) && length(local.wheel_files) > 0
      error_message = "Build artefacts missing. Run: bash aws_dropin/scripts/build.sh"
    }
  }
}

# aws_entrypoint.py = the small adapter that Glue actually invokes;
# it downloads app.zip, sets env vars, and runs main.py.
resource "aws_s3_object" "entrypoint" {
  bucket = var.scripts_bucket
  key    = "entrypoint/aws_entrypoint.py"
  source = "${var.dropin_dir}/glue/aws_entrypoint.py"
  etag   = filemd5("${var.dropin_dir}/glue/aws_entrypoint.py")
}

# EMR bootstrap script (only used if EMR is enabled).
resource "aws_s3_object" "emr_bootstrap" {
  bucket = var.scripts_bucket
  key    = "emr/bootstrap.sh"
  source = "${var.dropin_dir}/emr/bootstrap.sh"
  etag   = filemd5("${var.dropin_dir}/emr/bootstrap.sh")
}

# One S3 object per wheel file. for_each keeps them cleanly tracked.
resource "aws_s3_object" "wheels" {
  for_each = local.wheel_files
  bucket   = var.scripts_bucket
  key      = "wheels/${each.value}"
  source   = "${local.build_dir}/wheels/${each.value}"
  etag     = filemd5("${local.build_dir}/wheels/${each.value}")
}
