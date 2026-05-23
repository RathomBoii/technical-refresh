module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name            = "${var.cluster_name}-vpc"
  cidr            = var.vpc_cidr
  azs             = ["${var.region}a", "${var.region}b"]
  private_subnets = var.private_subnets
  public_subnets  = var.public_subnets

  enable_nat_gateway   = true
  single_nat_gateway   = var.is_single_nat_gateway # dev: cost-saving; set false in prod for HA
  enable_dns_hostnames = true
  enable_dns_support   = true

  # Required tags so EKS can discover subnets automatically
  private_subnet_tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"           = "1"
  }

  public_subnet_tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                    = "1"
  }

  tags = {
    Env       = var.env
    ManagedBy = "terraform"
  }
}

# ── VPC Endpoints for ECR (allows private nodes to pull images without NAT) ──

# Security group for interface endpoints — allow HTTPS from within the VPC
resource "aws_security_group" "vpc_endpoints" {
  name   = "${var.cluster_name}-vpc-endpoints"
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  tags = {
    Env       = var.env
    ManagedBy = "terraform"
  }
}

# S3 Gateway endpoint — ECR stores image layers in S3 (free, no hourly charge)
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = module.vpc.vpc_id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = module.vpc.private_route_table_ids

  tags = {
    Name      = "${var.cluster_name}-s3-endpoint"
    Env       = var.env
    ManagedBy = "terraform"
  }
}

# ECR API Interface endpoint — for authentication and manifest requests
resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.${var.region}.ecr.api"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.vpc.private_subnets
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = {
    Name      = "${var.cluster_name}-ecr-api-endpoint"
    Env       = var.env
    ManagedBy = "terraform"
  }
}

# ECR Docker Interface endpoint — for image layer pulls
resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.${var.region}.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.vpc.private_subnets
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = {
    Name      = "${var.cluster_name}-ecr-dkr-endpoint"
    Env       = var.env
    ManagedBy = "terraform"
  }
}
