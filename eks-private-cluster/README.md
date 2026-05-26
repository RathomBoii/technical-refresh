# Private EKS Cluster — Hello World + ArgoCD + NGINX

Private EKS cluster on AWS with:
- **Hello World** FastAPI app served via NGINX Ingress Controller
- **ArgoCD** for GitOps
- **NGINX Ingress Controller** as single entry point with domain-based routing
- **cert-manager + Let's Encrypt** for automatic TLS
- **Multi-environment** support (dev / prod)
- **Two deployment options**: plain Terraform or Terragrunt

---

## Architecture

```
Internet
    │
    ▼
NLB (internet-facing, public subnet)  :80 / :443
    │
    ▼
NGINX Ingress Controller (ingress-nginx namespace)
    │
    ├── app.wolffialampang.com     → helloworld-svc:8000  (dev-app namespace)
    └── argocd.wolffialampang.com  → argocd-server:8080   (argocd namespace)

NAT Gateway   → outbound internet for private nodes (ECR image pull, etc.)
Bastion Host  → kubectl/helm access via EC2 Instance Connect Endpoint
               (private subnet, no public IP, no SSH key)
```

---

## Repository Structure

```
eks-private-cluster/
├── app/
│   └── helloworld/              # FastAPI app + Dockerfile
├── k8s/
│   ├── README.md                # Helm deploy guide (run from bastion)
│   ├── charts/
│   │   ├── helloworld/          # Helm chart for FastAPI app
│   │   └── ingress-rules/       # Helm chart — Ingress routing rules
│   ├── values/
│   │   └── argocd/              # ArgoCD Helm values per environment
│   └── manifests/
│       └── cluster-issuer.yaml  # Let's Encrypt ClusterIssuer
├── terraform/                   # Option A: plain Terraform
│   ├── envs/
│   │   ├── dev.tfvars
│   │   └── prod.tfvars
│   └── modules/
│       ├── vpc/
│       ├── eks/
│       ├── bastion/
│       ├── ecr/
│       └── helm/
└── terragrunt/                  # Option B: Terragrunt multi-env
    ├── terragrunt.hcl
    ├── _envcommon/
    └── live/
        ├── dev/
        └── prod/
```

---

## Deployment Flow

```
1. terraform apply          → provision VPC, EKS, Bastion, ECR
2. docker buildx build      → build linux/amd64 image and push app image to ECR
3. EC2 Instance Connect     → access bastion (no SSH key needed)
4. helm install             → deploy apps to EKS (see k8s/README.md)
```

See [k8s/README.md](k8s/README.md) for the full helm deployment guide.
```

---

## Prerequisites

- AWS CLI configured with appropriate permissions
- Terraform >= 1.5.0
- Terragrunt >= 0.50.0 (Option B only)
- kubectl
- Helm >= 3.0
- Docker with Buildx (to build and push the Linux app image)

---

## Before You Start

### 1. Update placeholder values

In `terraform/envs/dev.tfvars` and `prod.tfvars`:
- Replace `admin_principal_arns` with your IAM user/role ARN
- Replace the rest as your desired values

```bash
# Get your IAM ARN
aws sts get-caller-identity --query Arn --output text
```

In `terragrunt/live/dev/env.hcl` and `prod/env.hcl`:
- Replace `111111111111` / `222222222222` with your AWS account IDs

### 2. Create S3 bucket and DynamoDB table for state
 **You need to create the state bucket before run IaC**

```bash
# S3 bucket for state
aws s3api create-bucket \
  --bucket mycompany-tfstate-YOUR_ACCOUNT_ID \
  --region ap-southeast-7 \
  --create-bucket-configuration LocationConstraint=ap-southeast-7

# (Optional) DynamoDB table for state locking
# ─────────────────────────────────────────────────────────────────────────────
# What it does: prevents two concurrent `terraform apply` runs from corrupting
#   the state file. When Terraform starts, it writes a lock record to DynamoDB.
#   Any other apply that runs at the same time will wait or fail until the lock
#   is released.
# When you need it: recommended for teams or CI/CD pipelines where multiple
#   people/jobs could run Terraform simultaneously.
# When you can skip it: safe to omit if you are the only person running
#   Terraform and never have concurrent pipeline runs. Simply remove
#   `dynamodb_table` from your .s3.tfbackend files.
# ─────────────────────────────────────────────────────────────────────────────
aws dynamodb create-table \
  --table-name terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region ap-southeast-7
```


---

## Option A: Plain Terraform

### Deploy Dev

> **Note:** EKS is a **private cluster** — the API endpoint is only reachable from inside the VPC.
> Bastion uses **EC2 Instance Connect Endpoint** (no public IP, no SSH key required).
> Apply in 2 steps:

```bash
cd terraform

# Step 1 — Init
terraform init -backend-config=envs/dev.s3.tfbackend

# Step 2 — Apply infra (VPC, EKS, Bastion + EIC Endpoint)
terraform apply -var-file="envs/dev.tfvars" \
  -target=module.vpc \
  -target=module.bastion \
  -target=module.eks \
  -target=module.ecr

