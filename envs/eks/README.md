# envs/eks: the EKS environment (P9.2)

Written offline: helm lint and template, YAML parsing. **None of it has run on a cluster yet.**

## What is where

| Path | What |
|---|---|
| `envs/eks/values.yaml` | The chart values for EKS (HTTP mode, RDS, gp3 Redis, ALB annotations, placeholders) |
| `envs/eks/sealed.values.yaml` | **Does not exist yet.** Written by `linkforge/scripts/eks-seal-and-enable.sh` (P9.3) against this cluster's sealing key |
| `argocd/eks/root.yaml` | The root Application: the one object applied by hand (P9.3) |
| `argocd/eks/apps/` | Watched by the root: sealed-secrets, eks-storage (gp3), metrics-server, aws-load-balancer-controller (all wave -3) |
| `argocd/eks/pending/linkforge.yaml` | The app. Moved to `apps/` by the enable script, in the same commit as `sealed.values.yaml` |
| `argocd/eks/optional/monitoring.yaml` | Lean monitoring, off by default (`git mv` to `apps/` and switch the three `monitoring.*` flags on) |
| `platform/eks/storage/` | The gp3 StorageClass (Redis claim) |
| `platform/monitoring/values-eks.yaml` | Lean overrides for the monitoring chart |

## Order on a new cluster (what P9.3 automates)

1. Terraform `cloud/` is applied (you). Nodes, RDS, roles and Pod Identity associations exist.
2. Argo CD is installed and the **root** is applied. It creates the four wave -3 apps. The load balancer controller must be Healthy.
3. **Phase 1, hosts unknown.** `linkforge` is still in `pending/`. Run `linkforge/scripts/eks-seal-and-enable.sh`: it seals `DATABASE_URL` (RDS host + password piped
   from `terraform output`, never printed) and a fresh `IP_HASH_SECRET`, writes `sealed.values.yaml`, `git mv`s the Application into `apps/`, commits, pushes.
   The app syncs with `pending.invalid` as every host: the migration runs, the pods start, the two Ingresses create the **two ALBs**, the go ALB answers 404 to all.
4. **Confirm the two-ALB assumption** (the docs say an Ingress without `group.name` gets its own ALB; this is the first place it is tested):
   `kubectl get ingress -n linkforge` must show TWO different `ADDRESS` names. If it shows one, stop: the design needs the second approach.
5. **Phase 2, real hosts.** `linkforge/scripts/eks-set-hosts.sh <app-alb-dns> <go-alb-dns>` writes them into `envs/eks/values.yaml` (`ALLOWED_ORIGINS`,
   `SHORT_URL_BASE`, `PUBLIC_REDIRECT_HOST`), commits, pushes; the pods roll once. Now `http://<app-alb-dns>` loads the UI and `http://<go-alb-dns>/<code>` redirects.

Before step 3 replace `REPLACE_WITH_YOUR_IP/32` in `values.yaml` (`inbound-cidrs`) with your IP as a /32, or with `0.0.0.0/0` on purpose. The enable script refuses
to run while the placeholder is still there (an invalid CIDR should make the controller report an error instead of opening the ALB, but that is not relied on).

## HTTP mode: what you give up
There is **no TLS**: passwords, session cookies and API keys cross the internet in clear text. `COOKIE_SECURE` is false because a Secure cookie would never be sent
back over HTTP. Test accounts only, ALBs restricted to your IP, and the demo is short. The ALB names are long and change every time the cluster is recreated.

## Domain mode (optional, when you own a domain)
Terraform `cloud/` with `domain_name` creates the ACM certificate (and later the alias records). Then overlay, in the Application's `valueFiles` after `values.yaml`
(an example is `envs/eks/domain.values.yaml.example`): `hostRules: true`, `appHost`/`goHost`, HTTPS listener + `certificate-arn` annotations, `COOKIE_SECURE: "true"`,
`https://` origins. Nothing in the chart needs to change.

## Capacity (computed, not measured)
Pods that must fit, with the monitoring app OFF: per node 4 DaemonSet pods (aws-node, kube-proxy, eks-pod-identity-agent, ebs-csi-node); cluster-wide 11
(coredns 2, ebs-csi-controller 2, load balancer controller 1, metrics-server 1, Argo CD 4, sealed-secrets 1); the app 5 (api 2, worker, frontend, redis),
up to 9 when the HPA reaches 6 API pods, plus the migration pod for a minute. With 2 nodes that is 8 + 11 + 5 = **24 at rest, about 29 at the HPA maximum**.
Lean monitoring (operator, Prometheus, Grafana, kube-state-metrics) adds 4. Compare with `NetworkInfo` of the chosen instance type (max pods = ENIs x (IPs per ENI - 1) + 2:
`t3.medium` 17 per node, so 34 for two); this is why the earlier estimate of 32-37 pods (full kind-style monitoring with Alertmanager and node-exporter) did not fit and this one
barely does. A third node (or `m7i-flex.large`, whose limit must be read from the CLI) gives room.

## Destroy order (the details are in the P9.4 checklist)
1. Delete the `linkforge` Application (cascade): the Ingresses go, and the controller deletes both ALBs, their target groups and security groups.
2. `kubectl delete namespace linkforge`: this also removes the Redis PersistentVolumeClaim (StatefulSet claims are not tracked by Argo), and with it the EBS volume
   (reclaim policy Delete). Skipping it leaves a billing volume behind.
3. Delete the root, wait, then `terraform destroy` in `infra/terraform/cloud`.
