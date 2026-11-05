#!/usr/bin/env python3
"""Find disks MicroCeph could use, and optionally zap them.

    ./utils/ceph-disks.py                      list candidates, print a CEPH_DISKS= line for site.env
    ./utils/ceph-disks.py --env                print only the CEPH_DISKS= line
    sudo ./utils/ceph-disks.py --zap ID[,ID]   wipe those disks (asks first; --yes to skip)

A candidate is a whole disk (not loop/zram/rbd/nbd, not read-only, not
removable) that holds nothing in use: no mounted filesystem or swap anywhere
on it, including through LVM, RAID or LUKS, and it isn't the disk the system
runs from. Each is shown by its /dev/disk/by-id path (wwn- or nvme-eui.
first), because sdX names can change across reboots.

Disks with old partitions or signatures are listed as "has data": MicroCeph
won't take them until they're zapped (or CEPH_WIPE=true in site.env).

Zapping refuses anything that isn't a candidate, so it can't touch the system
disk or a mounted one. It clears what Ceph and partitioning tools leave
behind: BlueStore labels (including the copies at 1, 10, 100 and 1000 GiB),
partition tables at both ends of the disk, and filesystem/LVM signatures.
"""

import argparse
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

SKIP_TYPES = ("loop", "zram", "rbd", "nbd", "ram")
BY_ID = Path("/dev/disk/by-id")
# Preferred by-id names, most stable first.
ID_PREFIXES = ("wwn-", "nvme-eui.", "nvme-", "ata-", "scsi-", "usb-")


def run(cmd: list[str], check: bool = True) -> str:
    r = subprocess.run(cmd, capture_output=True, text=True)
    if check and r.returncode != 0:
        sys.exit(f"{' '.join(cmd)} failed: {r.stderr.strip()}")
    return r.stdout


def lsblk() -> list[dict]:
    out = run(["lsblk", "-J", "-b", "-o",
               "NAME,KNAME,PATH,TYPE,SIZE,MODEL,SERIAL,TRAN,RM,RO,FSTYPE,MOUNTPOINTS"])
    return json.loads(out)["blockdevices"]


def walk(dev: dict):
    yield dev
    for c in dev.get("children", []) or []:
        yield from walk(c)


def by_id_names() -> dict[str, str]:
    """/dev/sdX -> best /dev/disk/by-id path."""
    best: dict[str, tuple[int, str]] = {}
    if not BY_ID.is_dir():
        return {}
    for link in BY_ID.iterdir():
        if "-part" in link.name:
            continue
        rank = next((i for i, p in enumerate(ID_PREFIXES) if link.name.startswith(p)), len(ID_PREFIXES))
        target = str(link.resolve())
        if target not in best or rank < best[target][0]:
            best[target] = (rank, str(link))
    return {k: v for k, (_, v) in best.items()}


def human(n: int) -> str:
    for unit in ("B", "KB", "MB", "GB", "TB", "PB"):
        if n < 1000:
            return f"{n:.0f}{unit}" if unit == "B" else f"{n:.1f}{unit}"
        n /= 1000
    return f"{n:.1f}EB"


def survey() -> list[dict]:
    """Every whole disk, with why it can or can't be used."""
    ids = by_id_names()
    disks = []
    for d in lsblk():
        if d["type"] != "disk" or d["kname"].startswith(SKIP_TYPES):
            continue
        nodes = list(walk(d))
        mounts = sorted({m for n in nodes for m in (n.get("mountpoints") or []) if m})
        fstypes = sorted({n["fstype"] for n in nodes if n.get("fstype")})
        why = []
        if any(m == "/" for m in mounts):
            why.append("system disk (/)")
        elif mounts:
            why.append("mounted: " + ", ".join(mounts))
        if d.get("ro"):
            why.append("read-only")
        if d.get("rm"):
            why.append("removable")
        if not d.get("size"):
            why.append("no size")
        has_data = len(nodes) > 1 or bool(fstypes)
        disks.append({
            "path": d["path"],
            "id": ids.get(d["path"]),
            "size": d.get("size") or 0,
            "model": (d.get("model") or "").strip(),
            "tran": d.get("tran") or "",
            "fstypes": fstypes,
            "has_data": has_data,
            "excluded": why,
            "bluestore": "ceph_bluestore" in fstypes,
            "parts": [n["path"] for n in nodes[1:] if n.get("type") == "part"],
        })
    return disks


