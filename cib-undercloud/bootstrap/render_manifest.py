#!/usr/bin/env python3
"""Check site.env against this host, then render the Sunbeam manifest and the
undercloud's Terraform variables from it.

Run by install.sh (with site.env exported into the environment), or alone:
    set -a; . ./site.env; set +a; python3 -I render_manifest.py [--check-only]

Address families:
  - Management (MGMT_CIDR, API_RANGE) is single-stack: IPv4 OR IPv6, never both
    (dual-stack management trips Juju bugs). The family of MGMT_CIDR decides.
  - The VM network is dual-stack: IPv4 (EXT_*) plus optional IPv6 (EXT_V6_*).
  - Tenant networks get IPv6 /64s from TENANT_V6_POOL, routed without NAT.

Stdlib only, so it runs on a fresh Ubuntu before anything is installed.
"""

import ipaddress
import json
import os
import socket
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
MANIFEST = HERE / "manifest.yaml"
TFVARS = HERE.parent / "terraform" / "site.auto.tfvars.json"

# Charms Sunbeam deploys from the OpenStack track (its OPENSTACK_CHANNEL,
# always "<track>/stable" whatever the snap's channel), from snap-openstack
# stable/2026.1 sunbeam/versions.py and the features install.sh enables.
# CHARM_CHANNEL in site.env points all of them at one channel instead.
OPENSTACK_CORE_CHARMS = (
    "cinder-k8s", "glance-k8s", "horizon-k8s", "keystone-k8s", "keystone-saml-k8s",
    "neutron-k8s", "nova-k8s", "placement-k8s",
    "openstack-network-agents", "sunbeam-ovn-proxy", "openstack-hypervisor",
    "sunbeam-machine", "sunbeam-clusterd", "cinder-volume", "cinder-volume-ceph",
    "epa-orchestrator",
)
# Charms that install an OpenStack snap themselves, with snap-channel set by
# Sunbeam to "<track>/stable" too. Manifest charm config overrides it
# (steps/sunbeam_machine.py, microovn.py, cinder_volume.py, clusterd.py and
# the hypervisor plan's merge(..., var.charm_config)).
OPENSTACK_SNAP_CHARMS = (
    "openstack-network-agents", "epa-orchestrator", "cinder-volume",
    "sunbeam-clusterd", "openstack-hypervisor",
)
OPENSTACK_FEATURE_CHARMS = {
    "secrets": ("barbican-k8s",),
    "loadbalancer": ("octavia-k8s", "openstack-port-cni-k8s"),
    "caas": ("magnum-k8s",),
    "orchestration": ("heat-k8s",),
}

Net = ipaddress.IPv4Network | ipaddress.IPv6Network
Addr = ipaddress.IPv4Address | ipaddress.IPv6Address
Iface = ipaddress.IPv4Interface | ipaddress.IPv6Interface

errors: list[str] = []
warnings: list[str] = []


def env(name: str, required: bool = True) -> str:
    value = os.environ.get(name, "").strip()
    if required and (not value or value == "CHANGEME"):
        errors.append(f"{name} is not set in site.env")
    return value


def network(name: str, value: str, version: int | None = None) -> Net | None:
    if not value:
        return None
    try:
        net = ipaddress.ip_network(value, strict=True)
    except ValueError as e:
        errors.append(f"{name}={value!r}: {e}")
        return None
    if version and net.version != version:
        errors.append(f"{name}={value!r} must be IPv{version}")
        return None
    return net


def address(name: str, value: str, version: int | None = None) -> Addr | None:
    if not value:
        return None
    try:
        addr = ipaddress.ip_address(value)
    except ValueError:
        errors.append(f"{name}={value!r} is not an IP address")
        return None
    if version and addr.version != version:
        errors.append(f"{name}={value!r} must be IPv{version}")
        return None
    return addr


def parse_range(name: str, value: str) -> tuple[Addr, Addr] | None:
    try:
        start, end = (ipaddress.ip_address(p.strip()) for p in value.split("-"))
    except ValueError:
        errors.append(f"{name}={value!r} must look like 10.0.0.10-10.0.0.20 or fd00::10-fd00::20")
        return None
    if start.version != end.version:
        errors.append(f"{name}: start and end must be the same IP version")
        return None
    if start > end:
        errors.append(f"{name}: start {start} is after end {end}")
        return None
    return start, end


