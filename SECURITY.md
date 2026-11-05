# Security review

Scope: all four repos plus the host bootstrap. Review date 26 Oct 2026.
Threat model: a single-box lab cloud with a few tenants who are not fully
trusted, operated through GitHub.

## Fixed

### This pass

| Area | Finding | Fix |
|---|---|---|
| Tenant pipeline | builder-admin's static password stored as a tenant repo secret; never rotated; carried `manager` | Repo gets a Keystone application credential instead: `member` + `load-balancer_member` only, rotated every 30 days, expires 7 days later. Minted by the tenant's own identity in `as-tenant/`. Password never leaves the platform pipeline |
| Tenant identity | One admin group per tenant; builder-admin in it | Three persona groups (admin / developer / viewer), roles on groups only. builder-admin is a *developer*: automation can't create users or grant roles. Validation forbids Keystone `admin` in any persona |
| Platform admin | Cloud `admin` added to every tenant group by default | Off by default (`add_platform_admin_to_tenant_groups`) |
| GitHub Actions | Actions pinned to movable tags | Pinned to commit SHAs (checkout v7.0.1, setup-terraform v4.0.1) |
| GitHub Actions | No `permissions:`, so `GITHUB_TOKEN` got the repo default | `contents: read` everywhere; only the module release job gets `contents: write` |
| GitHub Actions | Fork PRs would run on self-hosted runners next to credentials | Jobs skip PRs from forks |
| GitHub Actions | `actions/checkout` left the token in `.git/config` for later steps | `persist-credentials: false` |
| Platform runners | Pods could reach Backstage, its database and cluster internals; passwordless `sudo` in the runner image | NetworkPolicy: no ingress, egress only to DNS and outside the cluster. Pod Security `restricted`, `allowPrivilegeEscalation: false`, all capabilities dropped, no service-account token |
| Backstage | Any pod could reach Backstage and Postgres | Default-deny ingress; only Traefik → Backstage, only Backstage (+ replicas, CNPG operator) → Postgres. Pod Security `restricted`, hardened container |
| Jenkins module | Admin login hard-coded `admin`/`admin` | Removed; chart generates a random password into a secret |
| Shared security groups | `cib-ssh` open to `0.0.0.0/0` | RFC 1918 ranges only |
| Admin lookups | Sunbeam's admin project/user were looked up by name across all domains; a tenant admin creating a project or user called `admin` in their own domain would make the lookup ambiguous and break provisioning | Lookups pinned to Sunbeam's admin domain (`admin_domain`, configurable) |
| Host bootstrap | `install.sh` echoed the admin password; `admin_openrc`, `vault_keys` (unseal keys + root token) and the CA key created with default permissions | No echo; those files created mode 0600, `certs/` 0700 |

### Earlier passes (for completeness)