def show(disks: list[dict]) -> None:
    print(f"{'DISK':10} {'SIZE':>8}  {'TYPE':5} {'MODEL':24} STATUS")
    for d in disks:
        if d["excluded"]:
            status = "not usable: " + "; ".join(d["excluded"])
        elif d["bluestore"]:
            status = "has a Ceph OSD on it (in use by a running cluster?)"
        elif d["has_data"]:
            status = "has data (" + (", ".join(d["fstypes"]) or "partitions") + "): zap first"
        else:
            status = "blank: ready"
        print(f"{Path(d['path']).name:10} {human(d['size']):>8}  {d['tran'][:5]:5} {d['model'][:24]:24} {status}")
        if not d["excluded"]:
            print(f"{'':10} {d['id'] or '(no /dev/disk/by-id name: use with care)'}")


def env_line(disks: list[dict]) -> str:
    usable = [d["id"] or d["path"] for d in disks if not d["excluded"] and not d["bluestore"]]
    return f'CEPH_DISKS="{",".join(usable)}"'


def zap(target: dict) -> None:
    dev = target["path"]
    print(f"zapping {dev} ({target['id'] or 'no by-id name'})")
    if target["bluestore"] and shutil.which("microceph.ceph-bluestore-tool"):
        run(["microceph.ceph-bluestore-tool", "zap-device", "--dev", dev,
             "--yes-i-really-really-mean-it"], check=False)
    # Signatures on partitions first, then the disk itself.
    for part in target["parts"]:
        run(["wipefs", "-af", part], check=False)
    run(["wipefs", "-af", dev])
    if shutil.which("sgdisk"):
        run(["sgdisk", "--zap-all", dev], check=False)
    size = int(run(["blockdev", "--getsize64", dev]).strip())
    gib = 1 << 30
    # Start and end of the disk (MBR/GPT and its backup, LVM, md and FS
    # labels), then BlueStore's label copies at 1, 10, 100 and 1000 GiB.
    spans = [(0, 10 << 20), (max(0, size - (10 << 20)), 10 << 20)]
    spans += [(n * gib, 4096) for n in (1, 10, 100, 1000) if n * gib + 4096 <= size]
    with open(dev, "r+b", buffering=0) as f:
        for offset, length in spans:
            f.seek(offset)
            f.write(b"\0" * min(length, size - offset))
        os.fsync(f.fileno())
    run(["blockdev", "--rereadpt", dev], check=False)
    run(["udevadm", "settle"], check=False)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--env", action="store_true", help="print only the CEPH_DISKS= line")
    ap.add_argument("--bluestore", action="store_true",
                    help="print only disks holding a Ceph OSD, comma-separated (for uninstall.sh)")
    ap.add_argument("--zap", metavar="DISKS", help="comma-separated by-id paths or /dev names to wipe")
    ap.add_argument("--yes", action="store_true", help="don't ask before zapping")
    ap.add_argument("--force-bluestore", action="store_true",
                    help="also zap disks holding a Ceph OSD (only once that cluster is gone)")
    args = ap.parse_args()

    disks = survey()

    if args.bluestore:
        print(",".join(d["id"] or d["path"] for d in disks if d["bluestore"] and not d["excluded"]))
        return 0

    if not args.zap:
        if args.env:
            print(env_line(disks))
        else:
            show(disks)
            print()
            print("# for site.env (blank disks are ready; zap the ones with data, or set CEPH_WIPE=true):")
            print(env_line(disks))
        return 0

    if os.geteuid() != 0:
        sys.exit("--zap needs root: sudo ./utils/ceph-disks.py --zap ...")
    by_path = {}
    for d in disks:
        by_path[d["path"]] = d
        if d["id"]:
            by_path[d["id"]] = d
    targets = []
    for name in [n.strip() for n in args.zap.split(",") if n.strip()]:
        key = name if name.startswith("/dev/") else f"/dev/{name}"
        d = by_path.get(key) or by_path.get(str(Path(key).resolve()))
        if not d:
            sys.exit(f"{name}: not a whole disk on this host (see ./utils/ceph-disks.py)")
        if d["excluded"]:
            sys.exit(f"{name}: refusing to zap, {'; '.join(d['excluded'])}")
        if d["bluestore"] and not args.force_bluestore:
            sys.exit(f"{name}: holds a Ceph OSD. If that cluster is gone, add --force-bluestore")
        targets.append(d)

    print("About to destroy everything on:")
    for d in targets:
        print(f"  {d['path']}  {human(d['size'])}  {d['model']}  {d['id'] or ''}")
    if not args.yes:
        answer = input("Type 'zap' to continue: ")
        if answer.strip() != "zap":
            print("nothing changed")
            return 1
    for d in targets:
        zap(d)
    print("done. Check with: ./utils/ceph-disks.py")
    return 0


if __name__ == "__main__":
    sys.exit(main())
