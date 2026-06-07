# EKS On-Call Runbook and Ingress Decision Matrix

This guide is written for the current architecture in this repository:

- Private EKS control plane
- NLB fronting `ingress-nginx`
- ArgoCD for GitOps
- cert-manager for TLS
- Prometheus and Grafana for cluster monitoring
- Bastion host for `kubectl`, `helm`, and AWS CLI access

Use this guide from the bastion host unless stated otherwise.

## 1. On-Call Operating Model

### Severity levels

| Severity | Meaning | Example | Update cadence |
| --- | --- | --- | --- |
| `SEV1` | Broad outage or critical security event | Public ingress down, all apps unavailable | Every 10-15 min |
| `SEV2` | Major degradation with partial service available | High 5xx, TLS broken for one major domain | Every 30 min |
| `SEV3` | Limited degradation with workaround | One app rollout failed, can rollback | Every 60 min |
| `SEV4` | Internal issue with low user impact | Alert noise, one pod restarting without user impact | Best effort |

### Incident roles

| Role | Responsibility |
| --- | --- |
| `Incident Commander` | Own incident flow, assign tasks, approve mitigation |
| `Operator` | Run commands, collect evidence, apply rollback or mitigation |
| `Comms` | Update stakeholders with facts only |
| `Scribe` | Keep timeline, commands used, and decision log |

In a small team, one person may hold multiple roles, but always be explicit about who is deciding and who is executing.

### SLO guardrails

Use these as a starting point for platform operations.

| SLO | Target |
| --- | --- |
| Ingress availability | `99.9%` monthly |
| TLS success rate | `99.95%` monthly |
| App HTTP success rate | `99.9%` monthly |
| p95 latency | `< 300 ms` for the demo app |
| Mean time to detect | `< 5 min` for SEV1/SEV2 |
| Mean time to mitigate | `< 30 min` for SEV2 |

### First 5 minutes checklist

1. Confirm severity and user impact.
2. Freeze risky changes: pause manual deploys and avoid unrelated `helm upgrade` or `terraform apply`.
3. Identify blast radius: one app, one namespace, one controller, or cluster-wide.
4. Pick mitigation first, root cause second.
5. Start a timeline.

### Core commands

```bash
kubectl get pods -A
kubectl get ingress -A
kubectl get svc -A
kubectl get events -A --sort-by=.lastTimestamp

kubectl logs -n ingress-nginx deploy/ingress-nginx-controller --tail=200
kubectl logs -n argocd deploy/argocd-server --tail=200
kubectl logs -n cert-manager deploy/cert-manager --tail=200

kubectl top pods -A
kubectl top nodes
```

## 2. Incident Runbooks

### Incident 1: Public traffic fails or users see 5xx from ingress

### Symptoms

- `app.wolffialampang.com` or `argocd.wolffialampang.com` returns `502`, `503`, or `504`
- NLB DNS resolves but requests fail or time out
- Grafana or app health endpoints fail externally

### Likely causes

- `ingress-nginx-controller` pods not ready
- Bad ingress config or bad upstream service endpoints
- NLB targets unhealthy
- Backend pods ready state failing

### Triage

```bash
kubectl get pods -n ingress-nginx
kubectl get svc -n ingress-nginx ingress-nginx-controller -o wide
kubectl get ingress -A
kubectl get endpoints -A
kubectl describe ingress -A
kubectl logs -n ingress-nginx deploy/ingress-nginx-controller --tail=300
```

### AWS checks

```bash
aws elbv2 describe-load-balancers --region ap-southeast-7
aws elbv2 describe-target-groups --region ap-southeast-7
aws elbv2 describe-target-health --target-group-arn <target-group-arn> --region ap-southeast-7
```

### Mitigation

1. If ingress controller pods are unhealthy, restart only the controller deployment.

```bash
kubectl rollout restart deployment ingress-nginx-controller -n ingress-nginx
kubectl rollout status deployment ingress-nginx-controller -n ingress-nginx
```

2. If the backend service has no endpoints, fix the app rollout or rollback ArgoCD revision.

```bash
kubectl get pods -n dev-app
kubectl rollout undo deployment/<deployment-name> -n dev-app
```

3. If ingress rules are broken, rollback the `ingress-rules` chart to the previous release.

```bash
helm history ingress-rules -n ingress-nginx
helm rollback ingress-rules <revision> -n ingress-nginx
```

### Escalate when

- NLB targets stay unhealthy after controller recovery
- Multiple namespaces fail at once
- No safe rollback is available

### Post-incident follow-up

- Add or tune alerts for ingress 5xx and upstream latency
- Add `PodDisruptionBudget` and HPA for ingress controller
- Review ingress config blast radius

### Incident 2: TLS certificate pending, invalid, or expired

### Symptoms

- Browser shows invalid cert or HTTP only
- `kubectl get certificate -A` shows `False` or `Pending`
- TLS secret is missing or not type `kubernetes.io/tls`

### Likely causes

- `cert-manager` pod unhealthy
- `ClusterIssuer` misconfigured
- HTTP-01 challenge path blocked by ingress
- DNS record does not point to the current NLB

### Triage

