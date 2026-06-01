# M2 Conformance Report — POC

Deploy the workload-hardening guardrails via **ArgoCD (D10)** onto the M1 cluster and measure posture.

## Result summary

| Check | Outcome |
|---|---|
| Guardrails delivered by ArgoCD | **Synced / Healthy** — "successfully synced (all tasks run)" |
| Kyverno ClusterPolicies present | **10 / 10** (PSS baseline + Kyverno restricted set from k8s-hardening Tier-1) |
| Pod Security Standards | `restricted` enforced on `default` (baseline on `kube-system`) |
| **Behavioral: privileged pod** | **REJECTED** — blocked on 5 grounds (privileged, allowPrivilegeEscalation, capabilities, runAsNonRoot, seccompProfile) |
| **Drift self-heal** | Deleted `disallow-privileged-containers` ClusterPolicy → **ArgoCD restored it** automatically |
| kubescape compliance (whole-cluster) | baseline **85** → post **82** — see caveat below |

**Verdict:** the hardening guardrails are **live and enforcing**, delivered and self-healing via GitOps (ArgoCD). M2 objectives met.

## The kubescape score caveat (important)

The whole-cluster aggregate went **down** (85 → 82), which is a **measurement artifact, not a regression**:

- The **baseline** scan ran on a near-empty cluster (only GKE system pods).
- The **post** scan also includes the **ArgoCD + Kyverno workloads we deployed** to *do* the hardening. Those tools are not themselves hardened to `restricted` (and are deliberately policy-excluded), so they add new control failures that lower the *aggregate*.
- Our guardrails provably enforce on actual workloads (the privileged pod was rejected) — the aggregate number just isn't a clean before/after when unhardened tooling is added between scans.

This matches the [k8s-hardening](https://github.com/AI-Fabrik/k8s-hardening) guidance: on managed GKE the meaningful signal is **workload posture** (which we proved behaviorally), not a single aggregate score.

**Better metric for the real build:** scan a fixed *workload* namespace before/after (excluding platform tooling), or diff only the controls the guardrails target. Captured as a POC learning.

## Artifacts
- `reports/baseline/kubescape.json` — pre-hardening scan
- `reports/post/kubescape.json` — post-hardening scan

## Environment
- Cluster `poc` (regional us-central1), GKE Standard, COS nodes, hardened per D2/D7.
- Guardrails: vendored k8s-hardening Tier-1 (PSS, default-deny NetworkPolicy, RBAC, SA-automount-off) + 10 Kyverno policies, with `argocd`/`kyverno`/`kube-system` excluded.
- Delivery: ArgoCD `guardrails` Application, `automated` sync with `selfHeal: true, prune: true`.
