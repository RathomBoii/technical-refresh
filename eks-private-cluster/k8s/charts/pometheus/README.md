

```bash
k8s/values/prometheus/
├── values-dev.yaml   ← dev overrides (simple password, 7d retention, no alerting)
└── values-prod.yaml  ← prod overrides (strong resources, 30d retention, alerting on)

k8s/manifests/app-pometheus/
└── argocd-app-prometheus.yaml  ← Application CRD you kubectl apply to ArgoCD
```

No wrapper chart needed. ArgoCD pulls kube-prometheus-stack directly from the
Helm registry (https://prometheus-community.github.io/helm-charts) and applies
your values file from this Git repo using the multiple-sources pattern.

How to use
Step 1 — Register Prometheus with ArgoCD

kubectl apply -f k8s/manifests/app-pometheus/argocd-app-prometheus.yaml

That is all. ArgoCD handles everything from here:
  1. Pulls kube-prometheus-stack chart directly from the Helm registry
  2. Pulls values-dev.yaml from this Git repo
  3. Renders and deploys all Prometheus/Grafana resources into the monitoring namespace
  4. Watches for changes in Git and auto-syncs forever

No helm dependency update, no Chart.yaml, no charts/ folder required.

Step 2 — Switch to prod

Edit argocd-app-prometheus.yaml and change the values file reference:
  $values/eks-private-cluster/k8s/values/prometheus/values-dev.yaml
to:
  $values/eks-private-cluster/k8s/values/prometheus/values-prod.yaml

Then re-apply:
  kubectl apply -f k8s/manifests/app-pometheus/argocd-app-prometheus.yaml

Why ServerSideApply=true is critical for Prometheus
kube-prometheus-stack ships with very large CRDs (e.g. PrometheusRule). Without
ServerSideApply=true, kubectl apply hits a size limit and the sync fails with an
"annotation too large" error.