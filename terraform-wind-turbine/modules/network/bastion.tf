variable "create_bastion" {
  type    = bool
  default = false
}

variable "bastion_key_name" {
  type    = string
  default = ""
}

variable "my_ip_cidr" {
  type    = string
  default = "0.0.0.0/0"
}

data "aws_ssm_parameter" "al2023" {
  count = var.create_bastion ? 1 : 0
  name  = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

resource "aws_internet_gateway" "bastion" {
  count  = var.create_bastion ? 1 : 0
  vpc_id = aws_vpc.main.id
  tags   = merge(var.tags, { Name = "${var.project_name}-bastion-igw" })
}

resource "aws_subnet" "bastion" {
  count                   = var.create_bastion ? 1 : 0
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, 10)
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true
  tags                    = merge(var.tags, { Name = "${var.project_name}-bastion-subnet" })
}

resource "aws_route_table" "bastion" {
  count  = var.create_bastion ? 1 : 0
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.bastion[0].id
  }

  tags = merge(var.tags, { Name = "${var.project_name}-bastion-rt" })
}

resource "aws_route_table_association" "bastion" {
  count          = var.create_bastion ? 1 : 0
  subnet_id      = aws_subnet.bastion[0].id
  route_table_id = aws_route_table.bastion[0].id
}

resource "aws_security_group" "bastion" {
  count       = var.create_bastion ? 1 : 0
  name        = "${var.project_name}-bastion-sg"
  description = "SSH access to bastion for DBeaver tunnel"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = var.tags
}

resource "aws_security_group_rule" "bastion_to_rds" {
  count                    = var.create_bastion ? 1 : 0
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = aws_security_group.data_pipeline.id
  source_security_group_id = aws_security_group.bastion[0].id
}

resource "aws_instance" "bastion" {
  count                       = var.create_bastion ? 1 : 0
  ami                         = data.aws_ssm_parameter.al2023[0].value
  instance_type               = "t3.nano"
  subnet_id                   = aws_subnet.bastion[0].id
  vpc_security_group_ids      = [aws_security_group.bastion[0].id]
  key_name                    = var.bastion_key_name
  associate_public_ip_address = true
  tags                        = merge(var.tags, { Name = "${var.project_name}-bastion" })
}
