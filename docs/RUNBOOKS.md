# Operational Runbooks

Procedures for monitoring, troubleshooting, and recovery.

---

## 1. Monitoring application health

```bash
# Pod & workload status
kubectl -n sample-app get pods -o wide
kubectl -n sample-app get deploy,hpa,pdb

# Is the HPA scaling as expected?
kubectl -n sample-app describe hpa sample-web-app

# Live resource usage (requires metrics-server, bundled with AKS)
kubectl -n sample-app top pods

# Argo CD view of health & sync
kubectl -n argocd get applications
argocd app get sample-web-app-dev
```

Healthy signals: all pods `Running` & `Ready`, Deployment `Available`, Argo CD
Application `Synced` + `Healthy`.

---

## 2. Troubleshooting a failed deployment

### Step 1 — identify the failing object
```bash
kubectl -n sample-app get pods
kubectl -n argocd get application sample-web-app-dev -o jsonpath='{.status.conditions}'
```

### Step 2 — inspect events (most issues show here)
```bash
kubectl -n sample-app get events --sort-by=.lastTimestamp | tail -n 30
kubectl -n sample-app describe pod <pod>
```

### Step 3 — common causes

| Symptom | Likely cause | Action |
|---------|--------------|--------|
| `ImagePullBackOff` | bad tag / no ACR pull rights | fix `image.tag`; grant AcrPull to kubelet identity |
| `CrashLoopBackOff` | app error / failing startup probe | `kubectl logs --previous`; check probe paths |
| `Pending` | insufficient resources / quota | check `ResourceQuota`, node autoscaler, `describe pod` |
| `CreateContainerConfigError` | missing secret/configmap | verify SecretProviderClass + ConfigMap exist |
| Readiness failing | probe path/port wrong | confirm `containerPort` 8080 & probe path |
| Blocked traffic | NetworkPolicy default-deny | confirm an explicit allow policy covers the flow |

### Step 4 — logs
```bash
kubectl -n sample-app logs deploy/sample-web-app --tail=100
kubectl -n sample-app logs <pod> --previous   # last crashed container
```

---

## 3. Inspecting Kubernetes events cluster-wide

```bash
kubectl get events -A --sort-by=.lastTimestamp | tail -n 50
# Warnings only
kubectl get events -A --field-selector type=Warning
```

---

## 4. Argo CD: out-of-sync / failed sync

```bash
argocd app get <app>                 # status + conditions
argocd app diff <app>                # what differs from Git
argocd app sync <app>                # force a sync
argocd app sync <app> --prune        # also remove orphaned resources
```

If a sync hangs, check the resource hooks and the `retry` backoff. Inspect the
repo-server logs: `kubectl -n argocd logs deploy/argocd-repo-server`.

---

## 5. Rollback

**Preferred (Git):**
```bash
git revert <bad-commit> && git push     # Argo CD reconciles to prior state
```

**Emergency (Argo CD history):**
```bash
argocd app history <app>
argocd app rollback <app> <REVISION_ID>
```
Then reconcile Git to match so it remains the source of truth.

---

## 6. Configuration drift recovery (Kubernetes)

Someone changed a live resource by hand:

```bash
argocd app diff sample-web-app-dev      # see the drift
```
- With `selfHeal: true` (dev), Argo CD reverts automatically.
- For manual-sync apps (prod): `argocd app sync sample-web-app-prod` to restore.

To temporarily pause self-heal during an incident:
```bash
argocd app set <app> --sync-policy none
# ... investigate ...
argocd app set <app> --sync-policy automated --self-heal
```

---

## 7. Infrastructure drift recovery (Terraform)

Someone changed Azure resources outside Terraform:

```bash
cd terraform/environments/<env>
terraform plan            # shows drift as proposed changes
```
Options:
- **Revert to code**: `terraform apply` to restore the declared state.
- **Adopt the change**: update the `.tf`/tfvars to match, then `plan` clean.
- **Import** an out-of-band resource: `terraform import <addr> <azure-id>`.

If state is corrupted or lost:
- State is versioned in the storage account — restore a prior blob version.
- Blob leases provide locking; a stale lock can be broken via
  `terraform force-unlock <LOCK_ID>` (only when certain no apply is running).

---

## 8. Cluster access recovery

Lost kubeconfig or Azure AD change:
```bash
az aks get-credentials -g aksplat-<env>-rg -n aksplat-<env>-aks --overwrite-existing
kubectl get nodes
```
If RBAC locks you out, a member of the `admin_group_object_ids` Azure AD group
must grant access (local accounts are disabled by design).

---

## 9. Node pressure / scaling

```bash
kubectl top nodes
kubectl get nodes
kubectl describe node <node> | grep -A5 Allocated
```
The autoscaler adjusts node counts within the min/max in the env tfvars. To
change capacity, edit `*_node_min_count` / `*_node_max_count` and `terraform apply`.
