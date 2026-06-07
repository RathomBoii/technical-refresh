# ── helloworld IRSA role ───────────────────────────────────────────────────────
# Allows the helloworld pod's Kubernetes ServiceAccount to call AWS Secrets Manager.
# The pod's ServiceAccount must be annotated with this role ARN.

# The role's trust policy allows sts:AssumeRoleWithWebIdentity from the OIDC provider ARN for the EKS cluster,
# but only if the token's "sub" claim matches the expected ServiceAccount and namespace, and the "aud" claim is sts.amazonaws.com.
resource "aws_iam_role" "helloworld" {
  name = "${var.env}-helloworld"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = var.oidc_provider_arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          # Must match exactly: namespace and ServiceAccount name in the helm chart
          # helloworld is a application's EKS namespace, revise it as your actual application namespace.
          #* Pattern is: system:serviceaccount:<namespace>:<serviceaccount-name>
          "${var.oidc_provider}:sub" = "system:serviceaccount:${var.helloworld_namespace}:helloworld"
          "${var.oidc_provider}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })

  tags = {
    Name = "${var.env}-helloworld"
    Env  = var.env
  }
}


# The policy of line 7 role allows read-only access to Secrets Manager secrets under /<env>/helloworld/*.
resource "aws_iam_role_policy" "helloworld_secrets" {
  name = "${var.env}-helloworld-secrets"
  role = aws_iam_role.helloworld.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret"
      ]
      # Scoped to only secrets under /<env>/helloworld/
      # Wildcard suffix (-??????) matches the 6-char random suffix AWS appends to secret ARNs
      Resource = "arn:aws:secretsmanager:${var.region}:*:secret:/${var.env}/helloworld/*"
    }]
  })
}

# ── External Secrets Operator IRSA role ─────────────────────────────────────
# Allows the ESO ServiceAccount (eks-secret-store-irsa in the external-secrets
# namespace) to call Secrets Manager on behalf of ExternalSecret resources.
# The ServiceAccount name and namespace must match what the secret-store Helm
# chart deploys (values.serviceAccount.name and ArgoCD destination namespace).
resource "aws_iam_role" "eso" {
  name = "${var.env}-eks-secret-store-irsa"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = var.oidc_provider_arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${var.oidc_provider}:sub" = "system:serviceaccount:${var.eso_namespace}:${var.eso_service_account_name}"
          "${var.oidc_provider}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })

  tags = {
    Name = "${var.env}-eks-secret-store-irsa"
    Env  = var.env
  }
}

# Scoped to all secrets under <env>/* — covers current and future app secrets
resource "aws_iam_role_policy" "eso_secrets" {
  name = "${var.env}-eso-secrets-manager"
  role = aws_iam_role.eso.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret",
        "secretsmanager:ListSecretVersionIds"
      ]
      Resource = "arn:aws:secretsmanager:${var.region}:*:secret:${var.env}/*"
    }]
  })
}

# ── AWS Load Balancer Controller IRSA role ────────────────────────────────────
# Allows the aws-load-balancer-controller ServiceAccount in kube-system to
# create/manage NLBs and ALBs in response to LoadBalancer services and Ingresses.
resource "aws_iam_role" "lbc" {
  name = "${var.env}-aws-load-balancer-controller"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = var.oidc_provider_arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${var.oidc_provider}:sub" = "system:serviceaccount:kube-system:aws-load-balancer-controller"
          "${var.oidc_provider}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })

  tags = {
    Name = "${var.env}-aws-load-balancer-controller"
    Env  = var.env
  }
}

# AWS-managed policy with all permissions LBC needs (EC2, ELB, IAM, WAF, etc.)
resource "aws_iam_role_policy_attachment" "lbc" {
  role       = aws_iam_role.lbc.name
  policy_arn = "arn:aws:iam::aws:policy/ElasticLoadBalancingFullAccess"
}

