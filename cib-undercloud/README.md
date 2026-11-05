# cib-undercloud

The platform layer of cloud-in-a-box. Everything here runs as the Sunbeam
`admin` user in `admin_domain` and produces things *every* tenant consumes.
Nothing tenant-specific lives here.

```
bootstrap/     Host install from a manifest (site.env → manifest.yaml): Sunbeam, Vault, TLS,
               Octavia, CaaS. See bootstrap/README.md (router: mv-2112/HomeLab RB4011_v4)
tools/         ipv6-routes.py: RB4011 routes for tenant IPv6 networks, per cloud
               github-apps.py: creates the platform's GitHub Apps, credentials -> Terraform
terraform/     Shared OpenStack objects, applied with admin credentials
```

## What it owns

| Object | File | Consumed by |
|---|---|---|
| External network `external-network`, dual-stack (VM NIC/VLAN, from `bootstrap/site.env`) | `network.tf` | every tenant router and floating IP |
| IPv6 address scope + tenant pool `cib-tenant-v6` (routed ULA /64 per tenant network) | `network.tf` | `tenant-network`, `gh-runner-vm` modules |
| Flavors `m1.tiny`…`m1.large` | `flavors.tf` | everyone |
| Base + Magnum CAPI images | `images.tf` | modules (`k8s-cluster`), tenants' own code |
| Magnum cluster templates (`generic-k8s-<ver>-template`) | `cluster_templates.tf` | `k8s-cluster` module, by name |
| Volume types | `volume_types.tf` | everyone |
| Core security groups (`cib-ssh`, `cib-web`, ...) | `security_groups.tf` | shared into tenant projects via Neutron RBAC by cib-tenants |
| Private state buckets (`state-bucket` module, S3 API) | `state_buckets.tf` | this repo, cib-tenants |
| Admin Magnum cluster `cib-platform` (stage 2 fills it) | `admin_cluster.tf` | platform runners, Backstage |

It does **not** create domains, projects, users or GitHub repos; that moved to
`cib-tenants`. It no longer pushes module code to GitHub either; modules live in
`cib-terraform-modules` and are versioned with git tags.

## Contract with the other repos

Downstream code finds platform objects **by name**, so these names are the API:

- Cluster templates: `generic-k8s-<version>-template`
- CAPI images: `coe-capi-<version>`
- Shared security groups: `cib-<name>`
- External network: `var.external_network` (default `external-network`)

`cib-tenants` additionally reads `terraform output` via `terraform_remote_state`
to get security group IDs for RBAC sharing.

## Usage

```bash
# 1. Host (once): see bootstrap/README.md
cd bootstrap && cp site.env.example site.env && $EDITOR site.env
./install.sh --check && ./install.sh

# 2. Platform objects. In every new shell, first:
source env.sh                               # admin_openrc + CA bundle + S3 keys + TF_VARs, then checks S3
#   It reuses the admin project's EC2 key (creating one only if none exists),
#   builds a CA bundle of Sunbeam's CA plus system CAs (so image downloads from
#   the internet verify), and ignores ~/.aws (stray keys there are rejected by
#   RGW as InvalidAccessKeyId). Pass another openrc path as an argument if needed.

cd terraform
terraform init && terraform apply           # first run uses local state
cp backend.tf.example backend.tf            # then move state into RGW
terraform init -migrate-state -backend-config="endpoints={s3=\"$TF_VAR_s3_endpoint\"}"
# answer "yes" to copy the local state; S3 keys and CA come from env.sh
```

Every later `terraform init` here needs the same `-backend-config`; plan and
apply just need `source env.sh` in the shell.

Adding a Kubernetes version = add an entry to `k8s_templates` and apply.
Templates default to Octavia's **amphora** provider (`octavia_provider`):
a small VM per load balancer, with source ranges, TLS/L7 and health
monitors. `ovn` is lighter but lacks those, and on this Sunbeam its Service
load balancers weren't reachable through their floating IPs.

