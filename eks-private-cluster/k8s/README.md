# Helm Deployment Guide

Run these commands from the bastion host inside the `eks-private-cluster/` directory.

## Dev

### Each Helm Chart have `values.yaml` as the baseline and  `values-dev.yaml` as an overider for specific environment

***The duplicated key in `values-{env}.yaml` file will override the baseline values from `values.yaml`***

```bash
# 1 — Install NGINX Ingress Controller (creates the NLB automatically)
# Ref: https://kubernetes.github.io/ingress-nginx/deploy/#aws
#
# service.beta.kubernetes.io/aws-load-balancer-scheme: "internet-facing"
#   → Makes the NLB publicly accessible from the internet (vs "internal" for VPC-only).
#   → Source: NGINX Ingress — AWS deployment guide
#     https://kubernetes.github.io/ingress-nginx/deploy/#aws
#
# service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
#   → Tells AWS to provision a Network Load Balancer instead of the default Classic LB.
#   → Source: AWS in-tree cloud provider Service annotations
#     https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.7/guide/service/annotations/
# helm upgrade --install {release_name}} {repo_alias}/{chart_name}
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update 
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \  # <= It's automatically register this nginx ingress controller as ingressClass = "nginx"
  --namespace ingress-nginx --create-namespace \
  --set controller.service.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-scheme"=internet-facing \
  --set controller.service.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-type"=nlb

# 2 — cert-manager (issues TLS certs from Let's Encrypt automatically)
helm repo add jetstack https://charts.jetstack.io
helm repo update
helm upgrade --install cert-manager jetstack/cert-manager \
  --namespace cert-manager --create-namespace \
  --set crds.enabled=true

# Create ClusterIssuer (edit k8s/manifests/cluster-issuer.yaml to set your email first)
kubectl apply -f k8s/manifests/cluster-issuer.yaml

# 3 — ArgoCD
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
helm upgrade --install argocd argo/argo-cd \
  --namespace argocd --create-namespace \
  --version 6.7.0 \
  -f k8s/values/argocd/values-dev.yaml

# 4 — Hello World (via ArgoCD — GitOps)
# ArgoCD will deploy helloworld from Git. No direct helm install needed.
#  The chart is just for the example how you can pack your manifest files as a chart and share tp your internal team.
# Edit repoURL in k8s/manifests/argocd-app-helloworld.yaml first.
kubectl apply -f k8s/manifests/app-helloworld/argocd-app-helloworld.yaml

# 5 — Prometheus + Grafana (cluster monitoring)
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace \
  -f k8s/values/prometheus/values-dev.yaml

# 6 — Ingress rules (points domains to services — includes Grafana)
helm upgrade --install ingress-rules ./k8s/charts/ingress-rules \
  --namespace ingress-nginx \
  -f k8s/charts/ingress-rules/values-dev.yaml
```

> **DNS:** Add a CNAME record `grafana` → NLB hostname (same target as `app` and `argocd`).
> Grafana dashboard will be available at `https://grafana.wolffialampang.com`
> Default login: `admin` / password set in `k8s/values/prometheus/values-dev.yaml`

## Verify

```bash
helm list -A
kubectl get pods -A
kubectl get ingress -A

# Get NLB endpoint
kubectl get svc -n ingress-nginx ingress-nginx-controller
```

## Register helloworld in ArgoCD (GitOps)

### How ArgoCD tracks apps

Installing ArgoCD via Helm only sets up the ArgoCD server — it does not automatically
track any applications. To make ArgoCD manage an app, you create an **ArgoCD Application**
resource that points to your Git repo and chart path.

**1 app = 1 Application manifest.** ArgoCD watches the repo and auto-syncs on every push.

At scale, use **ApplicationSet** to generate many Application resources from a single template
instead of writing one file per app — see the [ApplicationSet docs](https://argo-cd.readthedocs.io/en/stable/user-guide/application-set/) for details.

### Register helloworld

#### Private repo — grant ArgoCD access first

**Option A — GitHub App (recommended, no long-lived credentials)**

1. GitHub → Settings → Developer settings → GitHub Apps → **New GitHub App**
   - Permissions: Contents = Read-only, Metadata = Read-only
   - Webhook: uncheck Active
2. Generate a private key → download `.pem` file
3. Install the App on your repo → note the **App ID** and **Installation ID**
4. On the bastion:

```bash
kubectl create secret generic github-app-repo \
  --namespace argocd \
  --from-literal=type=git \
  --from-literal=url=https://github.com/<your-user>/<your-repo> \
  --from-literal=githubAppID=<app-id> \
  --from-literal=githubAppInstallationID=<installation-id> \
  --from-file=githubAppPrivateKey=/path/to/your-app.pem

kubectl label secret github-app-repo \
  -n argocd \
  argocd.argoproj.io/secret-type=repository
```

**Option B — Personal Access Token (simpler, but requires rotation)**

```bash
# On bastion — create repo credentials secret
kubectl create secret generic helloworld-repo \
  --namespace argocd \
  --from-literal=type=git \
  --from-literal=url=https://github.com/<your-user>/<your-repo> \
  --from-literal=username=<your-github-username> \
  --from-literal=password=<your-github-pat>

# Label it so ArgoCD recognises it as a repo credential
kubectl label secret helloworld-repo \
  -n argocd \
  argocd.argoproj.io/secret-type=repository
```

**Option C — Public repo**

No secret needed. Skip directly to the apply step below.

---

#### Apply the Application

```bash
# Edit repoURL in the manifest first:
# k8s/manifests/app-helloworld/argocd-app-helloworld.yaml → set repoURL to your GitHub repo

kubectl apply -f k8s/manifests/app-helloworld/argocd-app-helloworld.yaml
```

ArgoCD will then:
1. Pull `k8s/charts/helloworld` from your Git repo
2. Deploy it to the `dev-app` namespace
3. Show sync status in the UI at `https://argocd.wolffialampang.com`
4. Auto-sync on every `git push` (prune + selfHeal enabled)

## Uninstall

```bash
helm uninstall ingress-rules -n ingress-nginx
kubectl delete -f k8s/manifests/argocd-app-helloworld.yaml   # ArgoCD will delete helloworld pods
helm uninstall argocd -n argocd
helm uninstall cert-manager -n cert-manager
helm uninstall ingress-nginx -n ingress-nginx
```
