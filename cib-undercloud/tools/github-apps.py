#!/usr/bin/env python3
"""Create the platform's GitHub Apps and hand their credentials to Terraform.

    ./github-apps.py runners      # app for the platform runners (ARC) on cib-tenants
    ./github-apps.py backstage    # app for Backstage: sign-in and the catalog

GitHub has no API that creates an app outright, so this uses its app
manifest flow: the app's whole definition is generated here, GitHub shows
it pre-filled and you click "Create GitHub App", then "Install". That's the
only manual part. The script collects the app ID, private key and client
secret, finds the installation, checks it, and writes them to
../platform/github-apps.auto.tfvars.json (mode 600, git-ignored), which
Terraform reads automatically.

Run it on a machine with a browser (it serves a page on 127.0.0.1 and opens
it). Defaults (org, Backstage hostname, runners' repository) come from
../platform/terraform.tfvars. Needs only Python 3 and openssl.
"""

import argparse
import base64
import html
import http.server
import json
import os
import re
import secrets
import subprocess
import sys
import tempfile
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
import webbrowser
from pathlib import Path

HERE = Path(__file__).resolve().parent
PLATFORM = HERE.parent / "platform"
TFVARS = PLATFORM / "terraform.tfvars"
OUT = PLATFORM / "github-apps.auto.tfvars.json"
API = "https://api.github.com"

# Permissions per app. Runners: what actions-runner-controller needs to
# register repository-level runners. Backstage: catalog and org membership
# for sign-in, plus what its scaffolder needs to create repos (drop that
# with --read-only).
PERMISSIONS = {
    "runners": {"administration": "write", "actions": "read", "metadata": "read"},
    "backstage": {"contents": "read", "metadata": "read", "members": "read"},
}
SCAFFOLDER = {"administration": "write", "contents": "write", "workflows": "write", "pull_requests": "write"}


# ------------------------------------------------------------------ helpers --
def tfvars_value(pattern: str) -> str | None:
    """Pull a simple string out of terraform.tfvars (defaults only)."""
    if not TFVARS.exists():
        return None
    m = re.search(pattern, TFVARS.read_text(), re.M)
    return m.group(1) if m else None


def default_backstage_hostname() -> str:
    """Same rule as platform/main.tf: hostname in terraform.tfvars, else
    backstage.<cloud_name>.<dns_domain> (cloud_name from stage 1's tfvars)."""
    explicit = tfvars_value(r'^\s*hostname\s*=\s*"([^"]+)"')
    if explicit:
        return explicit
    domain = tfvars_value(r'^\s*dns_domain\s*=\s*"([^"]+)"') or "lab.home.arpa"
    site = Path(__file__).resolve().parent.parent / "terraform" / "site.auto.tfvars.json"
    try:
        cloud = json.loads(site.read_text()).get("cloud_name")
    except (OSError, ValueError):
        cloud = None
    return f"backstage.{cloud}.{domain}" if cloud else f"backstage.{domain}"