# LBC also needs EC2 permissions to describe VPCs, subnets, security groups, etc.
resource "aws_iam_role_policy" "lbc_ec2" {
  name = "${var.env}-lbc-ec2"
  role = aws_iam_role.lbc.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeAccountAttributes",
          "ec2:DescribeAddresses",
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeInternetGateways",
          "ec2:DescribeVpcs",
          "ec2:DescribeVpcPeeringConnections",
          "ec2:DescribeSubnets",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeInstances",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DescribeTags",
          "ec2:GetCoipPoolUsage",
          "ec2:DescribeCoipPools",
          "ec2:CreateSecurityGroup",
          "ec2:CreateTags",
          "ec2:DeleteTags",
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:RevokeSecurityGroupIngress",
          "ec2:DeleteSecurityGroup"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "iam:CreateServiceLinkedRole",
          "iam:GetServerCertificate",
          "iam:ListServerCertificates"
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["cognito-idp:DescribeUserPoolClient"]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["waf-regional:*", "wafv2:*", "shield:*"]
        Resource = "*"
      }
    ]
  })
}

# ── GitHub Actions OIDC provider ──────────────────────────────────────────────
# AWS-account-level resource — only one should exist per account.
# Set create_github_oidc_provider = true on the FIRST env you apply (e.g. dev),
# and false for prod to avoid a "duplicate provider" error.
resource "aws_iam_openid_connect_provider" "github_actions" {
  count = var.create_github_oidc_provider ? 1 : 0

  url = "https://token.actions.githubusercontent.com"

  # sts.amazonaws.com is the audience GitHub Actions sends in its OIDC token
  client_id_list = ["sts.amazonaws.com"]

  # GitHub's OIDC thumbprint — AWS uses this to verify the token signature.
  # Check current value at:
  # https://docs.github.com/en/actions/security-for-github-actions/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services
  # openssl s_client \
  # -servername token.actions.githubusercontent.com \
  # -showcerts \
  # -connect token.actions.githubusercontent.com:443 \
  # </dev/null 2>/dev/null \
  # | openssl x509 -fingerprint -sha1 -noout \
  # | sed 's/sha1 Fingerprint=//I; s/://g' \
  # | tr '[:upper:]' '[:lower:]'
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]

  tags = {
    Name      = "github-actions-oidc"
    ManagedBy = "terraform"
  }
}

# ── GitHub Actions IAM role (ECR push) ───────────────────────────────────────
# Assumed by the CI/CD pipeline via OIDC — no static AWS credentials stored.
# Trust is scoped to tag pushes from the specific GitHub repo only.
resource "aws_iam_role" "github_actions" {
  name = "${var.env}-github-actions-ecr-push"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/token.actions.githubusercontent.com"
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          # Audience must match client_id_list above
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
        StringLike = {
          # Restrict to tag pushes from this specific repo only
          # Covers v* tags and release/** tags — matches the CI pipeline triggers
          "token.actions.githubusercontent.com:sub" = [
            "repo:${var.github_org}/${var.github_repo}:ref:refs/tags/v*",
            "repo:${var.github_org}/${var.github_repo}:ref:refs/tags/release/*"
          ]
        }
      }
    }]
  })

  tags = {
    Name = "${var.env}-github-actions-ecr-push"
    Env  = var.env
  }
}

# ECR push permissions — scoped to the env-specific repository only
resource "aws_iam_role_policy" "github_actions_ecr" {
  name = "${var.env}-github-actions-ecr"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # GetAuthorizationToken is account-scoped — cannot be restricted to one repo
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage"
        ]
        # Scoped to the env-specific ECR repo only (e.g. dev-helloworld)
        Resource = "arn:aws:ecr:${var.region}:${data.aws_caller_identity.current.account_id}:repository/${var.env}-${var.ecr_repo_name}"
      }
    ]
  })
}

# Resolves the current AWS account ID at plan time — used in trust policy ARN
data "aws_caller_identity" "current" {}