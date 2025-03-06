# Drop out files for each domain and builder projects

resource "local_sensitive_file" "output-app-rcfile" {
  for_each        = var.sites
  filename        = "../sites/${each.key}/builder_openrc"
  content         = <<-EOF
# Automagically generated rc file for ${each.key} builder user
export OS_USERNAME=${openstack_identity_user_v3.domain_user[each.key].name}
export OS_PASSWORD=${openstack_identity_user_v3.domain_user[each.key].password}
export OS_AUTH_URL=${data.openstack_identity_endpoint_v3.keystone_endpoint.url}
export OS_PROJECT_DOMAIN_NAME=${each.key}
export OS_USER_DOMAIN_NAME=${each.key}
export OS_PROJECT_NAME=${openstack_identity_project_v3.builder[each.key].name}
export OS_IDENTITY_API_VERSION=3
export OS_AUTH_VERSION=3
EOF
  file_permission = "0600"
}


# Start the modularisation - not fully in use yet

resource "local_file" "main_builder_terraform" {
  for_each = var.sites
  content  = templatefile("templates/main.tftpl", { SITE = each.key })
  filename = "../sites/${each.key}/main.tf"
}

resource "local_file" "main_variables" {
  for_each = var.sites
  content  = templatefile("templates/variables.tftpl", { SITE = each.key, SAFE_SITE = replace(each.key, ".", "_"), CLUSTER_TEMPLATE = openstack_containerinfra_clustertemplate_v1.clustertemplate_calico[var.default_k8s_template].name })
  filename = "../sites/${each.key}/variables.tf"
}
