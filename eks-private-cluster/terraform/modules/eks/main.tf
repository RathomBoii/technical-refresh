# terraform-aws-modules/eks module creates OICD provider automatically under the hood.
# What the OIDC provider does:
# It creates a trust bridge between your EKS cluster and 
# AWS IAM. When a pod presents its Kubernetes ServiceAccount token to STS, 
# AWS uses the OIDC provider to verify: "Is this token genuinely signed by this EKS cluster?" 
# — before allowing AssumeRoleWithWebIdentity.
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = var.kubernetes_version

  # Must be false — matches the existing cluster created before this config.
  # Changing to true forces cluster replacement (destroy + recreate).
  bootstrap_self_managed_addons = false

  vpc_id     = var.vpc_id
  subnet_ids = var.private_subnet_ids

  # Private cluster — API server not reachable from public internet
  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = false

  # Control plane logging — audit trail required for production security
  cluster_enabled_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  # KMS envelope encryption for Kubernetes secrets at rest
  create_kms_key = true
  cluster_encryption_config = {
    resources = ["secrets"]
  }
  kms_key_deletion_window_in_days = 7
  kms_key_enable_default_policy   = true

  # Allow bastion to reach EKS API on port 443
  cluster_security_group_additional_rules = {
    bastion_ingress = {
      description              = "Allow bastion to reach EKS API"
      protocol                 = "tcp"
      from_port                = 443
      to_port                  = 443
      type                     = "ingress"
      source_security_group_id = var.bastion_security_group_id
    }
  }

  eks_managed_node_groups = {
    default = {
      instance_types = [var.node_instance_type]
      min_size       = var.min_nodes
      max_size       = var.max_nodes
      desired_size   = var.desired_nodes
      subnet_ids     = var.private_subnet_ids

      # Encrypted GP3 root volume on every node
      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size           = 50
            volume_type           = "gp3"
            encrypted             = true
            delete_on_termination = true
          }
        }
      }
      # It protects clusters against Server-Side Request Forgery (SSRF)
      # IMDSv2 required — prevents SSRF-based credential theft from pods
      # hop_limit = 2 so containers inside the node can still reach IMDS
      metadata_options = {
        http_endpoint               = "enabled"
        http_tokens                 = "required"
        http_put_response_hop_limit = 2
      }

      # Rolling update: replace at most 33% of nodes at once (zero-downtime)
      update_config = {
        max_unavailable_percentage = 33
      }
    }
  }

  tags = {
    Env       = var.env
    ManagedBy = "terraform"
  }
}

# ── Critical EKS addons ───────────────────────────────────────────────────────
# AWS bootstraps the cluster
#   → kube-proxy, coredns installed AND registered with EKS Addon API
#   → AWS manages version compatibility with cluster version
#   → You can upgrade with one Terraform change or one CLI command
#   → AWS flags when addon version is out of date
resource "aws_eks_addon" "vpc_cni" {
  cluster_name                = module.eks.cluster_name
  addon_name                  = "vpc-cni"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = {
    Env       = var.env
    ManagedBy = "terraform"
  }
}

resource "aws_eks_addon" "coredns" {
  cluster_name                = module.eks.cluster_name
  addon_name                  = "coredns"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = {
    Env       = var.env
    ManagedBy = "terraform"
  }
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name                = module.eks.cluster_name
  addon_name                  = "kube-proxy"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = {
    Env       = var.env
    ManagedBy = "terraform"
  }
}

# EBS CSI driver IRSA — addon needs IAM permissions to create/attach EBS volumes.
# Without this role the addon starts DEGRADED and PVCs will never bind.
resource "aws_iam_role" "ebs_csi_driver" {
  name = "${var.cluster_name}-ebs-csi-driver"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = module.eks.oidc_provider_arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${module.eks.oidc_provider}:sub" = "system:serviceaccount:kube-system:ebs-csi-controller-sa"
          "${module.eks.oidc_provider}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })

  tags = {
    Env       = var.env
    ManagedBy = "terraform"
  }
}

resource "aws_iam_role_policy_attachment" "ebs_csi_driver" {
  role       = aws_iam_role.ebs_csi_driver.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

# EBS CSI driver — required for PersistentVolumes backed by EBS
resource "aws_eks_addon" "ebs_csi_driver" {
  cluster_name                = module.eks.cluster_name
  addon_name                  = "aws-ebs-csi-driver"
  service_account_role_arn    = aws_iam_role.ebs_csi_driver.arn
  resolve_conflicts_on_update = "OVERWRITE"

  tags = {
    Env       = var.env
    ManagedBy = "terraform"
  }
}

resource "aws_eks_addon" "pod_identity_agent" {
  cluster_name = module.eks.cluster_name
  addon_name   = "eks-pod-identity-agent"

  tags = {
    Env       = var.env
    ManagedBy = "terraform"
  }
}

resource "aws_eks_access_entry" "bastion" {
  cluster_name  = module.eks.cluster_name
  principal_arn = var.bastion_role_arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "bastion" {
  cluster_name  = module.eks.cluster_name
  principal_arn = var.bastion_role_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }
}

resource "aws_eks_access_entry" "admins" {
  for_each      = toset(var.admin_principal_arns)
  cluster_name  = module.eks.cluster_name
  principal_arn = each.value
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "admins" {
  for_each      = toset(var.admin_principal_arns)
  cluster_name  = module.eks.cluster_name
  principal_arn = each.value
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }
}