def github(method: str, path: str, token: str | None = None, body: dict | None = None):
    req = urllib.request.Request(
        path if path.startswith("https://") else API + path,
        method=method,
        data=json.dumps(body).encode() if body is not None else None,
        headers={
            "Accept": "application/vnd.github+json",
            "X-GitHub-Api-Version": "2022-11-28",
            "User-Agent": "cib-github-apps",
            **({"Authorization": f"Bearer {token}"} if token else {}),
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            return json.loads(r.read() or b"null")
    except urllib.error.HTTPError as e:
        raise SystemExit(f"GitHub {method} {path}: {e.code} {e.read().decode(errors='replace')[:300]}")


def b64url(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()


def app_jwt(app_id: int, pem: str) -> str:
    """RS256 JWT for the app itself, signed with openssl (no Python deps)."""
    now = int(time.time())
    head = b64url(json.dumps({"alg": "RS256", "typ": "JWT"}).encode())
    body = b64url(json.dumps({"iat": now - 60, "exp": now + 540, "iss": app_id}).encode())
    with tempfile.TemporaryDirectory() as d:
        key = Path(d, "key.pem")
        key.touch(mode=0o600)
        key.write_text(pem)
        sig = subprocess.run(
            ["openssl", "dgst", "-sha256", "-sign", str(key)],
            input=f"{head}.{body}".encode(), capture_output=True, check=True,
        ).stdout
    return f"{head}.{body}.{b64url(sig)}"


def pending_path(kind: str) -> Path:
    return PLATFORM / f".github-app-{kind}.pending.json"


def save_pending(kind: str, app: dict) -> None:
    """GitHub shows an app's private key once: keep it until install finishes."""
    path = pending_path(kind)
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "w") as f:
        json.dump(app, f)


def write_out(key: str, value: dict) -> None:
    data = json.loads(OUT.read_text()) if OUT.exists() else {}
    data[key] = value
    tmp = OUT.with_suffix(".tmp")
    fd = os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "w") as f:
        json.dump(data, f, indent=2)
        f.write("\n")
    os.replace(tmp, OUT)


# --------------------------------------------------------------- manifest --
def build_manifest(kind: str, args, port: int) -> dict:
    perms = dict(PERMISSIONS[kind])
    if kind == "backstage" and not args.read_only:
        perms.update(SCAFFOLDER)
    m = {
        "name": args.name,
        "url": f"https://github.com/{args.org}",
        "description": {
            "runners": f"cloud-in-a-box platform runners (actions-runner-controller) for {args.org}/{args.repo}",
            "backstage": f"cloud-in-a-box Backstage at https://{args.hostname}",
        }[kind],
        "public": False,
        "default_permissions": perms,
        "default_events": [],
        # Neither app needs webhooks: ARC long-polls, Backstage reads on a schedule.
        "hook_attributes": {"url": "https://example.invalid/unused", "active": False},
        "redirect_url": f"http://127.0.0.1:{port}/created",
        "setup_url": f"http://127.0.0.1:{port}/installed",
        "setup_on_update": True,
    }
    if kind == "backstage":
        m["callback_urls"] = [f"https://{args.hostname}/api/auth/github/handler/frame"]
    return m


# ------------------------------------------------------------ local server --
class Flow:
    """State shared between the local web server and the main thread."""

    def __init__(self, kind, args, manifest, new_app_url):
        self.kind, self.args, self.manifest = kind, args, manifest
        self.new_app_url = new_app_url
        self.state = secrets.token_urlsafe(16)
        self.app: dict | None = None
        self.installation_id: str | None = None
        self.done = threading.Event()
        self.error: str | None = None


def page(title: str, body: str) -> bytes:
    return (
        "<!doctype html><meta charset=utf-8><title>%s</title>"
        "<body style='font-family:system-ui;max-width:42rem;margin:3rem auto;line-height:1.5'>"
        "<h1 style='font-size:1.3rem'>%s</h1>%s" % (html.escape(title), html.escape(title), body)
    ).encode()


def make_handler(flow: Flow):
    class H(http.server.BaseHTTPRequestHandler):
        def log_message(self, *a):  # quiet
            pass

        def send(self, code, body=b"", location=None):
            self.send_response(code)
            if location:
                self.send_header("Location", location)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.end_headers()
            self.wfile.write(body)

        def do_GET(self):
            url = urllib.parse.urlparse(self.path)
            q = dict(urllib.parse.parse_qsl(url.query))
            if url.path == "/":
                form = (
                    f"<p>Creating <b>{html.escape(flow.args.name)}</b> in <b>{html.escape(flow.args.org)}</b>. "
                    "GitHub shows the settings pre-filled: click <b>Create GitHub App</b>.</p>"
                    f"<form id=f method=post action='{html.escape(flow.new_app_url)}?state={flow.state}'>"
                    f"<input type=hidden name=manifest value='{html.escape(json.dumps(flow.manifest))}'>"
                    "<button>Continue to GitHub</button></form>"
                    "<script>document.getElementById('f').submit()</script>"
                )
                return self.send(200, page("Create the GitHub App", form))
            if url.path == "/created":
                if q.get("state") != flow.state or "code" not in q:
                    return self.send(400, page("Unexpected request", "<p>State mismatch; start again.</p>"))
                # One-time code -> app ID, private key, client ID/secret.
                try:
                    flow.app = github("POST", f"/app-manifests/{q['code']}/conversions", body={})
                except SystemExit as e:
                    flow.error = str(e)
                    flow.done.set()
                    return self.send(502, page("GitHub refused", f"<p>{html.escape(str(e))}</p>"))
                save_pending(flow.kind, flow.app)
                hint = (
                    f"<p>Choose <b>Only select repositories</b> and pick <b>{html.escape(flow.args.repo)}</b>.</p>"
                    if flow.kind == "runners" else "<p>Install it on the organisation.</p>"
                )
                install = f"{flow.app['html_url']}/installations/new"
                return self.send(302, page("App created", hint), location=install)
            if url.path == "/installed":
                flow.installation_id = q.get("installation_id")
                flow.done.set()
                return self.send(200, page("Installed", "<p>All done. You can close this tab.</p>"))
            self.send(404, page("Not found", ""))

    return H


# ---------------------------------------------------------------- main -----
def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("app", choices=["runners", "backstage"])
    ap.add_argument("--org", default=tfvars_value(r'^\s*github_owner\s*=\s*"([^"]+)"'),
                    help="GitHub org (default: github_owner in platform/terraform.tfvars)")
    ap.add_argument("--repo", default=tfvars_value(r'^\s*repository\s*=\s*"([^"]+)"') or "cib-tenants",
                    help="runners: the one repository they serve (default: cib-tenants)")
    ap.add_argument("--hostname", default=default_backstage_hostname(),
                    help="backstage: its public hostname, for the sign-in callback "
                         "(default: as platform/ computes it, e.g. backstage.mz640test.lab.home.arpa)")
    ap.add_argument("--read-only", action="store_true",
                    help="backstage: catalog and sign-in only, no repository creation (scaffolder)")
    ap.add_argument("--name", help="app name (unique across GitHub, max 34 characters)")
    ap.add_argument("--port", type=int, default=8765)
    ap.add_argument("--no-browser", action="store_true", help="print the URL instead of opening it")
    ap.add_argument("--timeout", type=int, default=900, help="seconds to wait for create + install")
    ap.add_argument("--resume", action="store_true",
                    help="the app was created earlier but not installed: wait for its installation")
    args = ap.parse_args()

    if not args.org:
        sys.exit("No org: pass --org or set github_owner in platform/terraform.tfvars")
    args.name = args.name or f"{args.org}-cib-{args.app}"[:34]

    owner = github("GET", f"/users/{args.org}")
    new_app_url = (
        f"https://github.com/organizations/{args.org}/settings/apps/new"
        if owner.get("type") == "Organization" else "https://github.com/settings/apps/new"
    )
    if owner.get("type") != "Organization":
        print(f"note: {args.org} is a user account, not an org; the app will belong to it")

    manifest = build_manifest(args.app, args, args.port)
    flow = Flow(args.app, args, manifest, new_app_url)
    server = http.server.ThreadingHTTPServer(("127.0.0.1", args.port), make_handler(flow))
    threading.Thread(target=server.serve_forever, daemon=True).start()

    if args.resume:
        if not pending_path(args.app).exists():
            sys.exit(f"Nothing to resume: {pending_path(args.app)} doesn't exist.")
        flow.app = json.loads(pending_path(args.app).read_text())
        install = f"{flow.app['html_url']}/installations/new"
        print(f"Resuming {flow.app['slug']}: install it, if you haven't, at {install}")
        if not args.no_browser:
            webbrowser.open(install)
    else:
        start = f"http://127.0.0.1:{args.port}/"
        print(f"Creating GitHub App '{args.name}' for {args.org} ({args.app}).")
        print("  In the browser: Create GitHub App, then Install"
              + (f" (Only select repositories: {args.repo})." if args.app == "runners" else "."))
        print(f"  Page: {start}")
        if not args.no_browser:
            webbrowser.open(start)

    # Wait for GitHub's redirect after install; once the app exists, also poll
    # its installations, in case the browser never comes back to us.
    deadline = time.time() + args.timeout
    while not flow.done.wait(5):
        if time.time() > deadline:
            server.shutdown()
            if flow.app:
                sys.exit(f"Timed out waiting for the install. The app exists and its key is kept in "
                         f"{pending_path(args.app)}: install it, then run: {sys.argv[0]} {args.app} --resume")
            sys.exit("Timed out before the app was created; nothing to keep. Run again.")
        if flow.app:
            installs = github("GET", "/app/installations", token=app_jwt(flow.app["id"], flow.app["pem"]))
            mine = [i for i in installs if i["account"]["login"].lower() == args.org.lower()]
            if mine:
                flow.installation_id = str(mine[0]["id"])
                flow.done.set()
    server.shutdown()
    if flow.error:
        sys.exit(flow.error)
    app = flow.app
    if not app or not flow.installation_id:
        sys.exit("The app wasn't created or installed; nothing written.")

    # Check the installation: right account, and for the runners the right repo.
    jwt = app_jwt(app["id"], app["pem"])
    inst = github("GET", f"/app/installations/{flow.installation_id}", token=jwt)
    if inst["account"]["login"].lower() != args.org.lower():
        sys.exit(f"Installed on {inst['account']['login']}, not {args.org}; nothing written.")
    if args.app == "runners":
        tok = github("POST", f"/app/installations/{flow.installation_id}/access_tokens", token=jwt)["token"]
        repos = [r["name"] for r in github("GET", "/installation/repositories?per_page=100", token=tok)["repositories"]]
        if args.repo not in repos:
            sys.exit(f"The app can't see {args.org}/{args.repo} (it has: {', '.join(repos) or 'nothing'}). "
                     f"Add it in {app['html_url']}/installations and re-run; nothing written.")
        if repos != [args.repo]:
            print(f"warning: the runners app can also administer {', '.join(r for r in repos if r != args.repo)}. "
                  f"Narrow it to {args.repo} in the installation's settings.")
        write_out("platform_runner_github_app", {
            "app_id": str(app["id"]),
            "installation_id": str(flow.installation_id),
            "private_key": app["pem"],
        })
    else:
        write_out("backstage_github_app", {
            "app_id": str(app["id"]),
            "client_id": app["client_id"],
            "client_secret": app["client_secret"],
            "private_key": app["pem"],
        })

    pending_path(args.app).unlink(missing_ok=True)
    print(f"Created {app['html_url']} (ID {app['id']}), installed on {args.org} (installation {flow.installation_id}).")
    print(f"Credentials written to {OUT} (mode 600). Next: cd {PLATFORM} && terraform apply")
    return 0


if __name__ == "__main__":
    sys.exit(main())
