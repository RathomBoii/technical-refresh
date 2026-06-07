# # ── Secrets Store CSI Driver ───────────────────────────────────────────────────
# # Two-chart setup:
# #   1. secrets-store-csi-driver   — Kubernetes-native CSI driver (from sig-storage)
# #   2. secrets-store-csi-driver-provider-aws — AWS provider plugin for the driver
# #
# # After install, pods can mount secrets from AWS Secrets Manager / SSM Parameter
# # Store as files via a SecretProviderClass CRD. Each pod needs its own IRSA role
# # with secretsmanager:GetSecretValue permission (configured per app, not here).

# resource "helm_release" "secrets_store_csi_driver" {
#   name             = "secrets-store-csi-driver"
#   repository       = "https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts"
#   chart            = "secrets-store-csi-driver"
#   version          = "1.4.7"
#   namespace        = "kube-system"
#   create_namespace = false # kube-system already exists

#   # syncSecret.enabled — mirrors the CSI secret into a native Kubernetes Secret
#   # so apps that read from env vars (not file mounts) work too
#   set {
#     name  = "syncSecret.enabled"
#     value = "true"
#   }

#   # Rotate secrets automatically when they change in Secrets Manager
#   set {
#     name  = "enableSecretRotation"
#     value = "true"
#   }

#   depends_on = [module.eks]
# }

# resource "helm_release" "secrets_store_csi_driver_provider_aws" {
#   name             = "secrets-store-csi-driver-provider-aws"
#   repository       = "https://aws.github.io/secrets-store-csi-driver-provider-aws"
#   chart            = "secrets-store-csi-driver-provider-aws"
#   version          = "0.3.10"
#   namespace        = "kube-system"
#   create_namespace = false

#   depends_on = [helm_release.secrets_store_csi_driver]
# }
