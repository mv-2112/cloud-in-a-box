# cloud-in-a-box

Four repos, all in the **same GitHub organization** (not a personal account:
tenant repos, GitHub Apps and Backstage's catalog all hang off the org).
**Create and push all four first**; pushing deploys nothing. They're then
*applied* in a different order, below.

| Repo | What | Push | Apply |
|---|---|---|---|
| `cib-terraform-modules` | shared Terraform modules, tagged `v1.1.1`; **public** | 1st (tag it) | never: the others use it |
| `cib-tenant-template` | GitHub template every tenant repo is created from (mark it a template) | 2nd | never: tenant repos are created from it |
| `cib-tenants` | tenant definitions + provisioning pipeline | 3rd (the platform runners and their GitHub App attach to it) | last, on the platform runners |
| `cib-undercloud` | Sunbeam install, platform objects, admin cluster, platform runners, Backstage | 4th | from the Sunbeam host, before `cib-tenants` |

First, point all four repos at your org:

```bash
./set-org.py <your-org> --dry-run   # preview
./set-org.py <your-org>             # checks it's an org, then rewrites module sources + tfvars examples
```

It rewrites whatever org is there now (the `YOUR_ORG` placeholder the first
time), so re-running with a different name is safe. Then follow
`cib-terraform-modules/README.md` to create and push the first repo. After that:

- `MIGRATION.md`: the full bring-up sequence, and where everything from the old repo went
- `SECURITY.md`: security review, fixes and what's left
