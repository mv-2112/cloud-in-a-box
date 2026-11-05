# cloud-in-a-box: split into four repos

```
cib-undercloud          admin domain: host bootstrap, images, Magnum templates,
                        volume types, core security groups, state buckets
cib-terraform-modules   versioned module monorepo (tenant-network, k8s-cluster,
                        platform-addons + the existing addons)
cib-tenant-template     GitHub template repo every tenant repo is created from
cib-tenants             tenants/*.yaml + pipeline on a self-hosted runner that
                        creates domains, users, SG sharing and the tenant repo
```

Dependency direction is one-way:

```
undercloud  ──(names: templates, images, SGs)──▶  modules  ──▶  tenant repos
     │                                                              ▲
     └──(remote state: SG IDs)──▶  cib-tenants  ──(creates + wires)─┘
```

## Where everything in the old repo went

| Old path | New home |
|---|---|
| `install.sh`, `uninstall.sh` (merged), `fixups/`, `utils/`, `keep/` | `cib-undercloud/bootstrap/` |
| `start_here/images.tf`, `k8s_templates.tf`, `volume_types.tf` | `cib-undercloud/terraform/` |
| `start_here/buckets.tf` (`terraform` bucket) | `cib-undercloud/terraform/state_buckets.tf` (private, versioned) |
| `start_here/buckets.tf` (`<site>-bucket-1`) | per-tenant bucket from `cib-tenants` (policy-scoped to that tenant) |
| *(new)* core security groups | `cib-undercloud/terraform/security_groups.tf` |
| `start_here/modules/terraform-module-*` | `cib-terraform-modules/modules/*` |
| `terraform-module-builder-infra` | split: `tenant-network` + `k8s-cluster` + `platform-addons` |
| `start_here/github_module_upload.tf` | gone: modules are tagged in one repo |
| `start_here/templates/*`, `github_site_upload.tf` | `cib-tenant-template` |
| `start_here/projects.tf`, `iam.tf`, `local_files.tf`, `var.sites` | `cib-tenants` |
| `legacy/`, `wip/`, `app-demo/`, `documentation/` | leave in the old repo (archive it) |

## Bringing it up from scratch

Nothing from `start_here/` is deployed, so there's no state to move; build
in dependency order:

1. **Modules** – run `./set-org.py <org>`, then push `cib-terraform-modules` and tag `v1.1.1`.
2. **Repos** – push `cib-tenant-template` (mark it a template repository) and
   `cib-tenants`; the platform runners register to the latter.
3. **Undercloud stage 1** – `bootstrap/install.sh` (manifest install from
   `site.env`; see `bootstrap/README.md`), then `terraform/` as the Sunbeam
   admin: external network, flavors, images, templates, volume types, core
   security groups, state buckets and the admin cluster `cib-platform`.
4. **Undercloud stage 2** – `platform/`: StorageClasses, cert-manager,
   Traefik, CloudNativePG, the platform runners (ARC) and Backstage.
5. **Tenants** – set `cib-tenants` secrets/variables, add a `tenants/*.yaml`,
   merge. Runs on the platform runners; creates the domain, user, state
   bucket, tenant repo and the tenant's own runner VM.
6. **Tenant workloads** – push to the tenant repo; runs on the tenant runner.

Archive the old repo once this works; `legacy/`, `wip/`, `app-demo/` and
`documentation/` stay there for reference.

## Problems in the old code fixed along the way

- **Public state bucket**: `terraform` container had `.r:*,.rlistings`. State
  holds passwords and EC2 secrets.
- **EC2 credentials for the wrong user**: no `user_id`, so the "builder-admin"
  S3 keys were the cloud admin's.
- **Tenants granted `admin`**: on Keystone without enforced scope that's cloud-wide admin.
- **Swift ACL**: `.r:-user` is a referrer deny rule, not "grant this user read".
- **Backend mismatch**: `backend.tftpl` pointed at bucket `tf-store`, which
  nothing created.
- **Internal Keystone URL** in tenant rc files.
- **Provider blocks inside `builder-infra`**: stopped it being used with
  `count`/`depends_on` and configured helm against a cluster created in the
  same run. Now two stages.
- **Helm provider 2.x syntax**: cert-manager/trust-manager `set {}` blocks and
  the provider `kubernetes {}` block migrated to helm provider 3.x; Harness
  delegate module bumped to 0.3.0 (0.2.3 pinned helm `< 3.0`).
- **State bucket access**: per-tenant buckets owned by the platform, with a
  bucket policy for that tenant's project only, versioning, public-access block.
- `terraform fmt` drift in harness, jaeger, storage-classes (the old per-module
  CI would have failed on these).
- **Deprecated Kubernetes resources**: `kubernetes_daemonset` and
  `kubernetes_storage_class` replaced with `_v1` types; kubernetes provider
  now `>= 3.0`.
- **ip-masq-agent ran privileged**: now unprivileged with just
  `NET_ADMIN`/`NET_RAW`, as upstream ships it.
- **`multiattach` was the default StorageClass**: default is now `standard`.

## Not verified here

HCL syntax and formatting were checked with HashiCorp's `hclfmt`. `terraform
init/validate/plan` could not be run (no registry access from the build
environment, and no OpenStack to plan against). Run `terraform validate` in
each root before the first apply.
