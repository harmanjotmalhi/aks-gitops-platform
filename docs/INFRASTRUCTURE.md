# Infrastructure Lifecycle

How Terraform is structured, consumed, and operated across its lifecycle.

## Module reference

### `modules/networking`
| Input | Description | Default |
|-------|-------------|---------|
| `name_prefix` | Prefix for resource names | — |
| `location` | Azure region | — |
| `resource_group_name` | Target RG | — |
| `vnet_address_space` | VNet CIDRs | `["10.20.0.0/16"]` |
| `aks_subnet_prefixes` | AKS subnet CIDRs | `["10.20.1.0/24"]` |
| `ingress_subnet_prefixes` | Ingress subnet CIDRs | `["10.20.2.0/24"]` |

Outputs: `vnet_id`, `vnet_name`, `aks_subnet_id`, `ingress_subnet_id`.

### `modules/aks`
Key inputs: `kubernetes_version`, `aks_subnet_id`, node pool sizing
(`system_*`, `user_*`), `network_policy`, `admin_group_object_ids`.
Outputs: `cluster_id`, `cluster_name`, `oidc_issuer_url`,
`kubelet_identity_object_id`, `node_resource_group`, `kube_config_raw` (sensitive).

Design choices:
- `local_account_disabled = true` forces all access through Azure AD.
- `only_critical_addons_enabled` keeps the system pool for platform components.
- `lifecycle.ignore_changes` on node counts prevents Terraform fighting the autoscaler.

## Remote state

- Backend: `azurerm`, one container per environment.
- **Locking**: Azure blob leases prevent concurrent applies.
- **Versioning + soft delete**: enabled on the storage account for recovery.
- The `bootstrap` config uses local state because it creates the backend itself.

## Standard lifecycle commands

```bash
cd terraform/environments/<env>
terraform init        # first time / after backend change
terraform plan        # preview
terraform apply       # provision/update
terraform output      # read outputs (cluster name, etc.)
terraform destroy     # teardown (dev only; prod RG is deletion-protected)
```

## Making infrastructure changes

1. Branch and edit module or environment code.
2. Open a PR → `terraform-ci` runs `fmt -check`, `validate`, and `plan` for
   dev and prod, posting the plan as a PR comment.
3. Review the plan diff in the PR.
4. Merge. Apply is intentionally **not** automated — run `terraform apply`
   from a controlled context (local with MFA, or a protected CD job).

## Upgrades

- **Kubernetes version**: bump `kubernetes_version` in the env tfvars; plan shows
  a control-plane upgrade, then node pools roll with `max_surge = 33%`.
- **Node VM size**: changing `*_vm_size` replaces the node pool — drain impact is
  mitigated by the autoscaler + PodDisruptionBudgets on workloads.

## Drift between Terraform and Azure

Run `terraform plan` to detect drift. If a change was made manually in the
portal, either import it, revert it, or codify it. See
[RUNBOOKS.md](RUNBOOKS.md#infrastructure-drift-recovery).

## Cost notes

Dev is sized small (1–2 system + 1–3 app nodes on D2s_v5). Prod is sized for
availability (3–5 + 3–10 on D4s_v5). For projected costs, use the
[Azure Pricing Calculator](https://azure.microsoft.com/pricing/calculator/)
with your region and node counts.
