data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

# ── IAM role for bastion (needed for aws eks update-kubeconfig) ────────────────

resource "aws_iam_role" "bastion" {
  name = "${var.env}-bastion-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })

  tags = {
    Name      = "${var.env}-bastion-role"
    Env       = var.env
    ManagedBy = "terraform"
  }
}

resource "aws_iam_role_policy" "bastion_eks" {
  name = "${var.env}-bastion-eks-policy"
  role = aws_iam_role.bastion.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["eks:DescribeCluster"]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:DescribeRepositories",
          "ecr:GetRepositoryPolicy",
          "ecr:ListImages",
          "ecr:DescribeImages",
          "ecr:BatchGetImage",
          "ecr:GetDownloadUrlForLayer",
          "ecr:GetAuthorizationToken",
          "ecr:CreateRepository",
          "ecr:PutImageTagMutability",
          "ecr:PutLifecyclePolicy",
          "ecr:SetRepositoryPolicy",
          "ecr:ListTagsForResource",
          "ecr:TagResource",
          "ecr:UntagResource"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy" "bastion_tfstate" {
  name = "${var.env}-bastion-tfstate-policy"
  role = aws_iam_role.bastion.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.tfstate_bucket}",
          "arn:aws:s3:::${var.tfstate_bucket}/*"
        ]
      },
      {
        Effect   = "Allow"
        Action   = ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:DeleteItem"]
        Resource = "arn:aws:dynamodb:${var.region}:*:table/terraform-locks"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "bastion" {
  name = "${var.env}-bastion-profile"
  role = aws_iam_role.bastion.name
}

# ── Security groups (separate resources to avoid circular dependency) ──────────

resource "aws_security_group" "eic_endpoint" {
  name        = "${var.env}-eic-endpoint-sg"
  description = "EC2 Instance Connect Endpoint security group"
  vpc_id      = var.vpc_id

  tags = {
    Name      = "${var.env}-eic-endpoint-sg"
    Env       = var.env
    ManagedBy = "terraform"
  }
}

resource "aws_security_group" "bastion" {
  name        = "${var.env}-bastion-sg"
  description = "Bastion host security group"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name      = "${var.env}-bastion-sg"
    Env       = var.env
    ManagedBy = "terraform"
  }
}

# Rules added after both SGs exist — breaks circular dependency
resource "aws_security_group_rule" "eic_egress_ssh" {
  type                     = "egress"
  description              = "SSH to bastion"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eic_endpoint.id
  source_security_group_id = aws_security_group.bastion.id
}

resource "aws_security_group_rule" "bastion_ingress_eic" {
  type                     = "ingress"
  description              = "SSH from EIC endpoint only"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  security_group_id        = aws_security_group.bastion.id
  source_security_group_id = aws_security_group.eic_endpoint.id
}

# ── EC2 Instance Connect Endpoint ─────────────────────────────────────────────

resource "aws_ec2_instance_connect_endpoint" "bastion" {
  subnet_id          = var.private_subnet_id
  security_group_ids = [aws_security_group.eic_endpoint.id]

  tags = {
    Name      = "${var.env}-eic-endpoint"
    Env       = var.env
    ManagedBy = "terraform"
  }
}

# ── Bastion EC2 instance ───────────────────────────────────────────────────────

resource "aws_instance" "bastion" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = "t3.micro"
  subnet_id                   = var.private_subnet_id
  vpc_security_group_ids      = [aws_security_group.bastion.id]
  associate_public_ip_address = false
  iam_instance_profile        = aws_iam_instance_profile.bastion.name

  user_data = <<-EOF
    #!/bin/bash
    # Install kubectl (pinned to match EKS cluster version)
    KUBECTL_VERSION="v1.35.0"
    curl -LO "https://dl.k8s.io/release/$${KUBECTL_VERSION}/bin/linux/amd64/kubectl"
    chmod +x kubectl && mv -f kubectl /usr/local/bin/kubectl

    # Install Helm
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

    # Wait for EKS cluster to be ACTIVE before configuring kubeconfig
    echo "Waiting for EKS cluster ${var.cluster_name} to be ACTIVE..."
    until aws eks describe-cluster \
        --name ${var.cluster_name} \
        --region ${var.region} \
        --query 'cluster.status' \
        --output text 2>/dev/null | grep -q "^ACTIVE$"; do
      echo "EKS not ready yet, retrying in 30s..."
      sleep 30
    done

    # Configure kubeconfig for EKS
    aws eks update-kubeconfig --region ${var.region} --name ${var.cluster_name}
    echo "kubeconfig updated successfully"

    # Install gh cli for Github auth (optional) for AML2 which doesn't have it by default
    type -p yum-config-manager >/dev/null || sudo yum install yum-utils
    sudo yum-config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo
    sudo yum install gh
    sudo yum update gh
    echo "GitHub CLI installed successfully"

    # Install Terraforms AWS CLI v2 plugin for EKS (optional, but useful for debugging and manual operations)
    sudo yum install -y yum-utils
    sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo
    sudo yum install -y terraform
    terraform -version
  EOF

  tags = {
    Name      = "${var.env}-bastion"
    Env       = var.env
    ManagedBy = "terraform"
  }
}