```bash
kubectl get pods -n cert-manager
kubectl get clusterissuer
kubectl describe clusterissuer letsencrypt-prod
kubectl get certificate -A
kubectl describe certificate -A
kubectl get challenge -A
kubectl describe challenge -A
kubectl get secret -A | grep tls
```

### Mitigation

1. If `cert-manager` is unhealthy, restart the deployment.

```bash
kubectl rollout restart deployment cert-manager -n cert-manager
kubectl rollout status deployment cert-manager -n cert-manager
```

2. If the challenge is blocked by ingress, verify `ingressClassName: nginx` in [eks-private-cluster/k8s/manifests/cluster-issuer.yaml](eks-private-cluster/k8s/manifests/cluster-issuer.yaml).

3. If DNS is wrong, update the CNAME or alias to the active NLB hostname.

4. If ingress redirects break HTTP-01 challenge unexpectedly, inspect challenge solver ingress before changing redirect behavior.

### Validation

```bash
curl -vk https://argocd.wolffialampang.com/
curl -vk https://grafana.wolffialampang.com/
```

### Escalate when

- LetsEncrypt rate limit is hit
- DNS is controlled by another team and blocks recovery
- All domains fail at once

### Post-incident follow-up

- Add cert expiry alerts at 14d, 7d, and 3d
- Document domain ownership and DNS change path
- Add a runbook for HTTP-01 solver diagnostics

### Incident 3: ArgoCD sync succeeds or runs, but app does not become healthy

### Symptoms

- ArgoCD app shows `OutOfSync`, `Progressing`, or `Degraded`
- `dev-app` namespace exists but pods are missing or crash looping
- New image tag was pushed but deployment is not serving traffic

### Likely causes

- Wrong image tag in `values-dev.yaml`
- ECR pull failure or repo permission issue
- App manifest renders incorrectly
- ArgoCD repo credentials or repo access failed

### Triage

```bash
kubectl get application -n argocd
kubectl describe application helloworld -n argocd
kubectl get pods -n dev-app
kubectl describe pods -n dev-app
kubectl get events -n dev-app --sort-by=.lastTimestamp
kubectl get deploy,rs,svc -n dev-app
```

### Image and rollout checks

```bash
kubectl describe deployment -n dev-app
kubectl get pod -n dev-app -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.containerStatuses[*].state.waiting.reason}{"\n"}{end}'
```

### Mitigation

1. If the image tag is wrong, update the Helm values and resync ArgoCD.
2. If the rollout is bad, sync to the previous Git revision or rollback the deployment.

```bash
kubectl rollout undo deployment/<deployment-name> -n dev-app
```

3. If ECR auth or permissions are broken, validate node role or workload identity permissions and test image pull manually from a debug pod.

### Escalate when

- ArgoCD cannot fetch the repo
- Image exists in ECR but nodes still cannot pull
- The deployment is healthy internally but ingress still fails

### Post-incident follow-up

- Add admission checks to block nonexistent image tags
- Add app-level readiness and startup probes
- Add deployment failure alerts from ArgoCD or Prometheus

### Incident 4: Nodes become `NotReady`, pods stay `Pending`, or capacity runs out

### Symptoms

- `kubectl get nodes` shows `NotReady`
- Pods remain `Pending`
- `kubectl describe pod` shows scheduling failures
- Multiple workloads restart during node drain or maintenance

### Likely causes

- Node group capacity too small
- AZ or subnet IP exhaustion
- DaemonSet pressure or resource requests too high
- Cluster autoscaling not present for workload spikes

### Triage

```bash
kubectl get nodes -o wide
kubectl describe nodes
kubectl top nodes
kubectl get pods -A --field-selector=status.phase=Pending
kubectl describe pod <pod-name> -n <namespace>
kubectl get events -A --sort-by=.lastTimestamp | tail -n 50
```

### AWS checks

```bash
aws eks describe-nodegroup --cluster-name <cluster-name> --nodegroup-name <nodegroup-name> --region ap-southeast-7
aws ec2 describe-subnets --subnet-ids <subnet-id-1> <subnet-id-2> --region ap-southeast-7
```

### Mitigation

1. If a node is unhealthy, cordon and drain it only if enough spare capacity exists.

```bash
kubectl cordon <node-name>
kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data
```

2. If capacity is too low, temporarily scale the managed node group.
3. If pods are `Pending` due to requests, reduce over-provisioned requests or temporarily scale critical workloads only.

### Escalate when

- Both AZs are impacted
- Subnet IPs are exhausted
- Critical namespaces cannot schedule core controllers

### Post-incident follow-up

- Introduce Karpenter or Cluster Autoscaler
- Add `PodDisruptionBudget` and topology spread constraints
- Review subnet sizing and VPC CNI IP planning

### Incident 5: ECR image pull fails or pods enter `ImagePullBackOff` / `CrashLoopBackOff`

### Symptoms

- Pods fail with `ErrImagePull`, `ImagePullBackOff`, or repeated restarts
- New deployment reaches cluster but never becomes ready

### Likely causes

- Wrong image tag or repository URI
- ECR permissions missing on node role or workload identity
- App starts but fails health checks
- New image is bad and needs rollback

