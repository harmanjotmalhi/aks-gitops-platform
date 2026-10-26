# Setup

End-to-end procedure to stand up the platform from an empty Azure subscription.

## Prerequisites

| Tool            | Purpose                                 |
|-----------------|-----------------------------------------|
| Azure CLI (`az`)| Authenticate & manage Azure             |
| Terraform ≥ 1.5 | Provision infrastructure                |
| kubectl         | Interact with the cluster               |
| helm ≥ 3.12     | Install Argo CD & inspect the app chart |
| An Azure subscription with Owner/Contributor + ability to create role assignments |

Also required:
- An **Azure AD group** whose object ID will be the cluster admin
  (`admin_group_object_ids`).
- A **GitHub repository** hosting this code; update every `repoURL` placeholder
  `https://github.com/your-org/aks-gitops-platform.git` to your actual repo.

## 1. Authenticate

```bash
az login
az account set --subscription <SUBSCRIPTION_ID>
```

## 2. Create the remote state backend (one-time)

```bash
cd terraform/bootstrap
terraform init
terraform apply
# Note the output: state_storage_account_name
```

If the default storage account name is taken (it must be globally unique), set a
new one: `terraform apply -var state_storage_account_name=<unique-name>` and
update the `storage_account_name` in each environment's `backend.tf`.

## 3. Provision the dev environment

```bash
cd ../environments/dev
# Edit terraform.tfvars: set admin_group_object_ids = ["<AAD_GROUP_OBJECT_ID>"]
terraform init
terraform plan
terraform apply
```

Fetch credentials using the emitted output:

```bash
az aks get-credentials --resource-group aksplat-dev-rg --name aksplat-dev-aks
kubectl get nodes
```

## 4. Install Argo CD

```bash
kubectl create namespace argocd
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
helm install argocd argo/argo-cd -n argocd -f ../../../argocd/install/values.yaml
```

Wait for the pods to be ready:

```bash
kubectl wait --for=condition=available deploy -l app.kubernetes.io/part-of=argocd -n argocd --timeout=300s
```

## 5. Bootstrap GitOps (app-of-apps)

Apply the project and the root Application:

```bash
kubectl apply -f ../../../argocd/projects/platform-project.yaml
kubectl apply -f ../../../argocd/applications/root-app.yaml
```

Argo CD now:
1. Syncs `security-baseline` (namespaces, RBAC, network policies, quotas).
2. Syncs `sample-web-app-dev` automatically.
3. Shows `sample-web-app-prod` as OutOfSync until you sync it manually.

Verify:

```bash
kubectl get applications -n argocd
kubectl get pods -n sample-app
```

## 6. Configure Key Vault secrets (optional)

To use the Key Vault CSI integration, follow the "Secrets" section of
[SECURITY.md](SECURITY.md) to create the vault, workload identity federation,
and populate the placeholders in `k8s/security/secretproviderclass.yaml`.

## 7. Promote to prod

Repeat step 3 in `terraform/environments/prod`, point Argo CD's prod Application
at the cluster, and sync it explicitly:

```bash
argocd app sync sample-web-app-prod
```

See [DEPLOYMENT.md](DEPLOYMENT.md) for the ongoing change workflow.
