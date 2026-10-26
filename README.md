# AKS GitOps Platform

A reusable, secure, and maintainable cloud-native platform on **Microsoft Azure** that combines
Infrastructure as Code (Terraform), GitOps continuous delivery (Argo CD), Kubernetes orchestration
(AKS), and CI/CD automation (GitHub Actions).

The platform provisions an AKS cluster and supporting networking with reusable Terraform modules,
deploys a sample web application via Helm, and lets Argo CD continuously reconcile the live cluster
state against this Git repository — giving you declarative deployments, drift detection, self-healing,
and Git-driven rollbacks.

---

## Architecture

```
                          ┌─────────────────────────────────────────────┐
                          │                 GitHub Repo                  │
                          │  terraform/  helm/  k8s/  argocd/  .github/  │
                          └───────────────┬───────────────┬─────────────┘
                                          │               │
                        git push / PR     │               │  watches (GitOps)
                                          ▼               ▼
                        ┌──────────────────────┐   ┌────────────────────────┐
                        │   GitHub Actions CI   │   │        Argo CD         │
                        │  - terraform fmt/     │   │  (runs inside AKS)     │
                        │    validate/plan      │   │  - sync desired state  │
                        │  - helm lint/template │   │  - drift detection     │
                        │  - kubeconform/kubeval│   │  - self-heal           │
                        └───────────┬──────────┘   │  - rollback via Git    │
                                    │              └───────────┬────────────┘
                     terraform apply│ (manual/gated)           │ apply manifests
                                    ▼                          ▼
   ┌───────────────────────────────────────────────────────────────────────────────┐
   │                               Microsoft Azure                                    │
   │                                                                                  │
   │   ┌──────────────┐   ┌─────────────────────────────────────────────────────┐    │
   │   │  Remote State│   │                Virtual Network (networking module)  │    │
   │   │  Storage Acct│   │   ┌──────────────┐   ┌──────────────────────────┐    │    │
   │   │  + state lock│   │   │ AKS subnet   │   │ App Gateway / Ingress sub │    │    │
   │   └──────────────┘   │   └──────┬───────┘   └──────────────────────────┘    │    │
   │                      │          │                                           │    │
   │                      │   ┌──────▼─────────────────────────────────────┐    │    │
   │                      │   │        AKS Cluster (aks module)            │    │    │
   │                      │   │  - system + user node pools                │    │    │
   │                      │   │  - Azure CNI, network policy (calico)      │    │    │
   │                      │   │  - RBAC + Managed Identity + Workload ID    │   │    │
   │                      │   │  ┌──────────┐ ┌──────────┐ ┌─────────────┐  │    │    │
   │                      │   │  │ argocd   │ │ platform │ │ sample-app  │  │    │    │
   │                      │   │  │ namespace│ │ namespace│ │ namespace   │  │    │    │
   │                      │   │  └──────────┘ └──────────┘ └─────────────┘  │    │    │
   │                      │   └────────────────────────────────────────────┘    │    │
   │                      └─────────────────────────────────────────────────────┘    │
   └───────────────────────────────────────────────────────────────────────────────┘
```

## Repository layout

```
aks-gitops-platform/
├── README.md                      # this file
├── terraform/
│   ├── modules/
│   │   ├── networking/            # reusable VNet/subnet/NSG module
│   │   └── aks/                   # reusable AKS cluster module
│   ├── bootstrap/                 # creates remote-state storage backend
│   └── environments/
│       ├── dev/                   # dev root config + backend + tfvars
│       └── prod/                  # prod root config + backend + tfvars
├── helm/
│   └── sample-web-app/            # Helm chart for the sample application
│       ├── Chart.yaml
│       ├── values.yaml            # defaults
│       ├── values-dev.yaml        # dev overrides
│       ├── values-prod.yaml       # prod overrides
│       └── templates/
├── k8s/
│   └── security/                  # namespaces, RBAC, network policies, secrets
├── argocd/
│   ├── install/                   # Argo CD bootstrap values
│   ├── projects/                  # AppProject (RBAC boundary)
│   └── applications/              # Application + ApplicationSet (app-of-apps)
├── docs/                          # architecture, setup, lifecycle, security, runbooks
└── .github/workflows/             # CI pipelines
```

## Quick start

1. **Provision remote state backend** (one-time): `terraform/bootstrap`
2. **Provision infrastructure**: `terraform/environments/dev` → `terraform apply`
3. **Install Argo CD**: `argocd/install`
4. **Bootstrap GitOps**: apply the app-of-apps `argocd/applications/root-app.yaml`
5. Argo CD then syncs `k8s/security` and the `helm/sample-web-app` chart automatically.

See [`docs/SETUP.md`](docs/SETUP.md) for the full step-by-step guide.

## Documentation index

| Doc | Purpose |
|-----|---------|
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Component design & data flow |
| [docs/SETUP.md](docs/SETUP.md) | End-to-end setup procedure |
| [docs/INFRASTRUCTURE.md](docs/INFRASTRUCTURE.md) | Terraform lifecycle & module reference |
| [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md) | GitOps deployment workflow & rollbacks |
| [docs/SECURITY.md](docs/SECURITY.md) | RBAC, network policy, secrets decisions |
| [docs/RUNBOOKS.md](docs/RUNBOOKS.md) | Monitoring, troubleshooting, drift recovery |

## Design principles

- **Reusable** — Terraform modules and a parameterized Helm chart are environment-agnostic; environments differ only by variables/values files.
- **Secure by default** — RBAC least-privilege, namespace isolation, default-deny network policies, no plaintext secrets in Git.
- **Declarative** — Git is the single source of truth; Argo CD reconciles continuously.
- **Validated** — every change is linted, validated, and planned in CI before merge.
