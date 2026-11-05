# Platform-owned Terraform state buckets (S3 API on RGW).
#
# - cib-undercloud-tfstate: this configuration's own state
# - cib-tenants-tfstate:    state for the cib-tenants provisioner
#
# Both are owned by the admin project with no grants to anyone else. Per-tenant
# buckets are created by cib-tenants with the same module, each granting only
# that tenant's project.
#
# Replaces the old start_here "terraform" container, which was world-readable
# (container_read = ".r:*,.rlistings") while holding passwords and EC2 secrets.

module "state_bucket" {
  source   = "git::https://github.com/blackcatengineering/cib-terraform-modules.git//modules/state-bucket?ref=v1.1.1"
  for_each = toset(["cib-undercloud-tfstate", "cib-tenants-tfstate"])

  name                    = each.key
  rgw_project_namespacing = var.rgw_project_namespacing
  owner_project_id        = data.openstack_identity_project_v3.admin_project.id
  tags                    = { managed-by = "cib-undercloud" }
}
