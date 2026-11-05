output "summary" {
  value = {
    domain_id  = openstack_identity_project_v3.domain.id
    projects   = { for k, v in openstack_identity_project_v3.project : k => v.id }
    user       = openstack_identity_user_v3.builder_admin.name
    people     = { for k, v in local.users : k => v.persona }
    repository = var.github_enabled ? github_repository.tenant[0].html_url : null
    state      = module.state_bucket.grantee_bucket_name
    shared_sgs = keys(var.shared_security_group_ids)
  }
}

output "runner_auth" {
  sensitive = true
  value = {
    os_auth_url            = var.keystone_url
    os_user_domain_name    = var.domain
    os_project_domain_name = var.domain
    os_project_name        = openstack_identity_project_v3.project[local.primary_project].name
    os_username            = openstack_identity_user_v3.builder_admin.name
    os_password            = random_password.builder_admin.result
  }
}

output "initial_passwords" {
  description = "Username => first-login password. Hand over out of band; users must change it."
  sensitive   = true
  value       = { for k, v in random_password.user : k => v.result }
}

output "groups" {
  value = { for k, v in openstack_identity_group_v3.persona : k => v.name }
}