Magnum won't change a template a cluster is using, so changing an existing
template means rebuilding its clusters: `terraform destroy` in `platform/`
first (so Services' load balancers go before the cluster), then
`terraform destroy -target='module.admin_cluster[0]'` and `terraform apply` here.
Keep old versions until no tenant cluster uses them (Magnum won't delete a
template that is in use).

## Admin cluster, platform runners and Backstage

The undercloud has two stages, for the same reason the tenant template does
(Terraform can't configure Helm against a cluster it creates in the same run):

```
terraform/   stage 1  images, templates, volume types, SGs, state buckets,
                      and the admin Magnum cluster "cib-platform"
platform/    stage 2  into that cluster: Cinder StorageClasses, cert-manager,
                      Traefik (Octavia LB), CloudNativePG, platform runners, Backstage
```

**Platform runners** use GitHub's actions-runner-controller (runner scale
sets). They are registered only to `cib-tenants`, the one repo whose jobs
carry admin credentials, with labels `self-hosted, cib`. Pods are ephemeral
(one job each, nothing left behind), scale 0–3, trust the Sunbeam CA through
`OS_CACERT`/`AWS_CA_BUNDLE`, and have no Kubernetes permissions. Tenant repos
never run here; each tenant has its own runner VM (see cib-tenants).

**Backstage** runs your `verranm/backstage` image from
[Backstage-Testbed](https://github.com/mv-2112/Backstage-Testbed) with a
CloudNativePG database, behind Traefik with a cert-manager certificate. Compared
with the testbed manifests:

- the database is created with `CREATEDB` for the app user, so no `kubectl exec`
- the GitHub App secret is created by Terraform from tfvars, not a committed YAML
- a standard `Ingress` is used rather than Traefik CRDs; HTTP→HTTPS is a Traefik entrypoint redirect
- the hostname is set with `APP_CONFIG_app_baseUrl` / `APP_CONFIG_backend_baseUrl` /
  `APP_CONFIG_backend_cors_origin`, so it isn't locked to the hostname baked into the image

Backstage is platform-only: it isn't in cib-terraform-modules, the tenant
template or cib-tenants.

### Bring-up

```bash
# Same shell as Usage above: admin_openrc sourced, AWS_CA_BUNDLE=$OS_CACERT and
# TF_VAR_cloud_ca_cert_pem exported (the CA reaches the runners through it)

# Stage 1 (see Usage above): cluster included
cd terraform && terraform apply

# Stage 2
cd ../platform
cp terraform.tfvars.example terraform.tfvars   # org, runner repo (Backstage's name is automatic)
../tools/github-apps.py runners                 # two clicks on GitHub each; writes
../tools/github-apps.py backstage               #   github-apps.auto.tfvars.json
../tools/admin-kubeconfig.sh                   # on the Sunbeam host: the admin cluster's
                                               #   kubeconfig -> ~/.kube/cib-platform.yaml,
                                               #   then switches off the cluster's MetalLB
terraform init -backend-config='endpoints={s3="'"$TF_VAR_s3_endpoint"'"}'
terraform apply
terraform output ingress_ip dns_records       # = PLATFORM_INGRESS_IP, and the names for the router's DNS
```

**Names.** The admin cluster's ingress (Traefik) has a fixed address,
`PLATFORM_INGRESS_IP` in `bootstrap/site.env`: stage 1 reserves it as a
floating IP outside the pool, and the platform stage gives it to Traefik, so
it survives load balancer and cluster rebuilds. Platform services are named
`<service>.<cloud_name>.lab.home.arpa` (Backstage:
`backstage.mz640test.lab.home.arpa`) in the router's DNS (HomeLab
`RB4011_v4/src/lablan/34-dns.rsc`), so any HomeLAN machine reaches them with no
hosts-file edits. `terraform output backstage_github_callback_url` is the URL
the Backstage GitHub App must have.

**GitHub Apps** come from `tools/github-apps.py`, not by hand. GitHub has no
API that creates an app outright, so it uses GitHub's app manifest flow: the
script generates each app's definition, opens GitHub with it pre-filled, and
you click **Create GitHub App** and then **Install**. It collects the app ID,
private key and client secret, finds and checks the installation, and writes
`platform/github-apps.auto.tfvars.json` (mode 600, git-ignored), which
Terraform reads automatically. Run it on a machine with a browser.

| App | Install on | Permissions | Writes |
|---|---|---|---|
| `runners` | `cib-tenants` only (choose *Only select repositories*; the script refuses an install that can't see it, and warns if it sees more) | Administration: read/write, Actions: read, Metadata: read | `platform_runner_github_app` |
| `backstage` | your org | Administration, Contents, Workflows, Pull requests: read/write (the scaffolder creates repos); Metadata, Members: read. `--read-only` drops the write permissions | `backstage_github_app` |

**Apps made by hand** (see `platform/terraform.tfvars.example`) need three
values, and GitHub doesn't make them obvious:

- **App ID:** the number on the app's General page, *not* the Client ID
  (`Iv23...`) just below it. GitHub suggests the Client ID works instead; the
  runners' controller (ARC) still only accepts the number.
- **Installation ID:** not shown on any GitHub page. Install the app first
  (app page → **Install App**; runners: only `cib-tenants`), then open
  `github.com/organizations/<org>/settings/installations`, click **Configure**
  next to the app, and take the number at the end of the URL
  (`.../settings/installations/178914053`).
- **Private key:** **Generate a private key** at the bottom of the General
  page downloads a `.pem`; GitHub keeps only its fingerprint.

Backstage's sign-in callback is `https://<hostname>/api/auth/github/handler/frame`;
`terraform output backstage_github_callback_url` (in `platform/`) prints it. If you close the browser
before installing, the script keeps the new app's private key (GitHub shows
it only once) and `--resume` finishes the job. To rotate an app's key, delete
the app on GitHub and run the script again.

Check the runners: `kubectl get pods -n arc-system` should show the
controller and a `cib-platform-...-listener` pod. Runner pods only appear in
`arc-runners` while a job runs (min 0). In GitHub, the repo's Settings →
Actions → Runners lists the `cib-platform` scale set.

Things to verify on first build (couldn't be tested here):

- **CSI:** the StorageClasses assume Cinder CSI is in the Magnum cluster. If
  `kubectl get csidriver` doesn't list `cinder.csi.openstack.org`, the database
  PVC will stay Pending.
- **Default StorageClass:** if the cluster already has one, set
  `default_storage_class = null` in `platform/main.tf` to avoid two defaults.
- **Kubeconfig:** stage 2 uses `~/.kube/cib-platform.yaml` from
  `tools/admin-kubeconfig.sh`, not Magnum's kubeconfig: Magnum's client
  certificate is signed by Magnum's CA, which Sunbeam's Cluster API clusters
  don't trust ("the server has asked for the client to provide
  credentials"). The script reads Cluster API's own kubeconfig secret from
  Sunbeam's Kubernetes, so it runs on the Sunbeam host.
- **Health probes:** they use the new backend's `/.backstage/health/v1/*`
  endpoints; if your image predates them, change the probe paths.
