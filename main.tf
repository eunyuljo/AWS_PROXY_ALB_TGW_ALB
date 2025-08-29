terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Data sources
data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# Frontend VPC for ALB
resource "aws_vpc" "frontend" {
  cidr_block           = var.frontend_vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.project_name}-frontend-vpc"
  }
}

resource "aws_subnet" "frontend_public" {
  count             = 2
  vpc_id            = aws_vpc.frontend.id
  cidr_block        = cidrsubnet(var.frontend_vpc_cidr, 8, count.index)
  availability_zone = data.aws_availability_zones.available.names[count.index]

  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-frontend-public-${count.index + 1}"
  }
}

resource "aws_internet_gateway" "frontend" {
  vpc_id = aws_vpc.frontend.id

  tags = {
    Name = "${var.project_name}-frontend-igw"
  }
}

resource "aws_route_table" "frontend_public" {
  vpc_id = aws_vpc.frontend.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.frontend.id
  }

  tags = {
    Name = "${var.project_name}-frontend-public-rt"
  }
}

resource "aws_route_table_association" "frontend_public" {
  count          = length(aws_subnet.frontend_public)
  subnet_id      = aws_subnet.frontend_public[count.index].id
  route_table_id = aws_route_table.frontend_public.id
}

# Backend VPC for services
resource "aws_vpc" "backend" {
  cidr_block           = var.backend_vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.project_name}-backend-vpc"
  }
}

resource "aws_subnet" "backend_private" {
  count             = 2
  vpc_id            = aws_vpc.backend.id
  cidr_block        = cidrsubnet(var.backend_vpc_cidr, 8, count.index)
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "${var.project_name}-backend-private-${count.index + 1}"
  }
}

# TGW Configuration
resource "aws_ec2_transit_gateway" "main" {
  description = "Transit Gateway for ALB domain routing"

  tags = {
    Name = "${var.project_name}-tgw"
  }
}

resource "aws_ec2_transit_gateway_vpc_attachment" "frontend" {
  subnet_ids         = aws_subnet.frontend_public[*].id
  transit_gateway_id = aws_ec2_transit_gateway.main.id
  vpc_id             = aws_vpc.frontend.id

  tags = {
    Name = "${var.project_name}-frontend-tgw-attachment"
  }
}

resource "aws_ec2_transit_gateway_vpc_attachment" "backend" {
  subnet_ids         = aws_subnet.backend_private[*].id
  transit_gateway_id = aws_ec2_transit_gateway.main.id
  vpc_id             = aws_vpc.backend.id

  tags = {
    Name = "${var.project_name}-backend-tgw-attachment"
  }
}

# Get TGW default route table
data "aws_ec2_transit_gateway_route_table" "default" {
  filter {
    name   = "default-association-route-table"
    values = ["true"]
  }
  filter {
    name   = "transit-gateway-id"
    values = [aws_ec2_transit_gateway.main.id]
  }
}

# TGW routes using default route table
resource "aws_ec2_transit_gateway_route" "backend_route" {
  destination_cidr_block         = var.backend_vpc_cidr
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.backend.id
  transit_gateway_route_table_id = data.aws_ec2_transit_gateway_route_table.default.id
}

resource "aws_ec2_transit_gateway_route" "frontend_route" {
  destination_cidr_block         = var.frontend_vpc_cidr
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.frontend.id
  transit_gateway_route_table_id = data.aws_ec2_transit_gateway_route_table.default.id
}

# Update route tables for TGW communication
resource "aws_route" "frontend_to_backend" {
  route_table_id         = aws_route_table.frontend_public.id
  destination_cidr_block = var.backend_vpc_cidr
  transit_gateway_id     = aws_ec2_transit_gateway.main.id
}

resource "aws_route_table" "backend_private" {
  vpc_id = aws_vpc.backend.id

  route {
    cidr_block         = var.frontend_vpc_cidr
    transit_gateway_id = aws_ec2_transit_gateway.main.id
  }

  tags = {
    Name = "${var.project_name}-backend-private-rt"
  }
}

resource "aws_route_table_association" "backend_private" {
  count          = length(aws_subnet.backend_private)
  subnet_id      = aws_subnet.backend_private[count.index].id
  route_table_id = aws_route_table.backend_private.id
}