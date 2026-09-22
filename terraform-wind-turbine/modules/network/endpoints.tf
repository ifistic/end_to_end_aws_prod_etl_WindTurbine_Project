# S3 gateway endpoint: free, gives the private subnets a path to S3.
resource "aws_vpc_endpoint" "s3" {
  vpc_id          = aws_vpc.main.id
  service_name    = "com.amazonaws.${var.aws_region}.s3"
  route_table_ids = [aws_route_table.private.id]
  tags            = var.tags
}

# Interface endpoints (billed per hour per AZ) for the services Glue
# calls that don't offer a gateway endpoint.
resource "aws_vpc_endpoint" "interface" {
  for_each            = toset(var.interface_endpoints)
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.${each.key}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.data_pipeline.id]
  private_dns_enabled = true
  tags                = var.tags
}
