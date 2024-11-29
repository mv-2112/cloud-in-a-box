# output "builder_user" {
#   value     = [openstack_identity_user_v3.domain_user[each.key].name]
#   sensitive = true
# }

# output "builder_pass" {
#   value     = [openstack_identity_user_v3.domain_user_1.password]
#   sensitive = true
# }

# resource "local_sensitive_file" "output-build-rcfile" {
#   filename        = "../auth/${var.build_project}_openrc"
#   content         = <<-EOF
# # Automagically generated rc file for ${var.build_project}
# export OS_USERNAME=${openstack_identity_user_v3.domain_user_1.name}
# export OS_PASSWORD=${openstack_identity_user_v3.domain_user_1.password}
# export OS_TENANT_NAME=${var.build_project}
# export OS_AUTH_URL=${data.openstack_identity_endpoint_v3.keystone_endpoint_1.url}
# export OS_PROJECT_DOMAIN_NAME=${var.domain}
# export OS_USER_DOMAIN_NAME=${var.domain}
# export OS_PROJECT_NAME=${var.build_project}
# export OS_IDENTITY_API_VERSION=3
# export OS_AUTH_VERSION=3
# EOF
#   file_permission = "0600"
# }


# Drop out files for each domain and builder projects

resource "local_sensitive_file" "output-app-rcfile" {
  for_each = var.sites
  filename        = "../${each.key}/builder_openrc"
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

resource "local_file" "output_builder_terraform" {
  for_each = var.sites
  content = templatefile("templates/builder_cluster.tftpl", { SITE = each.key, CLUSTER_TEMPLATE = openstack_containerinfra_clustertemplate_v1.clustertemplate_1.name })
  filename = "../${each.key}/builder/main.tf"
}

resource "local_file" "output_builder_variables" {
  for_each = var.sites
  content = templatefile("templates/variables.tftpl", { SITE = each.key, CLUSTER_TEMPLATE = openstack_containerinfra_clustertemplate_v1.clustertemplate_1.name })
  filename = "../${each.key}/builder/variables.tf"
}


resource "local_file" "output_builder_provider" {
  for_each = var.sites
  content = templatefile("templates/provider.tftpl", { SITE = each.key, CLUSTER_TEMPLATE = openstack_containerinfra_clustertemplate_v1.clustertemplate_1.name })
  filename = "../${each.key}/builder/provider.tf"
}


resource "local_file" "output_builder_network" {
  for_each = var.sites
  content = templatefile("templates/networks.tftpl", { SITE = each.key, SAFE_SITE = replace(each.key, ".", "_"), CLUSTER_TEMPLATE = openstack_containerinfra_clustertemplate_v1.clustertemplate_1.name })
  filename = "../${each.key}/builder/networks.tf"
}


resource "local_file" "output_builder_outputs" {
  for_each = var.sites
  content = templatefile("templates/outputs.tftpl", { SITE = each.key, SAFE_SITE = replace(each.key, ".", "_"), CLUSTER_TEMPLATE = openstack_containerinfra_clustertemplate_v1.clustertemplate_1.name })
  filename = "../${each.key}/builder/outputs.tf"
}