def host_addrs() -> dict[str, list[Iface]]:
    """Every NIC name -> its addresses (both families; link-local excluded).

    `ip -j addr`, not `ip -4 addr`: the latter omits interfaces with no IPv4
    address, which is exactly what an unaddressed VM NIC looks like.
    """
    out = subprocess.run(["ip", "-j", "addr"], capture_output=True, text=True, check=True).stdout
    result: dict[str, list[Iface]] = {}
    for link in json.loads(out):
        addrs = []
        for a in link.get("addr_info", []):
            if a.get("family") not in ("inet", "inet6"):
                continue
            iface = ipaddress.ip_interface(f"{a['local']}/{a['prefixlen']}")
            if iface.ip.is_link_local:  # fe80::, always present on an up IPv6 link
                continue
            addrs.append(iface)
        result[link["ifname"]] = addrs
    return result


def main() -> int:
    check_only = "--check-only" in sys.argv

    # --- Management: single-stack, family taken from MGMT_CIDR ---
    mgmt = network("MGMT_CIDR", env("MGMT_CIDR"))
    family = mgmt.version if mgmt else None
    api = parse_range("API_RANGE", env("API_RANGE"))

    # --- VM network: IPv4 required, IPv6 optional ---
    ext = network("EXT_CIDR", env("EXT_CIDR"), version=4)
    gw = address("EXT_GATEWAY", env("EXT_GATEWAY"), version=4)
    pool = parse_range("EXT_RANGE", env("EXT_RANGE"))
    ingress_ip = address("PLATFORM_INGRESS_IP", env("PLATFORM_INGRESS_IP", required=False), version=4)
    ext6 = network("EXT_V6_CIDR", env("EXT_V6_CIDR", required=False), version=6)
    gw6 = address("EXT_V6_GATEWAY", env("EXT_V6_GATEWAY", required=False), version=6)
    tenant6 = network("TENANT_V6_POOL", env("TENANT_V6_POOL", required=False), version=6)

    ext_nic = env("EXT_NIC")
    ext_type = env("EXT_NETWORK_TYPE")
    vlan = env("EXT_VLAN_ID", required=False)
    region = env("REGION")
    release = env("RELEASE", required=False)
    # Default: the charms follow the snap's channel (snap 2026.1/edge ->
    # charms 2026.1/edge). "default" leaves Sunbeam's own choice.
    charm_channel = env("CHARM_CHANNEL", required=False) or release
    charm_overrides = {}
    for item in env("CHARM_CHANNELS", required=False).split(","):
        if item.strip():
            name, _, chan = item.strip().partition("=")
            if not chan:
                errors.append(f"CHARM_CHANNELS entry {item!r} must look like charm-name=track/risk")
            charm_overrides[name.strip()] = chan.strip()
    disks = [d.strip() for d in env("CEPH_DISKS").split(",") if d.strip()]
    wipe = env("CEPH_WIPE", required=False).lower() == "true"
    fqdn = os.environ.get("NODE_FQDN") or socket.getfqdn()
    # Names this cloud wherever two clouds share a router (tenant IPv6 route
    # tags). Defaults to the host's short name.
    cloud_name = env("CLOUD_NAME", required=False) or fqdn.split(".")[0]

    # --- Node name: Sunbeam keys per-node settings by FQDN ---
    if "." not in fqdn:
        errors.append(
            f"hostname {fqdn!r} has no domain. Sunbeam needs an FQDN "
            "(set one in /etc/hosts, e.g. '192.168.88.252 mz640test.lab.home.arpa mz640test')"
        )

    nics = host_addrs()

    # --- Management address on this host ---
    mgmt_ip = None
    if mgmt:
        on_mgmt = [(n, i) for n, ifs in nics.items() for i in ifs if i.ip in mgmt and n != ext_nic]
        if not on_mgmt:
            errors.append(f"this host has no address in MGMT_CIDR {mgmt}")
        else:
            mgmt_ip = on_mgmt[0][1].ip
            if family == 6:
                warnings.append(
                    f"IPv6 management: make {mgmt_ip} static (netplan), not SLAAC/privacy, or the "
                    "cluster's address can change under it. IPv6 management is less proven on Sunbeam than IPv4"
                )

    # --- Name resolution: FQDN -> management address (router DNS or /etc/hosts) ---
    if mgmt_ip and "." in fqdn:
        try:
            resolved = {
                ipaddress.ip_address(a[4][0].split("%")[0])
                for a in socket.getaddrinfo(fqdn, None)
            }
        except socket.gaierror:
            resolved = set()
        if mgmt_ip not in resolved:
            found = ", ".join(sorted(map(str, resolved))) or "nothing"
            warnings.append(
                f"{fqdn} resolves to {found}, not this host's management address {mgmt_ip}. "
                "Add it to the router's DNS (HomeLab RB4011_v4, src/lablan/34-dns.rsc) and make sure "
                "/etc/hosts doesn't map it to 127.0.1.1"
            )

    # --- API range: same family as management, inside it, not the host ---
    if api and mgmt:
        if api[0].version != family:
            errors.append(
                f"API_RANGE is IPv{api[0].version} but MGMT_CIDR is IPv{family}: management is "
                "single-stack, so both must be the same family"
            )
        else:
            if api[0] not in mgmt or api[1] not in mgmt:
                errors.append(f"API_RANGE {api[0]}-{api[1]} must sit inside MGMT_CIDR {mgmt}")
            if mgmt_ip and api[0] <= mgmt_ip <= api[1]:
                errors.append(f"API_RANGE contains this host's own address {mgmt_ip}")
            if int(api[1]) - int(api[0]) + 1 < 10:
                warnings.append("API_RANGE has fewer than 10 addresses; Sunbeam publishes several services")
            if family == 4:
                warnings.append(f"make sure {api[0]}-{api[1]} is outside your router's DHCP pool")

    # --- VM network, IPv4 ---
    if ext and mgmt and ext.version == mgmt.version and ext.overlaps(mgmt):
        errors.append(f"EXT_CIDR {ext} overlaps MGMT_CIDR {mgmt}: VM traffic must stay off the management network")
    if ext:
        if gw and gw not in ext:
            errors.append(f"EXT_GATEWAY {gw} is not inside EXT_CIDR {ext}")
        if pool and pool[0].version != 4:
            errors.append("EXT_RANGE must be IPv4 (floating IPs are IPv4; IPv6 is routed, not floated)")
        elif pool:
            if pool[0] not in ext or pool[1] not in ext:
                errors.append(f"EXT_RANGE must sit inside EXT_CIDR {ext}")
            if gw and pool[0] <= gw <= pool[1]:
                errors.append("EXT_RANGE must not include EXT_GATEWAY")
            warnings.append(f"make sure the router runs no DHCP on the VM VLAN, or its pool is outside {pool[0]}-{pool[1]}")
        # The platform ingress's fixed floating IP: inside the VM network,
        # outside the pool (so Neutron never hands it to anything else).
        if ingress_ip:
            if ingress_ip not in ext:
                errors.append(f"PLATFORM_INGRESS_IP {ingress_ip} is not inside EXT_CIDR {ext}")
            elif pool and pool[0].version == 4 and pool[0] <= ingress_ip <= pool[1]:
                errors.append(f"PLATFORM_INGRESS_IP {ingress_ip} is inside EXT_RANGE: pick one outside it, so no other floating IP can take it")
            elif ingress_ip == gw:
                errors.append("PLATFORM_INGRESS_IP must not be EXT_GATEWAY")
        else:
            warnings.append("PLATFORM_INGRESS_IP unset: the admin cluster's ingress gets a random floating IP, which changes on rebuild (DNS can't point at it)")

    # --- VM network, IPv6 (optional) ---
    if ext6 or gw6:
        if not (ext6 and gw6):
            errors.append("set both EXT_V6_CIDR and EXT_V6_GATEWAY, or neither")
        else:
            if ext6.prefixlen != 64:
                errors.append(f"EXT_V6_CIDR {ext6} must be a /64 (SLAAC needs exactly /64)")
            if gw6 not in ext6:
                errors.append(f"EXT_V6_GATEWAY {gw6} is not inside EXT_V6_CIDR {ext6}")
            if mgmt and family == 6 and ext6.overlaps(mgmt):
                errors.append(f"EXT_V6_CIDR {ext6} overlaps MGMT_CIDR {mgmt}")
            if not ext6.is_private:
                warnings.append(
                    f"EXT_V6_CIDR {ext6} is a global prefix; if your ISP's delegation is dynamic, "
                    "prefer the VLAN's stable ULA /64"
                )
    if tenant6:
        if not ext6:
            errors.append("TENANT_V6_POOL needs EXT_V6_CIDR/EXT_V6_GATEWAY: tenant IPv6 is routed via the external network")
        if tenant6.prefixlen > 56:
            errors.append(f"TENANT_V6_POOL {tenant6} is too small; use /56 or larger (each tenant network takes a /64)")
        for other_name, other in (("EXT_V6_CIDR", ext6), ("MGMT_CIDR", mgmt if family == 6 else None)):
            if other and tenant6.overlaps(other):
                errors.append(f"TENANT_V6_POOL {tenant6} overlaps {other_name} {other}")

    # --- The VM NIC: exists, unaddressed (both families), has link ---
    if ext_nic and ext_nic != "CHANGEME":
        if ext_nic not in nics:
            errors.append(f"EXT_NIC {ext_nic!r} doesn't exist (see: ip -br link)")
        elif any(i.version == 4 for i in nics[ext_nic]):
            errors.append(
                f"EXT_NIC {ext_nic} has IPv4 addresses ({', '.join(map(str, nics[ext_nic]))}); "
                "Sunbeam needs it unaddressed. It must not be the management NIC."
            )
        elif nics[ext_nic]:
            # IPv6 only: router-advertised (SLAAC) addresses. The switch port is
            # carrying something untagged; it should be a tagged-only trunk. Warn
            # rather than block: the addresses alone don't stop the install.
            warnings.append(
                f"EXT_NIC {ext_nic} has IPv6 addresses ({', '.join(map(str, nics[ext_nic]))}) from router "
                "adverts, so its switch port is passing untagged traffic (management?). Make that port a "
                "tagged-only trunk (HomeLab RB4011_v4, lablan/30-bridge.rsc), and set 'accept-ra: false' "
                f"and 'link-local: []' for {ext_nic} in netplan"
            )
        else:
            # No link = VMs get no connectivity, silently. Warn, don't block:
            # the cable may simply not be patched yet.
            try:
                carrier = Path(f"/sys/class/net/{ext_nic}/carrier").read_text().strip()
            except OSError:
                carrier = "0"  # unreadable when the link is administratively down
            if carrier != "1":
                warnings.append(f"EXT_NIC {ext_nic} has no link (cable/switch port?); VMs won't be reachable until it does")

    if ext_type not in ("flat", "vlan"):
        errors.append("EXT_NETWORK_TYPE must be flat or vlan")
    vlan_id = None
    if ext_type == "vlan":
        if not vlan.isdigit() or not 1 <= int(vlan) <= 4094:
            errors.append("EXT_VLAN_ID must be 1-4094 when EXT_NETWORK_TYPE=vlan")
        else:
            vlan_id = int(vlan)

    # --- Ceph disks ---
    for d in disks:
        if not Path(d).exists():
            errors.append(f"CEPH_DISKS entry {d} doesn't exist (./utils/ceph-disks.py lists this host's disks)")
        elif not d.startswith("/dev/disk/by-id/"):
            warnings.append(f"{d}: prefer /dev/disk/by-id paths, sdX names can change across reboots")

    for w in warnings:
        print(f"warning: {w}")
    if errors:
        for e in errors:
            print(f"error: {e}", file=sys.stderr)
        return 1
    if check_only:
        charms = "Sunbeam's default" if not charm_channel or charm_channel == "default" else charm_channel
        print(f"site.env OK (management IPv{family}, VM network IPv4{' + IPv6' if ext6 else ' only'}, "
              f"OpenStack charms {charms}{', plus ' + str(len(charm_overrides)) + ' override(s)' if charm_overrides else ''})")
        return 0

    # Sunbeam is told only about IPv4 on the external network (it bridges the
    # NIC and builds nothing else there). IPv6 subnets are added by the
    # undercloud Terraform.
    external = {
        "nics": {fqdn: ext_nic},
        "cidr": str(ext),
        "gateway": str(gw),
        "range": f"{pool[0]}-{pool[1]}",
        "network_type": ext_type,
        "segmentation_id": vlan_id,
    }

    manifest = {
        "core": {
            "config": {
                "proxy": {"proxy_required": False},
                # Single family: IPv4 or IPv6, never both.
                "bootstrap": {"management_cidr": str(mgmt)},
                "region": region,
                "database": "single",
                # OpenStack API endpoints: load-balancer range on the management network.
                "k8s-addons": {"loadbalancer": f"{api[0]}-{api[1]}"},
                # No demo user/project/network. The undercloud Terraform owns
                # flavors and the external network instead.
                "user": {
                    "run_demo_setup": False,
                    "remote_access_location": "remote",
                },
                # VM access: its own NIC/VLAN, physnet1.
                "external-networks": {"physnet1": external},
                "microceph_config": {
                    fqdn: {
                        "osd_devices": disks,
                        "dangerous_i_acknowledge_i_will_lose_data_wipe_disks": wipe,
                    }
                },
            }
        }
    }

    # Charm channels (see OPENSTACK_CORE_CHARMS). Feature charms go under
    # features.<name>; listing a feature here doesn't enable it.
    core_charms: dict = {}
    features: dict = {}
    if charm_channel and charm_channel != "default":
        core_charms = {c: {"channel": charm_channel} for c in OPENSTACK_CORE_CHARMS}
        for c in OPENSTACK_SNAP_CHARMS:
            core_charms[c]["config"] = {"snap-channel": charm_channel}
        features = {
            f: {"software": {"charms": {c: {"channel": charm_channel} for c in charms}}}
            for f, charms in OPENSTACK_FEATURE_CHARMS.items()
        }
    for name, chan in charm_overrides.items():
        owner = next((f for f, cs in OPENSTACK_FEATURE_CHARMS.items() if name in cs), None)
        if owner:
            features.setdefault(owner, {"software": {"charms": {}}})["software"]["charms"][name] = {"channel": chan}
        else:
            core_charms.setdefault(name, {})["channel"] = chan
    if core_charms:
        manifest["core"]["software"] = {"charms": core_charms}
    if features:
        manifest["features"] = features

    header = (
        "# Generated by render_manifest.py from site.env. Edit site.env, not this file.\n"
        f"# Node: {fqdn}\n\n"
    )
    try:
        import yaml  # python3-yaml ships with Ubuntu (cloud-init needs it)

        body = yaml.safe_dump(manifest, sort_keys=False, default_flow_style=False)
    except ImportError:
        body = json.dumps(manifest, indent=2) + "\n"  # JSON is valid YAML

    MANIFEST.write_text(header + body)
    print(f"wrote {MANIFEST}")

    tfvars = {
        "region": region,
        "cloud_name": cloud_name,
        "management_ip_version": family,
        "external_network_config": {
            "cidr": str(ext),
            "gateway": str(gw),
            "range": f"{pool[0]}-{pool[1]}",
            "network_type": ext_type,
            "segmentation_id": vlan_id,
            "ipv6_cidr": str(ext6) if ext6 else None,
            "ipv6_gateway": str(gw6) if gw6 else None,
        },
        "tenant_ipv6_pool": str(tenant6) if tenant6 else None,
        "platform_ingress_ip": str(ingress_ip) if ingress_ip else None,
    }
    TFVARS.write_text(json.dumps(tfvars, indent=2) + "\n")
    print(f"wrote {TFVARS}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
