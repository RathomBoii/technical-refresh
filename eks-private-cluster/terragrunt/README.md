# Terragrunt Deployment Guide

Terragrunt wraps the same Terraform modules used in the `terraform/` directory.
Each module is deployed independently — state is isolated per environment and module.

## Prerequisites

- Terragrunt >= 0.55 — `brew install terragrunt`
- Terraform >= 1.15 — `brew install terraform`
- AWS credentials with admin access

## Directory structure

```
terragrunt/
├── terragrunt.hcl          # Root: S3 backend + AWS provider (inherited by all)
├── _envcommon/             # Shared module configs (no env-specific values)
│   ├── vpc.hcl
│   ├── bastion.hcl
│   ├── ecr.hcl
│   ├── eks.hcl
│   └── helm.hcl
└── live/
    ├── dev/                # Dev environment
    │   ├── env.hcl         # All dev-specific values (cluster name, CIDRs, node size…)
    │   ├── vpc/
    │   ├── bastion/
    │   ├── ecr/
    │   ├── eks/
    │   └── helm/
    └── prod/               # Prod environment (same structure)
```

## Deploy — Dev

> Run all commands from inside `terragrunt/live/dev/`

```bash
cd terragrunt/live/dev
```

### Step 1 — VPC

```bash
terragrunt run-all init --terragrunt-include-dir vpc
terragrunt run-all apply --terragrunt-include-dir vpc
```

Or one module at a time:

```bash
cd vpc && terragrunt init && terragrunt apply
```

### Step 2 — Bastion (EC2 + EIC endpoint)

```bash
cd ../bastion && terragrunt init && terragrunt apply
```

### Step 3 — ECR

```bash
cd ../ecr && terragrunt init && terragrunt apply
```

### Step 4 — EKS (depends on VPC + Bastion)

```bash
cd ../eks && terragrunt init && terragrunt apply
```

### Step 5 — Helm (ArgoCD — depends on EKS + ECR)

```bash
cd ../helm && terragrunt init && terragrunt apply
```

### Deploy all at once (respects dependency order automatically)

```bash
cd terragrunt/live/dev
terragrunt run-all apply
```

---

## Deploy — Prod

Same commands from `terragrunt/live/prod/`.

```bash
cd terragrunt/live/prod
terragrunt run-all apply
```

---

## After infrastructure is up — deploy k8s resources from bastion

Connect to the bastion via EC2 Instance Connect:

```bash
aws ec2-instance-connect open-tunnel \
  --instance-id <bastion-instance-id> \
  --region ap-southeast-7
```

Then follow **[k8s/README.md](../k8s/README.md)** for Helm + kubectl steps (NGINX, cert-manager, ArgoCD, Prometheus, ingress rules).

---

## Useful commands

```bash
# Plan a single module without applying
cd live/dev/eks && terragrunt plan

# Destroy a single module (respects dependencies)
cd live/dev/eks && terragrunt destroy

# Destroy entire environment (reverse order)
cd live/dev && terragrunt run-all destroy

# See outputs of a module
cd live/dev/eks && terragrunt output

# Validate all modules
cd live/dev && terragrunt run-all validate
```

---

## How state is stored

Each module gets its own state file in S3:

```
s3://eks-app-jessada-demo/
  dev/vpc/terraform.tfstate
  dev/bastion/terraform.tfstate
  dev/ecr/terraform.tfstate
  dev/eks/terraform.tfstate
  dev/helm/terraform.tfstate
  prod/vpc/terraform.tfstate
  ...
```

State locking uses DynamoDB table `terraform-locks` (must exist before first apply).

---

## Dependency graph

```
vpc ──────────────┐
                  ▼
bastion ──────► eks ──────► helm
                              ▲
ecr ──────────────────────────┘
```
