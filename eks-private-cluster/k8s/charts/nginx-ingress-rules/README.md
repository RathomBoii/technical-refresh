# ingress-rules Helm Chart

This chart defines Kubernetes **Ingress resources** that route traffic to the helloworld app and ArgoCD using the NGINX Ingress Controller.

## How it works

This chart does NOT contain an NGINX pod, Deployment, or Service.
Instead, it relies on the **NGINX Ingress Controller** which must be installed separately (see Prerequisites below).

```
app.wolffialampang.com ──┐
                         NLB → ingress-nginx controller → helloworld-svc:5000
argocd.wolffialampang.com─┘                             → argocd-server:8080
```

The controller watches for `Ingress` resources in the cluster and automatically configures its own internal NGINX routing — no manual `nginx.conf` management needed.

## Prerequisites

Install the NGINX Ingress Controller once per cluster:

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace \
  --set controller.service.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-scheme"=internet-facing \
  --set controller.service.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-type"=nlb
```

This creates:
- A Deployment running the NGINX pod (in `ingress-nginx` namespace)
- A LoadBalancer Service that provisions an AWS NLB

## Install this chart

```bash
helm upgrade --install ingress-rules ./k8s/charts/ingress-rules \
  --namespace ingress-nginx \
  -f k8s/charts/ingress-rules/values-dev.yaml
```

## Get the NLB endpoint

```bash
kubectl get svc -n ingress-nginx ingress-nginx-controller
# EXTERNAL-IP = <nlb-dns>.ap-southeast-7.elb.amazonaws.com
```

Point two DNS CNAME records to the NLB hostname:

| Record | Target |
|---|---|
| `app.wolffialampang.com` | `<nlb>.ap-southeast-7.elb.amazonaws.com` |
| `argocd.wolffialampang.com` | `<nlb>.ap-southeast-7.elb.amazonaws.com` |

## Values

| Key | Default | Description |
|---|---|---|
| `domains.app` | `app.example.com` | Domain for the helloworld app |
| `domains.argocd` | `argocd.example.com` | Domain for ArgoCD |
| `helloworld.serviceName` | `helloworld-svc` | Kubernetes Service name for helloworld |
| `helloworld.port` | `5000` | Port of the helloworld Service |
| `argocd.serviceName` | `argocd-server` | Kubernetes Service name for ArgoCD |
| `argocd.namespace` | `argocd` | Namespace where ArgoCD is installed |
| `argocd.port` | `8080` | Port of the ArgoCD Service |
