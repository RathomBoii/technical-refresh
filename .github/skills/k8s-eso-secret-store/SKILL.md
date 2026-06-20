---
name: k8s-eso-secret-store
description: >
  Use AWS Secrets Manager (or any external provider) as the source for native
  Kubernetes Secrets via External Secrets Operator (ESO). Use when setting up
  ESO, choosing between SecretStore and ClusterSecretStore, writing ExternalSecret
  resources, wiring IRSA auth, fetching specific JSON keys, or debugging common
  ESO errors (Request ARN is invalid, version v1beta1 not found, ComparisonError,
  spec.data must be an array, secret not appearing in target namespace).
---

# Kubernetes ESO & SecretStore

How to use an external secret provider (AWS Secrets Manager) as the source of
truth for native Kubernetes Secrets, using the External Secrets Operator.

## Mental Model

The three resources have misleading names. Reframe them by their actual job:

| Resource | Real job | Analogy |
|---|---|---|
| **External Secrets Operator (ESO)** | A running controller pod that does all the work | The robot/worker |
| **SecretStore / ClusterSecretStore** | Connection + auth profile to the provider. Stores NO data. | DB connection string / address book |
| **ExternalSecret** | What to fetch + where to create the K8s Secret | The work order |
| **K8s Secret** | The actual delivered result | The package |

```
ExternalSecret (WHAT + WHERE) ──refs──▶ SecretStore (HOW to auth)
        │                                      │
        └──────── both are just YAML ──────────┘
                          │ read by
                          ▼
        External Secrets Operator (the running robot)
                          │ creates
                          ▼
                K8s Secret (real data, in chosen namespace)
                          │ mounted by
                          ▼
                       App Pod
```

Key point: **defining an ExternalSecret does not create the secret yourself** — it
is a work order ESO picks up. ESO uses the SecretStore to authenticate to AWS,
fetches the value, then creates the real K8s Secret in the namespace you declared.

## SecretStore vs ClusterSecretStore

The SecretStore does **not** store secrets. It only answers: "HOW do I connect and
authenticate to the provider?"

| | `SecretStore` | `ClusterSecretStore` |
|---|---|---|
| Scope | One namespace | Cluster-wide (no namespace) |
| Usable by | ExternalSecrets in the **same** namespace only | ExternalSecrets in **any** namespace |
| When to use | All secrets land in one namespace | Secrets land in multiple namespaces |

If your secrets must be created in several namespaces (e.g. `prod-app`, `traefik`,
`external-secrets`), use `ClusterSecretStore` so you define the AWS auth **once**.
With a plain `SecretStore` you would need one per namespace, each repeating the
same provider config.

Because `ClusterSecretStore` is cluster-scoped, its `serviceAccountRef` **must**
specify an explicit `namespace` (it has no namespace context to inherit).

## Minimal Working Setup (AWS + IRSA)

### 1. ClusterSecretStore (auth profile)

```yaml
apiVersion: external-secrets.io/v1   # NOT v1beta1 on ESO chart >= 2.5.0
kind: ClusterSecretStore
metadata:
  name: secret-store
spec:
  provider:
    aws:
      service: SecretsManager
      region: ap-southeast-7
      # ESO v1: the role ARN MUST be set explicitly here.
      # serviceAccountRef only provides the web-identity token.
      role: arn:aws:iam::<ACCOUNT_ID>:role/<irsa-role>
      auth:
        jwt:
          serviceAccountRef:
            name: eks-secret-store-irsa
            namespace: external-secrets   # required for ClusterSecretStore
```

### 2. ServiceAccount (IRSA)

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: eks-secret-store-irsa
  namespace: external-secrets   # must match the sub claim in the IAM trust policy
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::<ACCOUNT_ID>:role/<irsa-role>
```

The IAM role trust policy must allow:
`system:serviceaccount:<sa-namespace>:<sa-name>` via the cluster OIDC provider.

### 3. ExternalSecret (work order)

Fetch a whole JSON secret and unpack every key:

```yaml
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: app-secrets
  namespace: prod-app          # ESO creates the K8s Secret HERE
