# AWS Secrets Manager Mounting on EKS — Complete Guide

This document explains how the helloworld application reads secrets from AWS Secrets Manager
inside a Kubernetes pod, using GitOps (ArgoCD) to manage every resource.

---

## Big Picture

**CSI** = Container Storage Interface. It is a standardized API in Kubernetes that allows storage vendors to write plugins and expose arbitrary block and file storage systems to containerized workloads without changing the core Kubernetes codebase

**A DaemonSet** is a Kubernetes resource that guarantees one pod runs on every node in the cluster — automatically. **The CSI driver must be physically present on the same node — it can't mount a volume on Node 2 from Node**

```
  Pod (prod-app/helloworld) starts
  └── requests CSI volume mount (secretProviderClass: helloworld-secrets)
          │
          │ (1) Kubernetes notifies the CSI driver on this node
          ▼
  ┌─────────────────────────────────────────────────────────────────┐
  │  Secrets Store CSI Driver  (DaemonSet — made by Kubernetes SIGs)│
  │  - Provider-agnostic                                            │
  │  - Reads SecretProviderClass to know: provider=aws,             │
  │    objectName=/prod/helloworld/api-key                          │
  └──────────────────────────┬──────────────────────────────────────┘
                             │ (2) gRPC call: "fetch this secret using this pod's token"
                             ▼
  ┌─────────────────────────────────────────────────────────────────┐
  │  AWS Provider Plugin  (DaemonSet — made by AWS)                 │
  │  - AWS-specific                                                 │
  │  1. Takes pod's OIDC token (audience: sts.amazonaws.com)        │
  │  2. Calls AWS STS → AssumeRoleWithWebIdentity                   │
  │     → gets temporary credentials for role: prod-helloworld      │
  │  3. Calls Secrets Manager → GetSecretValue                      │
  │     → returns "my-secret-value"                                 │
  └──────────────────────────┬──────────────────────────────────────┘
                             │ (3) returns secret value to CSI driver
                             ▼
  ┌─────────────────────────────────────────────────────────────────┐
  │  Secrets Store CSI Driver  (continues)                          │
  │  1. Writes file:  /mnt/secrets/api-key = "my-secret-value"     │
  │  2. Syncs K8s Secret: helloworld-secrets { API_KEY: "..." }     │
  └──────────────────────────┬──────────────────────────────────────┘
                             │ (4) volume mount completes, pod starts
                             ▼
  ┌─────────────────────────────────────────────────────────────────┐
  │  Pod (prod-app/helloworld)                                      │
  │  /mnt/secrets/api-key = "my-secret-value"  ← file mount        │
  │  env: API_KEY = "my-secret-value"          ← secretKeyRef      │
  └─────────────────────────────────────────────────────────────────┘
          │
          ▼
  AWS Secrets Manager
  /prod/helloworld/api-key = "my-secret-value"   (the source of truth)
```

The pod **never calls AWS directly**. The AWS Provider Plugin handles all AWS API calls,
and the Secrets Store CSI Driver coordinates the mount and K8s Secret sync.

---

## How IRSA Works (Identity)

IRSA = IAM Roles for Service Accounts. It lets a Kubernetes ServiceAccount assume an AWS IAM role
**without any long-lived credentials** (no access key / secret key stored in the cluster).

### Step-by-step token flow

```
1. Pod starts
   └── Kubernetes mounts a short-lived OIDC token into the pod
         (projected volume, auto-rotated, audience: sts.amazonaws.com)

2. CSI driver reads the pod's token

3. CSI driver calls AWS STS:
   AssumeRoleWithWebIdentity(
     RoleArn      = "arn:aws:iam::687069305167:role/prod-helloworld",
     WebIdentityToken = <pod's OIDC token>
   )

4. STS validates the token against the EKS cluster's OIDC provider
   Checks two conditions:
     sub = "system:serviceaccount:prod-app:helloworld"  ← namespace:name must match exactly
     aud = "sts.amazonaws.com"

5. STS returns temporary credentials (AccessKeyId, SecretAccessKey, SessionToken)

6. CSI driver uses those credentials to call:
   secretsmanager:GetSecretValue("/prod/helloworld/api-key")

7. Secret value is mounted as a file in the pod + synced into a K8s Secret
```