# Step 3 — Connect to Bastion via EIC Endpoint (see "Connect via Bastion" below)
#           then verify: kubectl get nodes

# Step 4 — Build and push the application image before applying Kubernetes resources
export AWS_REGION="ap-southeast-7"
export AWS_ACCOUNT_ID="<your-aws-account-id>"
export ECR_REPOSITORY="helloworld"
export IMAGE_TAG="<your-image-tag>"

aws ecr get-login-password --region "${AWS_REGION}" | \
  docker login --username AWS --password-stdin "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

docker buildx create --use --name eks-builder 2>/dev/null || docker buildx use eks-builder
docker buildx build \
  --platform linux/amd64 \
  -f ./app/helloworld/Dockerfile \
  -t "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPOSITORY}:${IMAGE_TAG}" \
  ./app/helloworld \
  --push

# Step 5 — On Bastion: deploy Helm charts from the helm-deploy directory
#           (self-contained — only needs eks:DescribeCluster + ecr:DescribeRepositories)
cd helm-deploy
terraform init -backend-config=envs/dev.s3.tfbackend
terraform apply -var-file="envs/dev.tfvars"
```

### Deploy Prod

```bash
terraform init -reconfigure -backend-config=envs/prod.s3.tfbackend

# Step 1 — Infra
terraform apply -var-file="envs/prod.tfvars" \
  -target=module.vpc \
  -target=module.bastion \
  -target=module.eks

# Step 2 — On Bastion: deploy Helm charts
cd helm-deploy
terraform init -backend-config=envs/prod.s3.tfbackend
terraform apply -var-file="envs/prod.tfvars"
```

### Destroy

```bash
terraform destroy -var-file="envs/dev.tfvars"
```

---

## Option B: Terragrunt

### Deploy Dev (all modules in dependency order)

```bash
cd terragrunt/live/dev
terragrunt run-all apply
```

### Deploy Prod

```bash
cd terragrunt/live/prod
terragrunt run-all plan   # always plan first
terragrunt run-all apply
```

### Deploy single module

```bash
cd terragrunt/live/dev/eks
terragrunt apply
```

### Destroy Dev

```bash
cd terragrunt/live/dev
terragrunt run-all destroy
```

---

## After Deploy
### Build and push Hello World image to ECR

```bash

# Build and push
aws ecr get-login-password --region ap-southeast-7 | \
  docker login --username AWS --password-stdin YOUR_ACCOUNT_ID.dkr.ecr.ap-southeast-7.amazonaws.com

# Build cross platform Docker image with buildx
docker buildx build --platform linux/amd64 -t helloworld ./app/helloworld --load .

docker tag helloworld:latest YOUR_ACCOUNT_ID.dkr.ecr.ap-southeast-7.amazonaws.com/helloworld:latest

docker push YOUR_ACCOUNT_ID.dkr.ecr.ap-southeast-7.amazonaws.com/helloworld:latest
```

### Connect via Bastion

Bastion is in a private subnet with no public IP. Connect via **EC2 Instance Connect Endpoint** — no SSH key required.

```bash
# Get bastion instance ID
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=dev-bastion" "Name=instance-state-name,Values=running" \
  --query "Reservations[0].Instances[0].InstanceId" \
  --output text --region ap-southeast-7

# Connect via AWS CLI (EIC Endpoint)
aws ec2-instance-connect ssh \
  --instance-id <INSTANCE_ID> \
  --region ap-southeast-7

# Or connect via AWS Console → EC2 → Select instance → Connect → EC2 Instance Connect

# On bastion — kubeconfig is pre-configured by user_data
kubectl get nodes
kubectl get pods -A
```

## Apply K8S manifest files before go to the below step

```bash
# You need to go to 
/k8s/README.md 
# then follow the instruction
```



### Get NLB endpoint

```bash
kubectl get svc nginx-proxy-svc
# EXTERNAL-IP = <nlb-dns>.ap-southeast-7.elb.amazonaws.com
```

### Test endpoints

```bash
NLB="<nlb-dns>.ap-southeast-7.elb.amazonaws.com"

curl http://$NLB/app/
# {"message": "Hello World", "env": "dev", "status": "ok"}

curl http://$NLB/argocd/
# ArgoCD UI

curl http://$NLB/health
# ok
```

### ArgoCD initial password

```bash
kubectl get secret argocd-initial-admin-secret \
  -n argocd \
  -o jsonpath="{.data.password}" | base64 -d
```

---

## Environment Differences

| Setting           | Dev            | Prod           |
|-------------------|----------------|----------------|
| VPC CIDR          | 10.4.0.0/16    | 10.5.0.0/16    |
| Node type         | t3.medium      | t3.large       |
| Desired nodes     | 1              | 3              |
| Max nodes         | 2              | 10             |
| Image tag         | latest         | 1.0.0 (pinned) |
| App replicas      | 1              | 3              |
| NAT Gateway       | Single (cost)  | HA (multi-AZ)  |
