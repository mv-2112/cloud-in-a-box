# Tenant starter (GitHub template repository)

Every tenant repo is created from this one by `cib-tenants` (GitHub's
"template repository" feature), replacing the old per-file
`github_repository_file` pushes from `start_here/github_site_upload.tf`.

When a repo is created, the provisioner also writes these into it, so the
pipeline works on the first push:

| Kind | Name | Value |
|---|---|---|
| variable | `TENANT_DOMAIN` | Keystone domain, e.g. `spanglywires.ddns.net` |
| variable | `OS_AUTH_URL` | Keystone public endpoint |
| variable | `TF_STATE_BUCKET`, `S3_ENDPOINT` | the tenant's state bucket: platform-owned, only this tenant's project can read/write objects |
| secret | `OS_APPLICATION_CREDENTIAL_ID`, `OS_APPLICATION_CREDENTIAL_SECRET` | pipeline credential: roles `member` + `load-balancer_member` only, rotated every 30 days, expires 7 days after rotation |
| secret | `S3_ACCESS_KEY`, `S3_SECRET_KEY` | EC2 credentials **for builder-admin** |

## Runner

Jobs run on `[self-hosted, cib-tenant]`: this tenant's own runner VM, in its
builder project and registered only to this repo. cib-tenants creates it when
the tenant's YAML has `runner.enabled: true`. Jobs queue until it's online
(a few minutes after provisioning).

## Layout

```
infra/      network + Magnum cluster   (state key infra/terraform.tfstate)
platform/   helm/k8s addons            (state key platform/terraform.tfstate)
```

Edit `platform/main.tf` to switch addons on, commit, and the pipeline does the rest.
PRs get a plan; merges to `main` apply (gated by the `production` environment).

## One-time setup when pushing this template

1. Run `./set-org.py <org>` at the top level (sets the module `source` URLs).
2. In GitHub: Settings → General → tick **Template repository**.
3. Create a `production` environment with required reviewers if you want an approval gate.

## Running locally

```bash
source ./tenant_openrc     # or export the OS_* vars by hand
export AWS_ACCESS_KEY_ID=... AWS_SECRET_ACCESS_KEY=...
cd infra
terraform init -backend-config="bucket=<TF_STATE_BUCKET>" -backend-config='endpoints={s3="<S3_ENDPOINT>"}'
terraform apply -var domain=<TENANT_DOMAIN>
```
