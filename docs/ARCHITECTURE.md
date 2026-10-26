# Architecture

## Overview

This platform demonstrates a layered, declarative delivery model on Azure:

1. **Infrastructure as Code (Terraform)** provisions the AKS cluster and network.
2. **GitOps (Argo CD)** continuously reconciles Kubernetes state from this repo.
3. **CI (GitHub Actions)** validates every change before it is merged.

Git is the single source of truth. Humans change Git; automation changes the cluster.

## Components

### Networking (Terraform module `modules/networking`)
- A virtual network with two subnets: one for AKS nodes (Azure CNI), one reserved
  for ingress / application gateway.
- A network security group on the AKS subnet that allows intra-VNet traffic and
  denies unsolicited inbound.

### AKS cluster (Terraform module `modules/aks`)
- Managed control plane with:
  - **Azure CNI** networking in the node subnet.
  - **Calico** network policy engine for pod-level isolation.
  - **AKS-managed Azure AD** + **Azure RBAC for Kubernetes** (local accounts disabled).
  - **System-assigned managed identity**, **OIDC issuer**, and **workload identity**.
  - **Key Vault Secrets Provider (CSI)** for runtime secret injection.
- Two node pools: a `system` pool (critical addons only) and an `app` user pool
  for workloads — both autoscaled.

### Remote state (Terraform `bootstrap`)
- A dedicated storage account with versioning and 30-day soft-delete holds the
  Terraform state, with one container per environment (`tfstate-dev`, `tfstate-prod`).
- The `azurerm` backend provides state locking via blob leases, preventing
  concurrent conflicting applies.

### Application (Helm chart `helm/sample-web-app`)
- Parameterized Deployment, Service, ServiceAccount, ConfigMap, HPA, and PDB.
- Environment-specific behavior comes solely from `values-dev.yaml` / `values-prod.yaml`.

### GitOps (Argo CD `argocd/`)
- An **AppProject** (`platform`) scopes which repo, namespaces, and resource kinds
  Applications may touch.
- An **app-of-apps** root Application bootstraps child Applications:
  - `security-baseline` (sync-wave -1) → `k8s/security`
  - `sample-web-app-dev` (auto-sync + self-heal)
  - `sample-web-app-prod` (manual sync for gated promotion)

### CI (GitHub Actions `.github/workflows`)
- `terraform-ci`: fmt check, validate (all modules + environments), and plan with
  Azure OIDC, posting the plan as a PR comment.
- `helm-ci`: lint across all value sets, template, and kubeconform on rendered output.
- `manifests-ci`: structural validation, kubeconform schema validation, and yamllint.

## Data / control flow

```
Developer → PR → GitHub Actions (validate/plan/lint) → review → merge to main
                                                                     │
         ┌───────────────────────────────────────────────────────────┤
         │ Terraform apply (manual/gated)        Argo CD (automatic)   │
         ▼                                        ▼
   Azure infra (AKS, VNet)              Reconcile k8s/security + Helm app
                                        detect drift → self-heal / alert
```

## Environment strategy

| Concern        | Dev                        | Prod                               |
|----------------|----------------------------|------------------------------------|
| Node sizes     | Standard_D2s_v5, small max | Standard_D4s_v5, larger max        |
| App replicas   | 2–4 (HPA)                  | 4–10 (HPA)                         |
| Argo sync      | Automatic + self-heal      | Manual sync (gated) + self-heal    |
| State container| tfstate-dev                | tfstate-prod                       |

See [SECURITY.md](SECURITY.md) for the security model and [INFRASTRUCTURE.md](INFRASTRUCTURE.md)
for the Terraform lifecycle.
