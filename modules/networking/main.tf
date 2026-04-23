data "aws_availability_zones" "main" {
}

locals {
  subnets = { for k, v in var.subnets : k => merge(v, {
    az = data.aws_availability_zones.main.names[index(tolist(keys(var.subnets)), k) % 2]
  }) }
}

resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr
  tags = {
    Name = "main"
  }
}

resource "aws_subnet" "this" {
  for_each = local.subnets

  vpc_id                  = aws_vpc.main.id
  cidr_block              = each.value.cidr
  availability_zone       = each.value.az
  map_public_ip_on_launch = each.value.public

  tags = {
    Name = each.key
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
}

resource "aws_route_table_association" "main" {
  for_each       = { for k, v in local.subnets : k => v if v.public }
  subnet_id      = aws_subnet.this[each.key].id
  route_table_id = aws_route_table.public.id
}
