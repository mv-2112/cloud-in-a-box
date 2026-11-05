# cib-tenants

Tenant provisioning as data. Each file in `tenants/` describes one tenant; a
GitHub Actions pipeline on a self-hosted runner turns it into:

- a Keystone **domain** and its **projects** (with quotas)
- a `builder-admin` user, admin group and inherited role assignments
- EC2/S3 credentials for that user (actually for that user, see below)
- a private, versioned **state bucket** that only that tenant's project can use
- Neutron RBAC entries sharing the chosen **undercloud security groups** into each project
- a **GitHub repo** created from `cib-tenant-template`, with the Actions
  variables/secrets its own pipeline needs already set

```
tenants/*.yaml             one file per tenant (the only thing most changes touch)
terraform/                 root module: reads tenants/, reads undercloud outputs
terraform/modules/tenant/  everything for one tenant
.github/workflows/         PR = plan, merge to main = apply
```

## Onboarding a tenant

1. Copy `tenants/spanglywires.ddns.net.yaml`, change `domain`, `owner`, projects.
2. Open a PR. The job summary shows the plan.
3. Merge. A `production` environment approval gate applies if you've configured one.
4. The tenant clones their new repo and pushes; their own pipeline builds
   network → cluster → addons using modules from `cib-terraform-modules`.

Offboarding: delete the file, PR, merge. Terraform will try to delete the
domain; it fails if resources are still in the projects, which is the safe outcome.
Tear down the tenant's own stacks first.

## Users and personas

Every tenant gets three **persona groups** in its domain, with roles granted to
the group (never to users) and inherited across all of the tenant's projects:

| Persona | Group | Keystone roles | Can |
|---|---|---|---|
| admin | `<domain>_admin` | `manager`, `member`, `load-balancer_member` | manage the tenant's users and role assignments, and everything below |
| developer | `<domain>_developer` | `member`, `load-balancer_member` | create and change servers, networks, volumes, clusters, load balancers, S3 |
| viewer | `<domain>_viewer` | `reader` | look, not touch |

Personas are defined once in `terraform/variables.tf` (`personas`). No persona
may hold Keystone `admin`, which validation enforces.

**People** are listed per tenant under `users:` in the YAML, each with one
persona. Without a `users:` block a tenant gets three generic users:
`tenant-admin`, `developer` and `viewer`. Each starts with a random password:

```bash
terraform -chdir=terraform output -json initial_passwords | jq '."<domain>"'
```

Hand these over out of band (never via the tenant repo). Terraform ignores
password changes afterwards, so users keep the password they set. To force a
change at first login, enable Keystone's `security_compliance` options (see
SECURITY.md). Set `enabled: false` to lock someone out; remove them to delete.

**builder-admin** is the tenant's automation identity, not a person. It is a
*developer*, so automation can't create users or grant roles. Its password
never leaves the platform pipeline. The tenant repo instead gets an
**application credential** minted from it by the as-tenant stage:
- **Roles:** `member` + `load-balancer_member`.
- **Rotation:** every 30 days, valid for 7 more after rotation.
- **When it happens:** the provisioning workflow runs weekly, so rotation happens even without commits.

The credential is *unrestricted* because Magnum needs to create a Keystone
trust when it builds a cluster. Set `pipeline_unrestricted = false` in
`as-tenant/` for tenants that never build clusters.

## Runners

There are two kinds, and they never share work:

| | Platform runners | Tenant runner |
|---|---|---|
| Where | pods on the admin cluster (ARC), built by `cib-undercloud/platform` | a VM in the tenant's builder project, built by `as-tenant/` here |
| Serves | this repo only | that tenant's repo only |
| Labels | `self-hosted, cib` | `self-hosted, cib-tenant` |
| Credentials in jobs | platform admin (app credential, admin S3 keys) | the tenant's builder-admin only |
| Lifetime | ephemeral pod per job | long-lived VM |

Keystone, Magnum and RGW are on the lab network, so GitHub-hosted runners
can't reach either.

**Tenant runners** are opt-in per tenant (`runner.enabled` in the YAML, needs
`github.enabled`). After the main apply, `as-tenant/apply-all.sh` applies
`as-tenant/` once per tenant, logged in as **that tenant's** builder-admin, so
the VM is created in the tenant's project, against its quota, on its own
network and router (separate from anything the tenant's pipeline manages, so
it can't remove the network it runs on). It registers to the tenant repo with
a token from the GitHub provider. State is in the platform bucket under
`as-tenant/<domain>.tfstate`, out of the tenant's reach.

Turning a runner off: set `runner.enabled: false` and merge; the next run
destroys it. Offboarding a tenant: do that first, then remove the tenant file,
because the runner can only be destroyed while the tenant's credentials exist.

The runner VM itself holds no cloud credentials; jobs get them from the
tenant repo's secrets. If a tenant deletes its runner VM, the next
provisioning run recreates it.

## State buckets

One bucket per tenant, `<domain-with-dashes>-tfstate`, created by this
pipeline with the `state-bucket` module:

- **Owned by the platform admin project.** The tenant can't delete it, change
  its policy, make it public or switch off versioning.
- **Bucket policy grants only the tenant's primary project** object
  read/write (RGW maps Keystone projects to S3 principals). Nothing else is
  granted, so tenants can't see each other's state.
- **Versioned**, with old versions expired after 90 days, and a public-access block.

Two things keep this honest:

- The `developer` persona (builder-admin's) must include `member` (Sunbeam's
  RGW only accepts `Member`/`member`), and no persona may include `admin`:
  RGW treats Keystone `admin` as an RGW admin with access to every bucket.
  Both are enforced by validation.
- The admin EC2 keys in this repo's secrets own every bucket. Treat them like root.

Because tenant repos run arbitrary workflow code on the same runner, a runner
group per tenant (or ephemeral runners) is the step up when tenants aren't all you.

## Changes from start_here/

| Old | New |
|---|---|
| `var.sites` map in `variables.tf` | `tenants/*.yaml`, one file per tenant |
| `local_sensitive_file` rc/aws files under `../sites/` | Actions secrets/variables in the tenant repo |
| EC2 credential without `user_id` (created for cloud admin) | `user_id = builder-admin` |
| tenant group granted `admin` | three persona groups (admin / developer / viewer), never Keystone `admin` |
| builder-admin password in the tenant repo | expiring, role-limited, rotated application credential |
| internal Keystone endpoint in tenant openrc | public endpoint |
| starter repo built file-by-file with `github_repository_file` | GitHub template repo |
| `<site>-bucket-1` with `.r:-user` ACL (a referrer *deny*, not a user grant) | admin-owned `<domain>-tfstate`, bucket policy grants only the tenant's project |
