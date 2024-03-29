# Create VPC
# Source: https://www.terraform.io/docs/providers/aws/r/vpc.html
resource "aws_vpc" "spoke_vpc" {
  cidr_block           = "${var.slash_16_cidr_block}"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name               = "${var.client_name_friendly} Spoke VPC"
    "user:client"      = "${var.aws_client_tag}"
    "user:stack"       = "${var.aws_stack_tag}"
    "user:application" = "spoke"
  }
}

# Create Internet Gateway
# Source: https://www.terraform.io/docs/providers/aws/r/internet_gateway.html
resource "aws_internet_gateway" "gw" {
  vpc_id = "${aws_vpc.spoke_vpc.id}"

  tags = {
    Name               = "${var.client_name_friendly} Spoke IGW"
    "user:client"      = "${var.aws_client_tag}"
    "user:stack"       = "${var.aws_stack_tag}"
    "user:application" = "spoke"
  }
}

# Create Subnets
# Source: https://www.terraform.io/docs/providers/aws/r/subnet.html

# Public A
resource "aws_subnet" "public_a" {
  vpc_id            = "${aws_vpc.spoke_vpc.id}"
  cidr_block        = "${cidrsubnet(var.slash_16_cidr_block, 8, 1)}"
  availability_zone = "${var.aws_region}a"

  tags = {
    Name               = "${var.client_name_friendly} Public A"
    "user:client"      = "${var.aws_client_tag}"
    "user:stack"       = "${var.aws_stack_tag}"
    "user:application" = "spoke"
  }
}

# Public B
resource "aws_subnet" "public_b" {
  vpc_id            = "${aws_vpc.spoke_vpc.id}"
  cidr_block        = "${cidrsubnet(var.slash_16_cidr_block, 8, 2)}"
  availability_zone = "${var.aws_region}b"

  tags = {
    Name               = "${var.client_name_friendly} Public B"
    "user:client"      = "${var.aws_client_tag}"
    "user:stack"       = "${var.aws_stack_tag}"
    "user:application" = "spoke"
  }
}

# Private A
resource "aws_subnet" "private_a" {
  vpc_id            = "${aws_vpc.spoke_vpc.id}"
  cidr_block        = "${cidrsubnet(var.slash_16_cidr_block, 8, 3)}"
  availability_zone = "${var.aws_region}a"

  tags = {
    Name               = "${var.client_name_friendly} Private A"
    "user:client"      = "${var.aws_client_tag}"
    "user:stack"       = "${var.aws_stack_tag}"
    "user:application" = "spoke"
  }
}

# Private B
resource "aws_subnet" "private_b" {
  vpc_id            = "${aws_vpc.spoke_vpc.id}"
  cidr_block        = "${cidrsubnet(var.slash_16_cidr_block, 8, 4)}"
  availability_zone = "${var.aws_region}b"

  tags = {
    Name               = "${var.client_name_friendly} Private B"
    "user:client"      = "${var.aws_client_tag}"
    "user:stack"       = "${var.aws_stack_tag}"
    "user:application" = "spoke"
  }
}

# Create EIP for NAT
# Source: https://www.terraform.io/docs/providers/aws/r/eip.html
resource "aws_eip" "lambda_nat" {
  vpc = true

  tags = {
    Name               = "${var.client_name_friendly} Lambda NAT EIP"
    "user:client"      = "${var.aws_client_tag}"
    "user:stack"       = "${var.aws_stack_tag}"
    "user:application" = "spoke"
  }

  depends_on = ["aws_internet_gateway.gw"]
}

# Create NAT Gateway
# Source: https://www.terraform.io/docs/providers/aws/r/nat_gateway.html
resource "aws_nat_gateway" "gw" {
  allocation_id = "${aws_eip.lambda_nat.id}"
  subnet_id     = "${aws_subnet.public_a.id}"

  tags = {
    Name               = "${var.client_name_friendly} Lambda NAT"
    "user:client"      = "${var.aws_client_tag}"
    "user:stack"       = "${var.aws_stack_tag}"
    "user:application" = "spoke"
  }

  # Source: https://www.terraform.io/docs/providers/aws/r/nat_gateway.html#argument-reference
  depends_on = ["aws_internet_gateway.gw"]
}

# Create Route Tables
# Source: https://www.terraform.io/docs/providers/aws/r/route_table.html

# Public
resource "aws_route_table" "public" {
  vpc_id = "${aws_vpc.spoke_vpc.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.gw.id}"
  }

  tags = {
    Name               = "${var.client_name_friendly} Public Route Table"
    "user:client"      = "${var.aws_client_tag}"
    "user:stack"       = "${var.aws_stack_tag}"
    "user:application" = "spoke"
  }
}

# Private
resource "aws_route_table" "private" {
  vpc_id = "${aws_vpc.spoke_vpc.id}"

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = "${aws_nat_gateway.gw.id}"
  }

  tags = {
    Name               = "${var.client_name_friendly} Private Route Table"
    "user:client"      = "${var.aws_client_tag}"
    "user:stack"       = "${var.aws_stack_tag}"
    "user:application" = "spoke"
  }
}

# Add Subnets to Route Tables
# Source: https://www.terraform.io/docs/providers/aws/r/route_table_association.html

# Public Route Table
resource "aws_route_table_association" "public_a" {
  subnet_id      = "${aws_subnet.public_a.id}"
  route_table_id = "${aws_route_table.public.id}"
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = "${aws_subnet.public_b.id}"
  route_table_id = "${aws_route_table.public.id}"
}

# Private Route Table
resource "aws_route_table_association" "private_a" {
  subnet_id      = "${aws_subnet.private_a.id}"
  route_table_id = "${aws_route_table.private.id}"
}

resource "aws_route_table_association" "private_b" {
  subnet_id      = "${aws_subnet.private_b.id}"
  route_table_id = "${aws_route_table.private.id}"
}