- **State:** world-readable state bucket replaced by private, versioned buckets with a public-access block. Each tenant's bucket is reachable by that tenant's project only.
- **S3 credentials:** EC2 credentials are now created for the right user (they were silently the cloud admin's).
- **Tenant roles:** tenants are no longer granted Keystone `admin`, which is cloud-wide and RGW-wide.
- **Runner separation:**
  - The platform runner serves only `cib-tenants`; each tenant runner serves only its own repo.
  - Runner VMs have no inbound access and the runner user has no sudo.
  - Registration tokens are short-lived and redacted after use.
- **ip-masq-agent** no longer runs privileged.
- **Secrets in files:** Backstage's GitHub App secret moved out of a committed YAML file into tfvars.

### Network layout (manifest install, RB4011 v4)

- **Isolation:** VM access (floating IPs, router gateways) is on its own NIC and VLAN, never the management network. `render_manifest.py` refuses overlapping networks, or a VM NIC with an IPv4 address; management IPv6 picked up from router adverts on it is a warning.
- **Router policy (mv-2112/HomeLab, `network/RB4011_v4`):** forwarding is default-drop between zones. Each cloud's networks reach only their own API range on 80/443 and the internet. The two clouds can't reach each other, and nothing in the lab can start a connection into HomeLAN. HomeLAN reaches everything in the clouds, as the internet would, plus the hosts and APIs. This replaces the old "LAN to LAN: allow all" rule, which let VMs reach the hosts' SSH, Juju and Ceph.
- **Management is single-stack** (IPv4 or IPv6): dual-stack management trips Juju bugs. The router no longer advertises IPv6 on VLAN 88.
- **Tenant IPv6 is ULA, routed inside the lab with no NAT:** VMs are reachable from HomeLAN by their own addresses, so security groups are what protect them. The shared groups have IPv6 rules: SSH from ULA only, web from anywhere, ICMPv6, which IPv6 needs to work. The internet sees the lab only through NAT66, outbound.
- **Management never reaches ens4f0:** its switch port is a tagged-only trunk (the cloud's external VLAN plus provider VLANs for provider networks and SR-IOV VFs), and VLAN 88 is only on the eno1 access ports.

## Recommended next (ranked)

1. **Protect the `production` environments** in `cib-tenants` and every tenant
   repo: required reviewers, deployments only from `main`. Store admin secrets as
   *environment* secrets, not repo secrets, and turn on branch protection.
   Until then, anyone with write access to `cib-tenants` can push a workflow
   change that runs with platform admin credentials.
2. **Narrow GitHub credentials.** `TENANTS_GH_TOKEN` (repo admin, secrets,
   variables) is the most powerful secret in the system. Replace it with a
   GitHub App installed only on `cib-tenants` and the tenant repos.
3. **Give the admin application credential an expiry and fewer roles.** Make
   `cib-tenants`'s credential expiring (`--expiration`), and avoid
   `--unrestricted` unless EC2 credential creation demands it. Rotate it like
   the tenant credentials.
4. **Encrypt Terraform state.** It holds passwords, application credential
   secrets and S3 keys. Bucket access is locked down, but OpenTofu's state
   encryption (or keeping the admin S3 keys very tightly held) is the next layer.
5. **Turn on Keystone `security_compliance`** if your Keystone charm exposes it:
   - force a password change at first use;
   - lockout after failed attempts;
   - minimum password length;
   - optionally TOTP for the admin persona.

   Until then, `initial_passwords` are permanent unless users change them.
6. **Pin the Backstage image by digest** (`image@sha256:...`; see the variable
   description) so a re-pushed tag can't change production. Its GitHub App has
   Administration read/write so the scaffolder can create repos, which makes
   it as powerful as an org admin over repositories: keep its client secret
   and key as tightly held as the platform credentials, and use
   `github-apps.py backstage --read-only` if scaffolding isn't needed.
7. **Replace self-signed TLS for Backstage** with a cert-manager CA issuer
   backed by your lab CA (or ACME). Users then aren't trained to click
   through certificate warnings.
8. **Use separate S3 keys per job.** The admin EC2 pair currently serves
   undercloud state, tenant provisioning state and every tenant bucket.
9. **Tenant runner VMs are long-lived:** a job can leave things behind for the
   next job in the same tenant. Move to ephemeral runners when tenants have
   several contributors.

## Accepted for a lab (revisit before anything shared)

- **Vault keys on the host.** Vault's unseal keys and root token live on the
  same host, because `post_reboot.sh` unseals from them.
- **Exposed cluster API.** Magnum clusters expose the Kubernetes API on a
  floating IP on the lab network (`master_lb_enabled`, `floating_ip_enabled`).
- **Unrestricted tenant credential.** The tenant pipeline credential is
  unrestricted so Magnum can create trusts. The role list still caps what it
  holds, but an unrestricted credential can mint further credentials or trusts
  of its own. Set `pipeline_unrestricted = false` for tenants that don't build
  clusters.
- **Tenant self-service user management.** The tenant admin persona's
  `manager` role lets it create users and grant roles in its domain. Check
  that your Keystone policies limit `manager` to its own domain
  before giving that persona to anyone untrusted.

## Not reviewed

- Sunbeam's own charms and their defaults.
- Upstream container images.
- The `legacy/` tree (not carried over).
- Chart internals beyond the values we set.
