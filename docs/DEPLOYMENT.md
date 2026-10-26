# Deployment Workflow

All application and configuration changes flow through Git. Argo CD reconciles
the cluster to match the committed state.

## The GitOps loop

```
edit values / manifests → PR → CI lint/validate → merge to main → Argo CD syncs
```

Nobody runs `kubectl apply` or `helm upgrade` by hand against the cluster for
managed workloads. The desired state lives in `helm/` and `k8s/`.

## Deploying an application change (dev)

1. Edit `helm/sample-web-app/values-dev.yaml` (e.g. bump `image.tag` or replicas).
2. Open a PR. `helm-ci` lints and renders the chart; `manifests-ci` validates.
3. Merge to `main`.
4. `sample-web-app-dev` has `automated: { prune, selfHeal }`, so Argo CD syncs
   within the reconciliation interval (~3 min) or immediately if a webhook is set.
5. Watch it:
   ```bash
   kubectl -n argocd get application sample-web-app-dev
   kubectl -n sample-app rollout status deploy/sample-web-app
   ```

## Promoting to prod (gated)

The prod Application uses **manual sync**. After the dev change is validated:

1. Update `values-prod.yaml` (typically the image tag) via PR and merge.
2. Argo CD marks `sample-web-app-prod` as **OutOfSync** but does not apply.
3. A human promotes:
   ```bash
   argocd app diff sample-web-app-prod      # review exactly what will change
   argocd app sync sample-web-app-prod      # apply
   ```

## Drift detection & self-healing

- **Drift detection**: Argo CD continuously compares live state to Git and marks
  Applications `OutOfSync` when they differ.
- **Self-heal**: with `selfHeal: true`, unauthorized live changes (e.g. someone
  runs `kubectl scale`) are automatically reverted to the Git-declared state.
- **Prune**: resources removed from Git are deleted from the cluster.

## Rollbacks

Two complementary mechanisms:

1. **Git revert (preferred, auditable)**:
   ```bash
   git revert <bad-commit>
   git push
   ```
   Argo CD syncs the cluster back to the previous good state.

2. **Argo CD history rollback (fast, emergency)**:
   ```bash
   argocd app history sample-web-app-prod
   argocd app rollback sample-web-app-prod <REVISION_ID>
   ```
   `revisionHistoryLimit` (10 dev / 15 prod) controls how far back you can roll.
   Follow up with a Git revert so Git remains the source of truth.

## Verifying a deployment

```bash
kubectl -n sample-app get pods,svc,hpa
kubectl -n sample-app logs deploy/sample-web-app
kubectl -n sample-app port-forward svc/sample-web-app 8080:80
curl http://localhost:8080
```

See [RUNBOOKS.md](RUNBOOKS.md) for failure scenarios.
