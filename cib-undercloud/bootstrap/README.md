# Bootstrap: single-node Sunbeam from a manifest

`install.sh` installs Sunbeam with no prompts. Every answer comes from
`site.env`, which `render_manifest.py` checks against the host and turns into
Sunbeam's `manifest.yaml`. The same values are written to
`../terraform/site.auto.tfvars.json`, so Sunbeam and the undercloud Terraform
always agree.

```bash
cp site.env.example site.env    # mz640test values; edit CEPH_DISKS (and the mz640: lines for mz640)
./utils/ceph-disks.py                 # candidate Ceph disks, and a CEPH_DISKS= line to paste
sudo ./utils/ceph-disks.py --zap /dev/disk/by-id/...   # only for disks that still hold old data
./install.sh --check            # validate against this host, change nothing
./install.sh                    # install
```

`utils/ceph-disks.py` only offers whole disks with nothing in use on them: never
the system disk, anything mounted or swapped (also through LVM, RAID or
LUKS), read-only or removable disks. `--zap` refuses anything else, asks
before wiping (`--yes` skips that), and won't touch a disk holding a Ceph OSD
without `--force-bluestore`. It replaces `fixups/nuke_disk.sh`, which zapped a
fixed `sda`-`sdd` and could hit the system disk.

## Starting again

`./uninstall.sh` removes a Sunbeam install (finished or half-finished) so
`./install.sh` can start clean. It asks first (`--yes` skips the question).
It zaps disks holding a Ceph OSD unless you pass `--keep-disks`, and moves
the old `admin_openrc`, `vault_keys`, `certs/` and `manifest.yaml` into
`old-<date>/`. Juju's LXD containers go, but LXD itself stays if anything
else is in it. Every step runs even if one fails, and running it again is
safe. It replaces `uninstall.sh` and `uninstall2.sh`: the old `uninstall.sh`
passed each step's label to the shell as part of the command, so its
removals never actually ran.

## Network layout

Two single-node clouds share the RB4011 (config: mv-2112/HomeLab,
`network/RB4011_v4`). `site.env.example` has mz640test's values, with
mz640's alongside.

```
                       mz640                          mz640test
host eno1 (VLAN 88)    192.168.88.253                 192.168.88.252
API_RANGE (VLAN 88)    192.168.88.200-.219            192.168.88.220-.239
external VLAN          10                             20
external IPv4          192.168.10.0/24 (.10-.249)     192.168.20.0/24 (.10-.249)
external IPv6          fd18:aaa8:47c3:10::/64         fd18:aaa8:47c3:20::/64
tenant IPv6 pool       fd18:aaa8:47c3:1000::/52       fd18:aaa8:47c3:2000::/52
host ens4f0            VM trunk                       VM trunk
host ens4f1            10GbE link, 192.168.200.253    10GbE link, 192.168.200.252
```

**Management is IPv4 *or* IPv6, never both.** Dual-stack management trips
Juju bugs, so Sunbeam is only ever given one family, chosen by `MGMT_CIDR`
(`API_RANGE` must match; `--check` refuses a mix). The router doesn't
advertise IPv6 on VLAN 88. IPv4 is the default and the better-trodden path.
If you choose IPv6 management later:
- **Static address:** give the host a static address on it in netplan, not
  SLAAC.
- **Platform runners:** the admin cluster's network is IPv4-only (Magnum), so
  its runner pods can't reach IPv6-only APIs. Use runner VMs, which get IPv6.

**Give eno1 a static address** in netplan (with `accept-ra: false`), even
with IPv4 management. The router keeps a DHCP reservation, but a lease that
can't renew while the router is down takes the cloud with it.

**VMs and tenants are dual-stack.**
- **IPv4** is NATed by tenant routers, then by the RB4011 to the internet.
- **IPv6** is ULA from the lab's /48:
  - Each tenant network gets a /64 from `TENANT_V6_POOL`, routed (no NAT)
    via its tenant router's address on the external /64.
  - VMs reach the internet over IPv6 through NAT66 on the RB4011.
  - HomeLAN reaches VMs over IPv6 directly; security groups protect them.

**What the router allows.** Each cloud's networks may reach that cloud's own
`API_RANGE` on 80/443 and the internet, nothing else on management, and not
the other cloud. HomeLAN may reach everything in the clouds, the hosts, and
both API ranges.

### Tenant IPv6 routes

Sunbeam has no BGP, so the RB4011 needs one static route per tenant network
(its /64 via that tenant router's address on the external /64). Generate
them from OpenStack and import; re-run whenever tenants add networks:

```bash
source ../env.sh
../tools/ipv6-routes.py > ipv6-routes.rsc     # review it, copy to the router
# on the RB4011:  /import ipv6-routes.rsc
```

The routes are tagged with `CLOUD_NAME`, and an import replaces only that
cloud's routes. The router's blackhole for the /48 drops anything without a
route.

## What the manifest sets

| Manifest key | From site.env | Effect |
|---|---|---|
| `bootstrap.management_cidr` | `MGMT_CIDR` | which network is management |
| `k8s-addons.loadbalancer` | `API_RANGE` | addresses for the API endpoints |
| `external-networks.physnet1` | `EXT_*` (IPv4) | bridges `EXT_NIC` as physnet1 (flat or VLAN) |
| `user.remote_access_location: remote` | | VMs reached over the external network, not only from the host |
| `user.run_demo_setup: false` | | no demo user, project or network |
| `microceph_config.<fqdn>.osd_devices` | `CEPH_DISKS` | Ceph disks; wiping only if `CEPH_WIPE=true` |

The manifest was checked against Sunbeam's own `CoreConfig` schema (Sunbeam
silently ignores unknown keys, so typos would otherwise vanish).

IPv6 on the VM side (`EXT_V6_*`, `TENANT_V6_POOL`) isn't in the manifest:
Sunbeam only bridges the NIC. The undercloud Terraform builds the IPv6
subnet, address scope and tenant pool (`network.tf`) from
`site.auto.tfvars.json`.

**The demo setup is off**, and that's what normally creates the `m1.*`
flavors, the Ubuntu image and the external network. The undercloud
Terraform creates the flavors (`flavors.tf`) and external network
(`network.tf`) instead, from `site.auto.tfvars.json`, so run it straight after
the install.

## Changes from the old install.sh

- No `--accept-defaults` guessing: answers come from the manifest.
- `newgrp snap_daemon` started a new interactive shell and stalled the script;
  sunbeam now runs through `sg snap_daemon`.
- The first Octavia certificate signing failed (`-CAserial` before `ca.srl`
  existed); now uses `-CAcreateserial`.
- The admin password is no longer echoed. `admin_openrc`, `vault_keys` and
  `certs/` are created owner-only.
- `set -euo pipefail`: a failed step stops the install instead of carrying on.

## Not verified here

The manifest validates against Sunbeam's schema and `render_manifest.py` was
tested against simulated hosts. The install itself hasn't run. Things worth
watching on the first run:

- **Prompts:** `sunbeam configure` may still ask about anything the manifest
  doesn't cover on your release. `--accept-defaults` takes the default if so.
- **FQDN:** the per-node keys (`nics`, `microceph_config`) use `hostname -f`.
  If `sunbeam cluster list` shows a different name, fix `/etc/hosts` first.
