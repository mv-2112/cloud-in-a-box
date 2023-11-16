output "builder_user" {
  value     = [openstack_identity_user_v3.domain_user_1.name]
  sensitive = true
}

output "builder_pass" {
  value     = [openstack_identity_user_v3.domain_user_1.password]
  sensitive = true
}

resource "local_sensitive_file" "output-build-rcfile" {
  filename        = "../auth/${var.build_project}_openrc"
  content         = <<-EOF
# Automagically generated rc file for ${var.build_project}
export OS_USERNAME=${openstack_identity_user_v3.domain_user_1.name}
export OS_PASSWORD=${openstack_identity_user_v3.domain_user_1.password}
export OS_TENANT_NAME=${var.build_project}
export OS_AUTH_URL=${data.openstack_identity_endpoint_v3.keystone_endpoint_1.url}
export OS_PROJECT_DOMAIN_NAME=${var.domain}
export OS_USER_DOMAIN_NAME=${var.domain}
export OS_PROJECT_NAME=${var.build_project}
export OS_IDENTITY_API_VERSION=3
export OS_AUTH_VERSION=3
EOF
  file_permission = "0600"
}

# Drop out files for app projects

resource "local_sensitive_file" "output-app-rcfile" {
  for_each = {
    for user in local.project_users : "${user.name}" => user
  }
  filename        = "../auth/${each.key}_openrc"
  content         = <<-EOF
# Automagically generated rc file for ${each.value.project_name}
export OS_USERNAME=${openstack_identity_user_v3.users[each.value.name].name}
export OS_PASSWORD=${openstack_identity_user_v3.users[each.value.name].password}
export OS_TENANT_NAME=${each.value.project_name}
export OS_AUTH_URL=${data.openstack_identity_endpoint_v3.keystone_endpoint_1.url}
export OS_PROJECT_DOMAIN_NAME=${var.domain}
export OS_USER_DOMAIN_NAME=${var.domain}
export OS_PROJECT_NAME=${each.value.project_name}
export OS_IDENTITY_API_VERSION=3
export OS_AUTH_VERSION=3
EOF
  file_permission = "0600"
}