### IAM Role: `prod-helloworld`

Defined in `eks-private-cluster/terraform/modules/iam/main.tf`.

**Trust policy** — who can assume this role:
```json
{
  "Effect": "Allow",
  "Principal": { "Federated": "<EKS OIDC provider ARN>" },
  "Action": "sts:AssumeRoleWithWebIdentity",
  "Condition": {
    "StringEquals": {
      "<oidc>:sub": "system:serviceaccount:prod-app:helloworld",
      "<oidc>:aud": "sts.amazonaws.com"
    }
  }
}
```

> The `sub` condition binds the role to **one specific ServiceAccount in one specific namespace**.
> If the namespace or ServiceAccount name doesn't match, STS rejects the request — this is why
> the pod was getting "Failed to fetch secret" before `helloworld_namespace = "prod-app"` was set
> in `prod.tfvars`.

**Permission policy** — what this role can do:
```json
{
  "Effect": "Allow",
  "Action": ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"],
  "Resource": "arn:aws:secretsmanager:ap-southeast-7:*:secret:/prod/helloworld/*"
}
```

Scoped to only secrets under `/prod/helloworld/` — the role cannot access any other secrets.

---

## Components and Their Files

### 1. ArgoCD Applications (what to deploy)

| ArgoCD App | File | Purpose |
|---|---|---|
| `csi-secrets-store` | `k8s/manifests/app-csi-secrets-store/argocd-app-csi-secrets-store.yaml` | Installs Secrets Store CSI Driver via Helm |
| `csi-secrets-store-aws-provider` | `k8s/manifests/app-csi-secrets-store/argocd-app-csi-aws-provider.yaml` | Installs AWS provider DaemonSet |
| `helloworld` | `k8s/manifests/app-helloworld/argocd-app-helloworld.yaml` | Deploys the helloworld app |

### 2. CSI Driver (cluster infrastructure)

#### What is it?

CSI stands for **Container Storage Interface** — a standard API that Kubernetes uses to talk to
external storage systems (S3, EBS, NFS, secret stores, etc.).

The **Secrets Store CSI Driver** is a special CSI implementation that treats secret managers
(AWS Secrets Manager, HashiCorp Vault, Azure Key Vault, etc.) as a "storage backend".
Instead of mounting a disk, it mounts secrets as files inside the pod.

It runs as a **DaemonSet** — one pod on every node — so it is always present on whichever
node your application pod is scheduled on.

```
┌─────────────────── Kubernetes Node ──────────────────────┐
│                                                           │
│  ┌─────────────────────────────┐                         │
│  │  secrets-store-csi-driver   │  ← DaemonSet pod        │
│  │  (one per node)             │                         │
│  └──────────────┬──────────────┘                         │
│                 │ mounts secrets via CSI volume           │
│                 ▼                                         │
│  ┌─────────────────────────────┐                         │
│  │  helloworld pod             │                         │
│  │  /mnt/secrets/api-key ← file│                         │
│  └─────────────────────────────┘                         │
└───────────────────────────────────────────────────────────┘
```

#### What CRDs does it install?

When you install the CSI driver Helm chart, it registers two Custom Resource Definitions (CRDs)
into Kubernetes:

| CRD | Purpose |
|---|---|
| `SecretProviderClass` | Defines **which secrets to fetch** and from which provider (aws, vault, azure). You create one per app. |
| `SecretProviderClassPodStatus` | Kubernetes auto-creates one per pod — tracks which pod is using which SecretProviderClass and the rotation status. You never create these manually. |

A **CRD (Custom Resource Definition)** is a way to extend Kubernetes with your own resource types.
After the CRD is installed, you can use `kubectl get secretproviderclass` the same way you use
`kubectl get deployment` — Kubernetes now understands that resource type.