spec:
  refreshInterval: 1h
  secretStoreRef:
    kind: ClusterSecretStore
    name: secret-store
  target:
    name: app-secrets          # name of the resulting K8s Secret
    creationPolicy: Owner
  dataFrom:
    - extract:
        key: prod/app          # AWS SM secret name (value is JSON)
```

## Fetching a Specific Key (not the whole JSON)

Use `data[]` with `remoteRef.property`. Note `spec.data` MUST be an array:

```yaml
spec:
  data:
    - secretKey: users         # key name inside the resulting K8s Secret
      remoteRef:
        key: prod/dashboard-auth   # AWS SM secret name
        property: password         # pick ONLY this JSON field
```

`dataFrom.extract` = unpack all JSON keys. `data[].remoteRef.property` = pick one.

## Cross-Namespace Rules (critical)

- A K8s Secret is **namespace-scoped**. A pod/Middleware can only read secrets in
  **its own namespace**.
- Put the ExternalSecret's `metadata.namespace` = the consumer's namespace.
- The `ClusterSecretStore` is the only cluster-scoped piece; it can create secrets
  into any namespace, but the resulting Secret still obeys normal isolation.

Example: an app pod in `prod-app` needs `app-secrets` created in `prod-app`, not in
`external-secrets`. A Traefik Middleware in `traefik` needs its auth secret in
`traefik`.

## Verification

```bash
kubectl get clustersecretstore secret-store           # READY: True
kubectl get externalsecret -A                          # SecretSynced
kubectl get secret app-secrets -n prod-app             # exists with data
kubectl describe externalsecret app-secrets -n prod-app
kubectl logs -n external-secrets deploy/external-secrets --tail=30
```

## Common Errors

| Symptom | Root cause | Fix |
|---|---|---|
| `STS AssumeRoleWithWebIdentity ... Request ARN is invalid` and logs show `"credentials":{}` | ESO v1 does not read the role ARN from the SA annotation; it passes an empty ARN | Add explicit `provider.aws.role: <arn>` to the SecretStore |
| `could not find version "v1beta1" ... "v1" is installed` | ESO chart >= 2.5.0 dropped `v1beta1` | Change `apiVersion` to `external-secrets.io/v1` in all SecretStore/ExternalSecret manifests |
| `spec.data ... must be of type array: "object"` | `data` written as a map | `data` must be a YAML list (`- secretKey: ...`) |
| Secret never appears in consumer namespace | ExternalSecret `metadata.namespace` is wrong (e.g. defaulted to `default`) | Set it to the consumer's namespace |
| `Request ARN is invalid` but role exists | Trust policy `sub` mismatch — SA name/namespace differs | Ensure SA name + namespace match `system:serviceaccount:<ns>:<name>` in the IAM trust policy |
| ClusterSecretStore READY but auth fails | Missing `serviceAccountRef.namespace` | Add explicit namespace (required for cluster-scoped store) |

## ArgoCD / GitOps Notes

- Deploy the ESO Helm chart (which registers the CRDs) **before** any
  SecretStore/ExternalSecret manifests, or you get CRD-not-found sync errors.
- ESO's `ValidatingWebhookConfiguration` objects (`externalsecret-validate`,
  `secretstore-validate`) get a `caBundle` patched in by ESO's cert-controller
  after install. ArgoCD keeps seeing drift → sync loop. Fix with
  `ignoreDifferences` on the whole `/webhooks` path for both VWCs.
- For BasicAuth-style secrets consumed by Traefik, the resulting K8s Secret must
  have a `users` key in htpasswd format (`admin:$2y$05$...`). Store the htpasswd
  hash in AWS SM and map it to `secretKey: users`. Plain-text passwords will not
  work.