### Triage

```bash
kubectl get pods -n dev-app
kubectl describe pod <pod-name> -n dev-app
kubectl logs <pod-name> -n dev-app --previous
kubectl get deployment -n dev-app -o yaml | grep image:
```

### AWS checks

```bash
aws ecr describe-images \
  --repository-name helloworld \
  --region ap-southeast-7 \
  --query 'imageDetails[].imageTags' \
  --output table
```

### Mitigation

1. Roll back to the last known good image tag.
2. If image tag exists but pull fails, verify IAM permissions and VPC endpoint reachability.
3. If the container starts but crashes, inspect app logs and health probe configuration.

```bash
kubectl rollout undo deployment/<deployment-name> -n dev-app
```

### Escalate when

- The last known good image also fails
- Pull failures affect multiple namespaces or controllers
- VPC endpoints or ECR service health are suspect

### Post-incident follow-up

- Enforce image existence checks in CI
- Add startup probes and better crash diagnostics
- Add deployment policy to block mutable or unverified tags

## 3. Recommended Alert Pack

Start with these alerts to protect the platform SLOs.

| Area | Alert |
| --- | --- |
| Ingress | 5xx rate high, target unhealthy, ingress controller pod not ready |
| TLS | certificate expiry, challenge failure |
| App | HTTP success rate low, p95 latency high, restart spike |
| ArgoCD | app degraded, sync failed, repo fetch failed |
| Nodes | node not ready, disk pressure, memory pressure, pending pods |
| ECR / deploy | image pull failures, rollout stuck |

## 4. Decision Matrix: NLB + NGINX Ingress vs AWS Load Balancer Controller

This section is designed so you can also use it as an interview answer.

### Quick summary

- `NLB + NGINX` is better when you want one shared ingress layer with rich L7 routing behavior and you can absorb more platform operations.
- `AWS Load Balancer Controller` is better when you want stronger AWS-native integration, clearer per-app isolation, and lower reverse-proxy operations burden.

### Decision matrix

| Dimension | NLB + NGINX Ingress | AWS Load Balancer Controller |
| --- | --- | --- |
| Data path | `NLB -> ingress-nginx -> Service -> Pod` | `ALB/NLB -> Service/Pod target group` depending on pattern |
| L7 flexibility | Strongest: rewrite, custom headers, advanced routing, mature NGINX config | Good, but more limited for complex proxy behavior |
| AWS native integration | Moderate | Strong: WAF, ACM, Shield, Cognito/OIDC, target group features |
| Shared ingress model | Very good for many apps behind one ingress tier | Less efficient if each app gets its own ALB |
| Blast radius | Higher, because one ingress controller can affect many apps | Lower per app/team if ALBs are isolated |
| Ops burden | Higher: controller tuning, upgrades, config safety | Lower on proxy layer, but still need controller ops |
| Cost profile | Often cheaper when many apps share one NLB | Can become expensive with many ALBs |
| Security model | Needs extra work for WAF or auth at edge | Strong AWS-native edge security integrations |
| Debugging | Must inspect NGINX config, controller logs, upstreams, and LB | Easier for AWS-side LB health, but AWS annotations can get complex |
| Team fit | Better for platform teams that want central ingress control | Better for AWS-centric teams and app-level ownership |

### Trade-off narrative for interviews

Use this answer structure:

1. Start from the operating model.
2. State the blast radius and on-call implications.
3. State the AWS integration and cost trade-offs.
4. End with the decision for the current platform.

Example answer:

> I would choose based on operating model rather than saying one is always better. If the team wants a shared ingress layer with strong L7 routing, consistent policy, and lower cost across many services, I would use NLB plus ingress-nginx. The trade-off is higher platform operations burden and larger blast radius because the ingress controller becomes a shared dependency. If the team wants stronger AWS-native integrations like WAF, ACM, and Cognito, plus clearer per-application isolation, I would lean toward AWS Load Balancer Controller with ALB. The trade-off is higher cost and tighter AWS coupling. For this repository's current shared-ingress design, NLB plus ingress-nginx is a reasonable choice, but it needs stronger runbooks, alerting, scaling, and rollback discipline to support SLOs.

### Recommended choice for this repository today

Stay with `NLB + ingress-nginx` for now because the repository is built around:

- Shared ingress rules in one chart
- Shared TLS management through cert-manager
- Multiple public domains routed through one ingress tier
- A learning platform where central routing is easier to reason about

Revisit ALB Controller when one or more of these becomes true:

- You need WAF or AWS-native auth at the edge
- Teams want per-app ingress ownership
- You want tighter integration with AWS networking and security controls
- The blast radius of the shared NGINX ingress becomes unacceptable

## 5. Improvement Backlog

To make this platform production-grade, prioritize these next:

1. Enable Alertmanager and route alerts to Slack or PagerDuty.
2. Add `PodDisruptionBudget`, HPA, and topology spread for critical workloads.
3. Add runbooks for subnet IP exhaustion and EKS access plane issues.
4. Add Karpenter or cluster autoscaling for workload spikes.
5. Add policy enforcement and secrets management.