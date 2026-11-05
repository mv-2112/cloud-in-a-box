#!/usr/bin/env python3
"""Point all four cib repos at your GitHub organization.

    ./set-org.py <org> [--dry-run] [--no-check]

Rewrites, in every repo under this folder:
  - module sources:  git::https://github.com/<anything>/cib-terraform-modules.git
  - github_owner = "<anything>"  in *.tfvars.example

It matches whatever org is there now, not just the YOUR_ORG placeholder, so
re-running with a different name is safe (e.g. after a typo or an org rename).
By default it first confirms <org> is a GitHub *organization*, not a personal
account; --no-check skips that (e.g. offline).

Stdlib only. Works on Linux and macOS.
"""

import argparse
import json
import re
import shutil
import subprocess
import sys
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent
REPOS = ["cib-terraform-modules", "cib-undercloud", "cib-tenant-template", "cib-tenants"]
SKIP_DIRS = {".git", ".terraform", "__pycache__"}

# GitHub org names: alphanumeric or single hyphens, no leading/trailing hyphen, max 39.
ORG_NAME = re.compile(r"^[A-Za-z0-9](?:[A-Za-z0-9]|-(?=[A-Za-z0-9])){0,38}$")

RULES = [
    # (file glob, pattern, replacement template, what)
    (
        "*.tf",
        re.compile(r"(git::https://github\.com/)([^/\s\"]+)(/cib-terraform-modules\.git)"),
        r"\g<1>{org}\g<3>",
        "module source",
    ),
    (
        "*.tfvars.example",
        re.compile(r'^(\s*github_owner\s*=\s*")([^"]*)(")', re.MULTILINE),
        r"\g<1>{org}\g<3>",
        "github_owner",
    ),
]


def check_is_org(org: str) -> None:
    """Exit unless `org` is a GitHub organization. Uses gh if present, else the public API."""
    if shutil.which("gh"):
        r = subprocess.run(["gh", "api", f"users/{org}", "--jq", ".type"], capture_output=True, text=True)
        if r.returncode == 0:
            kind = r.stdout.strip()
        elif "Not Found" in r.stderr:
            kind = None
        else:
            sys.exit(f"Couldn't ask GitHub about {org!r} via gh: {r.stderr.strip()}\nRetry, or use --no-check.")
    else:
        try:
            with urllib.request.urlopen(f"https://api.github.com/users/{org}", timeout=15) as resp:
                kind = json.load(resp).get("type")
        except urllib.error.HTTPError as e:
            if e.code != 404:
                sys.exit(f"GitHub API error for {org!r}: {e}. Retry, or use --no-check.")
            kind = None
        except OSError as e:
            sys.exit(f"Couldn't reach GitHub ({e}). Retry, or use --no-check.")

    if kind is None:
        sys.exit(f"{org!r} doesn't exist on GitHub. Create the organization first: https://github.com/organizations/plan")
    if kind != "Organization":
        sys.exit(
            f"{org!r} is a personal account ({kind}), not an organization.\n"
            "The cib repos need an org: tenant repos, GitHub Apps and Backstage's catalog all hang off it.\n"
            "Create a free one at https://github.com/organizations/plan"
        )
    print(f"✓ {org} is a GitHub organization")


def files(glob: str):
    for repo in REPOS:
        base = ROOT / repo
        if not base.is_dir():
            continue
        for p in sorted(base.rglob(glob)):
            if not SKIP_DIRS.intersection(p.parts):
                yield p


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("org", help="GitHub organization name, e.g. blackcatengineering")
    ap.add_argument("--dry-run", action="store_true", help="show what would change, write nothing")
    ap.add_argument("--no-check", action="store_true", help="don't confirm with GitHub that it's an organization")
    args = ap.parse_args()

    org = args.org.strip()
    if not ORG_NAME.match(org):
        sys.exit(f"{org!r} isn't a valid GitHub org name (letters, digits, single hyphens, max 39).")

    missing = [r for r in REPOS if not (ROOT / r).is_dir()]
    if missing:
        sys.exit(f"Run this from the folder holding all four repos; missing: {', '.join(missing)}")

    if not args.no_check:
        check_is_org(org)

    changed_files = 0
    changes = 0
    for glob, pattern, template, what in RULES:
        replacement = template.format(org=org)
        for path in files(glob):
            text = path.read_text()
            hits = [m for m in pattern.finditer(text) if m.group(2) != org]
            if not hits:
                continue
            for m in hits:
                line = text.count("\n", 0, m.start()) + 1
                print(f"{path.relative_to(ROOT)}:{line}: {what} {m.group(2)} -> {org}")
            changes += len(hits)
            changed_files += 1
            if not args.dry_run:
                path.write_text(pattern.sub(replacement, text))

    # Anything still mentioning the placeholder in code means a file this script doesn't know about.
    leftovers = [
        f"{p.relative_to(ROOT)}"
        for glob in ("*.tf", "*.tfvars.example", "*.yaml", "*.sh", "*.tftpl")
        for p in files(glob)
        if "YOUR_ORG" in p.read_text()
    ]

    verb = "Would change" if args.dry_run else "Changed"
    if changes:
        print(f"\n{verb} {changes} reference(s) in {changed_files} file(s).")
    else:
        print(f"\nNothing to change: everything already points at {org}.")
    if leftovers and not args.dry_run:
        print("Still contain YOUR_ORG (edit by hand): " + ", ".join(leftovers), file=sys.stderr)
        return 1

    print(
        "\nAlso set by hand, once each repo exists on GitHub:\n"
        f"  - cib-tenants repo variable GITHUB_OWNER = {org}\n"
        f"      gh variable set GITHUB_OWNER --body {org} --repo {org}/cib-tenants\n"
        "  - github_owner in any terraform.tfvars you've already copied from an example"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
