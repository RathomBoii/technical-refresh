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
      Action    = "sts:AssumeRole" # every role assumer must have this permission in order to able to receive the temporary credentials from STS
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

# Make bastion to be able to sync Terraform state to and from s3 bucket
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
  instance_type               = var.instance_type
  subnet_id                   = var.private_subnet_id
  vpc_security_group_ids      = [aws_security_group.bastion.id]
  associate_public_ip_address = false
  iam_instance_profile        = aws_iam_instance_profile.bastion.name

  # IMDSv2 required — prevents SSRF attacks from stealing instance credentials
  # IMDSv2 (Instance Metadata Service Version 2)
  # ทำไมถึงปลอดภัยกว่ารุ่นเก่า (IMDSv1): รุ่นเก่ามีช่องโหว่ที่แฮกเกอร์อาจหลอกให้เซิร์ฟเวอร์ส่งข้อมูลสำคัญออกมาจากภายนอกได้ (SSRF - Server-Side Request Forgery) 
  # IMDSv2 จึงอัปเกรดการทำงานโดยบังคับให้มีการขอ Session Token ทุกครั้งที่ต้องการเรียกดูข้อมูล ป้องกันการสุ่มดึงข้อมูลโดยไม่ได้รับอนุญาต
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  # Encrypted root volume — protects data at rest if volume snapshot is exposed
  # 30GB minimum — Amazon Linux 2023 AMI snapshot requires >= 30GB
  root_block_device {
    volume_type           = "gp3"
    volume_size           = 30
    encrypted             = true
    delete_on_termination = true
  }

  user_data = <<-EOF
    #!/bin/bash
    set -euo pipefail
    exec > >(tee /var/log/user-data.log | logger -t user-data) 2>&1

    # ── kubectl (pin to match EKS cluster version) ──────────────────────────────
    # Version is rendered by Terraform at plan time — avoids $$ escaping issues
    curl -LO "https://dl.k8s.io/release/v${var.kubernetes_version}.0/bin/linux/amd64/kubectl"
    install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
    rm -f kubectl
    echo "kubectl $(kubectl version --client) installed"

    # ── Helm ────────────────────────────────────────────────────────────────────
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    echo "Helm $(helm version --short) installed"

    # ── GitHub CLI (AL2023 uses dnf) ────────────────────────────────────────────
    dnf install -y 'dnf-command(config-manager)'
    dnf config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo
    dnf install -y gh
    echo "GitHub CLI $(gh --version | head -1) installed"

    # ── Terraform (AL2023 + HashiCorp repo) ─────────────────────────────────────
    dnf install -y dnf-plugins-core
    dnf config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo
    dnf install -y terraform
    echo "Terraform $(terraform version | head -1) installed"

    # ── ArgoCD CLI ──────────────────────────────────────────────────────────────
    curl -Lo argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
    install -o root -g root -m 0755 argocd /usr/local/bin/argocd
    rm -f argocd
    echo "ArgoCD CLI $(argocd version --client --short) installed"

    # ── Wait for EKS cluster to be ACTIVE ───────────────────────────────────────
    echo "Waiting for EKS cluster ${var.cluster_name} to be ACTIVE..."
    until aws eks describe-cluster \
        --name ${var.cluster_name} \
        --region ${var.region} \
        --query 'cluster.status' \
        --output text 2>/dev/null | grep -q "^ACTIVE$"; do
      echo "EKS not ready yet, retrying in 30s..."
      sleep 30
    done
    echo "EKS cluster is ACTIVE"

    # ── kubeconfig for both root and ec2-user ───────────────────────────────────
    aws eks update-kubeconfig --region ${var.region} --name ${var.cluster_name}

    # Also configure for ec2-user (the SSH login user)
    mkdir -p /home/ec2-user/.kube
    aws eks update-kubeconfig \
      --region ${var.region} \
      --name ${var.cluster_name} \
      --kubeconfig /home/ec2-user/.kube/config
    chown -R ec2-user:ec2-user /home/ec2-user/.kube
    echo "kubeconfig configured for root and ec2-user"
  EOF

  tags = {
    Name      = "${var.env}-bastion"
    Env       = var.env
    ManagedBy = "terraform"
  }
}
