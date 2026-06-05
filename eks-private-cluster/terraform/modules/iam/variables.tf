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

variable "helloworld_namespace" {
  description = "Kubernetes namespace where helloworld is deployed (must match helm chart destination)"
  type        = string
  default     = "dev-app"
}

variable "helloworld_api_key_secret_name" {
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


