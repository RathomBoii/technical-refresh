variable "env" {
  description = "Environment name (dev or prod)"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "oidc_provider_arn" {
  description = "OIDC provider ARN from the EKS cluster — used for IRSA trust policy"
  type        = string
}

variable "oidc_provider" {
  description = "OIDC provider URL (without https://) — used in IAM condition keys"
  type        = string
}

variable "app_namespace" {
  description = "Kubernetes namespace where app is deployed (must match helm chart destination)"
  type        = string
  default     = "dev-app"
}

variable "app_api_key_secret_name" {
  description = "Secrets Manager secret name from the secrets module — passed through to output for convenience"
  type        = string
}

variable "eso_namespace" {
  description = "Kubernetes namespace where External Secrets Operator is deployed (must match ArgoCD destination namespace)"
  type        = string
  default     = "external-secrets"
}

variable "eso_service_account_name" {
  description = "ServiceAccount name used by ESO — must match secret-store chart values.serviceAccount.name"
  type        = string
  default     = "eks-secret-store-irsa"
}

variable "github_org" {
  description = "GitHub organisation or user name that owns the repo (e.g. RathomBoii)"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name (e.g. technical-refresh)"
  type        = string
}

variable "ecr_repo_name" {
  description = "ECR repository base name — used to scope the push policy to <env>-<repo_name>"
  type        = string
  default     = "app"
}

variable "create_github_oidc_provider" {
  description = "Set true only on the first env (dev). The GitHub OIDC provider is account-scoped — creating it twice causes an error."
  type        = bool
  default     = false
}


