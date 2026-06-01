# iac-gke-poc

POC for the **iac-k8s cluster factory** (Milestone 1): build the smallest hardened, multi-AZ GKE cluster — COS nodes, multiple node pools incl. a Confidential pool — via Terraform driven by GitHub Actions (keyless WIF, PR → plan → approve → apply).

Design + decisions live in the research repo (`iac-k8s/`). See `implementation-plan.md` there.

## Layout
```
terraform/            # the cluster factory (POC)
  versions.tf         # providers + GCS backend
  providers.tf
  variables.tf
  network.tf          # VPC, subnet (secondary ranges), Cloud NAT
  kms.tf              # KMS key for GKE DB (secrets) encryption
  gke.tf              # regional cluster + 3 node pools (system, general, confidential)
  outputs.tf
  poc.tfvars          # POC values
.github/workflows/
  plan.yml            # PR: terraform plan, comment the diff
  apply.yml           # merge to main: terraform apply (gated by poc-apply environment)
  destroy.yml         # manual: terraform destroy (teardown)
reports/              # M2 conformance reports land here
```

## Flow (D8)
1. Open a PR changing `terraform/**` → `plan.yml` posts the plan.
2. Merge to `main` → `apply.yml` runs, **pauses for approval** on the `poc-apply` environment, then applies.
3. `destroy.yml` (manual dispatch) tears it down.

## Auth
Keyless via Workload Identity Federation — no service-account keys. Provider + CI SA are set in the workflow env.
