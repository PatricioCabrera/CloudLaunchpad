data "aws_availability_zones" "main" {
}

locals {
  subnets = {
    "public-a" = {
      cidr   = "10.0.0.0/27"
      az     = data.aws_availability_zones.main.names[0]
      public = true
    }
    "public-b" = {
      cidr   = "10.0.0.32/27"
      az     = data.aws_availability_zones.main.names[1]
      public = true
    }
    "private-a" = {
      cidr   = "10.0.1.0/24"
      az     = data.aws_availability_zones.main.names[0]
      public = false
    }
    "private-b" = {
      cidr   = "10.0.2.0/24"
      az     = data.aws_availability_zones.main.names[1]
      public = false
    }
  }
}

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/21"
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
