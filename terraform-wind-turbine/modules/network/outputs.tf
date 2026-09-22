# What the module exposes to the rest of the config.

output "vpc_id" {
  value = aws_vpc.main.id
}

output "private_subnet_ids" {
  value = aws_subnet.private[*].id
}

output "private_subnet_azs" {
  value = aws_subnet.private[*].availability_zone
}

output "security_group_id" {
  value = aws_security_group.data_pipeline.id
}

output "bastion_public_ip" {
  value = try(aws_instance.bastion[0].public_ip, null)
}