Before the CRD exists, any manifest with `kind: SecretProviderClass` will be rejected by the
Kubernetes API server with: `no matches for kind "SecretProviderClass"`.
This is exactly the error ArgoCD showed when trying to sync helloworld before the CSI driver was installed.

#### Two critical Helm settings

- `syncSecret.enabled=true` — by default the CSI driver only mounts the secret as a file.
  This flag also syncs it into a native K8s `Secret` object, which is needed to inject
  it as an env var via `secretKeyRef`.
- `tokenRequests[0].audience=sts.amazonaws.com` — enables IRSA. Without this, the CSI driver
  does not request the pod's OIDC token, so it cannot call `sts:AssumeRoleWithWebIdentity`.

Without `tokenRequests`, the pod fails with:
```
CSI token error: serviceAccount.tokens not provided — ensure tokenRequests is configured in CSIDriver
```

---

### 3. AWS Provider (cluster infrastructure)

#### What is it?

The CSI driver itself is **provider-agnostic** — it does not know how to talk to AWS, Vault, or Azure.
It delegates the actual secret fetching to a **provider plugin** that runs as a separate DaemonSet.

The **AWS Provider** (`secrets-store-csi-driver-provider-aws`) is the plugin that:
1. Receives the fetch request from the CSI driver (including the pod's IRSA token)
2. Calls `sts:AssumeRoleWithWebIdentity` using that token to get temporary AWS credentials
3. Calls `secretsmanager:GetSecretValue` with those credentials
4. Returns the secret value back to the CSI driver

```
CSI Driver (provider-agnostic)  ──calls──▶  AWS Provider plugin  ──calls──▶  AWS STS + Secrets Manager
```

The two components are deliberately separate so the CSI driver codebase stays cloud-neutral.
You could swap the AWS provider for a Vault provider without changing any application manifests.

Manifest stored at: `k8s/charts/csi-secrets-store-aws-provider/aws-provider-installer.yaml`
(downloaded from the official AWS repo and committed to Git for ArgoCD to manage).

### 4. Terraform: IAM Role (one-time per environment)

```bash
cd eks-private-cluster/terraform
aws-vault exec jessada-ntt -- terraform apply \
  -var-file=envs/prod.tfvars \
  -target=module.iam \
  -auto-approve
```

This creates the `prod-helloworld` IAM role with the correct trust policy and Secrets Manager permission.
Must be re-applied if the namespace or ServiceAccount name changes.

### 5. Helloworld Helm Chart Resources

All in `k8s/charts/helloworld/templates/`:

#### `serviceaccount.yaml` — links the pod identity to the IAM role
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: helloworld          # must match the "sub" in the IAM trust policy
  namespace: prod-app       # must match the "sub" in the IAM trust policy
  annotations:
    eks.amazonaws.com/role-arn: "arn:aws:iam::687069305167:role/prod-helloworld"
```

#### `secret-provider-class.yaml` — tells the CSI driver which secret to fetch
```yaml
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: helloworld-secrets
  namespace: prod-app
spec:
  provider: aws
  parameters:
    objects: |
      - objectName: "/prod/helloworld/api-key"   # path in AWS Secrets Manager
        objectType: secretsmanager
        objectAlias: "api-key"                   # filename in the volume mount
  secretObjects:
    - secretName: helloworld-secrets             # K8s Secret that gets created
      type: Opaque
      data:
        - objectName: "api-key"
          key: API_KEY                           # key inside the K8s Secret
```

#### `deployment.yaml` — mounts the secret and injects it as an env var
```yaml
spec:
  serviceAccountName: helloworld   # triggers IRSA token injection

  containers:
    - env:
        - name: API_KEY             # env var the application reads
          valueFrom:
            secretKeyRef:
              name: helloworld-secrets   # K8s Secret created by SecretProviderClass
              key: API_KEY

      volumeMounts:
        - name: secrets-store
          mountPath: /mnt/secrets   # file also available at /mnt/secrets/api-key
          readOnly: true

  volumes:
    - name: secrets-store
      csi:
        driver: secrets-store.csi.k8s.io
        volumeAttributes:
          secretProviderClass: helloworld-secrets
```

#### `values-dev.yaml` — enables secrets for the dev environment
```yaml
secrets:
  enabled: true
  providerClass: "helloworld-secrets"
  mountPath: "/mnt/secrets"
  envVars:
    - name: API_KEY
      secretName: helloworld-secrets
      key: API_KEY
```

---

## Deployment Order

Dependencies must be ready before helloworld can start:

```
1. terraform apply -target=module.iam     ← creates prod-helloworld IAM role
        ↓
2. ArgoCD: csi-secrets-store              ← installs CSI driver + CRDs
        ↓
3. ArgoCD: csi-secrets-store-aws-provider ← installs AWS provider DaemonSet
        ↓
4. ArgoCD: helloworld                     ← deploys app (SecretProviderClass + Deployment)
```

If helloworld syncs before the CSI driver is ready, ArgoCD will retry automatically
(up to the retry limit) until the `SecretProviderClass` CRD exists.

---

## Applying Everything

```bash
# On bastion, after pushing all changes to Git

# 1. Apply the ArgoCD applications (first time only — after that ArgoCD auto-syncs from Git)
kubectl apply -f eks-private-cluster/k8s/manifests/app-csi-secrets-store/
kubectl apply -f eks-private-cluster/k8s/manifests/app-helloworld/

# 2. Watch sync status
argocd app list

# 3. If helloworld pod fails to start, check events
kubectl describe pod -n prod-app -l app=helloworld
```

---

## Validation

```bash
# 1. Check the secret file is mounted inside the pod
kubectl exec -n prod-app $(kubectl get pod -n prod-app -l app=helloworld -o jsonpath='{.items[0].metadata.name}') \
  -- cat /mnt/secrets/api-key

# 2. Check the env var is injected
kubectl exec -n prod-app $(kubectl get pod -n prod-app -l app=helloworld -o jsonpath='{.items[0].metadata.name}') \
  -- env | grep API_KEY

# 3. Check the K8s Secret was synced
kubectl get secret helloworld-secrets -n prod-app
kubectl get secret helloworld-secrets -n prod-app -o jsonpath='{.data.API_KEY}' | base64 -d

# 4. Hit the app endpoints
curl https://helloworldapp.wolffialampang.com/secret-check
# {"api_key_loaded": true}

curl "https://helloworldapp.wolffialampang.com/secret-value?key=API_KEY"
# {"key": "API_KEY", "value": "changeme-replace-before-use"}
```

---

## Common Errors and Fixes

| Error | Cause | Fix |
|---|---|---|
| `SecretProviderClass CRD not found` | CSI driver not installed yet | Apply `argocd-app-csi-secrets-store.yaml` first |
| `CSI token error: serviceAccount.tokens not provided` | `tokenRequests` not set on CSIDriver | Helm upgrade with `tokenRequests[0].audience=sts.amazonaws.com` |
| `Failed to fetch secret from all regions` | IRSA trust policy namespace mismatch | Ensure `helloworld_namespace = "prod-app"` in `prod.tfvars` and re-apply `module.iam` |
| `API_KEY not found in environment variables` | `syncSecret.enabled=false` | Reinstall CSI driver with `syncSecret.enabled=true` |
| Pod stuck in `Init` or `ContainerCreating` | Secret mount failed | `kubectl describe pod` → check Events section for CSI errors |

---

## Plain Text Secret vs Key/Value Secret

The secret `/prod/helloworld/api-key` is stored as **Plaintext** in Secrets Manager.
The entire value is the secret — no JSON keys needed.

If the secret were stored as **Key/Value** JSON (e.g. `{"API_KEY": "abc123"}`), you would need
`jmesPath` in the `SecretProviderClass` to extract individual fields. See the commented example
in `k8s/charts/helloworld/templates/secret-provider-class.yaml`.
