# Security

Security decisions and how they are implemented, by layer.

## Identity & cluster access

- **AKS-managed Azure AD + Azure RBAC for Kubernetes**: Kubernetes authorization
  is delegated to Azure RBAC. `local_account_disabled = true` removes the static
  cluster-admin kubeconfig, so every user authenticates through Azure AD.
- **Cluster-admin** is granted only to the Azure AD group(s) in
  `admin_group_object_ids`.
- **Managed identity + Workload Identity (OIDC)**: pods federate to Azure AD
  identities via the cluster OIDC issuer — no service principal secrets in cluster.

## Namespace isolation & Pod Security Standards

- Each workload domain has its own namespace (`sample-app`, `platform`, `argocd`).
- `sample-app` enforces the **restricted** Pod Security Standard
  (`pod-security.kubernetes.io/enforce: restricted`), rejecting privileged pods,
  host namespaces, and root containers.
- The sample app's pods satisfy restricted: non-root user, dropped capabilities,
  `allowPrivilegeEscalation: false`, read-only root filesystem, seccomp
  `RuntimeDefault`.

## RBAC (least privilege)

Defined in `k8s/security/rbac.yaml`:
- **app-developer** (namespaced Role): read/observe workloads + `pods/exec` for
  debugging; cannot mutate deployments, secrets, RBAC, or network policy.
- **app-operator** (namespaced Role): manage app workloads (deploy/scale/rollback)
  within `sample-app` only.
- Subjects are Azure AD **Group** object IDs — update the placeholder GUIDs.
- No ClusterRoleBindings for app personas; blast radius is confined to `sample-app`.

## Network policy (default-deny)

Enforced by Calico (`k8s/security/network-policies.yaml`):
- `default-deny-all` denies all ingress and egress in `sample-app`.
- Explicit allows re-enable only required flows:
  - DNS egress to kube-system.
  - Ingress to the web app on port 8080 from the `platform` namespace only.
  - HTTPS (443) egress for external/Key Vault calls, excluding link-local and
    private ranges to limit lateral movement.

## Secrets management (no secrets in Git)

- Secret **values are never committed**. Git contains only references.
- The **Azure Key Vault Provider for Secrets Store CSI Driver** (enabled via the
  AKS Terraform `key_vault_secrets_provider` block) mounts secrets at runtime and
  can sync them into a Kubernetes Secret (`secretObjects` in
  `secretproviderclass.yaml`).
- Access to Key Vault uses workload identity with the **Key Vault Secrets User**
  role — least privilege, no long-lived credentials.
- `.gitignore` blocks `*.tfvars` secret files, `*.pem`, `*.key`, `kubeconfig*`.

### Wiring Key Vault (summary)

```bash
# 1. Create a vault and secret
az keyvault create -n <kv-name> -g <rg> --enable-rbac-authorization true
az keyvault secret set --vault-name <kv-name> -n db-password --value <value>

# 2. Create a user-assigned identity and federate to the app ServiceAccount
az identity create -n sample-app-id -g <rg>
# ... create federated credential against the AKS OIDC issuer + SA subject ...

# 3. Grant it Key Vault access
az role assignment create --role "Key Vault Secrets User" \
  --assignee <identity-client-id> --scope <vault-resource-id>

# 4. Fill placeholders in k8s/security/secretproviderclass.yaml:
#    clientID, keyvaultName, tenantId
```

## Supply-chain & CI gates

- `terraform-ci`, `helm-ci`, `manifests-ci` block merges on lint/validate failures.
- Argo CD `AppProject` whitelists the allowed repo, namespaces, and resource kinds,
  so a compromised or mistaken manifest cannot deploy arbitrary cluster resources.

## Residual items to configure before production

- Replace all placeholder GUIDs / `REPLACE_WITH_*` values.
- Replace `https://github.com/your-org/...` repoURLs.
- Restrict `allow-https-egress` further if the app's destinations are known.
- Enable Azure Defender for Containers and Azure Policy for AKS (out of scope here).
