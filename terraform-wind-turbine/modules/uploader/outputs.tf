output "user_name" {
  value = aws_iam_user.uploader.name
}

output "access_key_id" {
  value = try(aws_iam_access_key.uploader[0].id, null)
}

# secret_access_key is marked sensitive: it won't print in `terraform
# output` unless you ask for it by name with -raw.
output "secret_access_key" {
  value     = try(aws_iam_access_key.uploader[0].secret, null)
  sensitive = true
}
