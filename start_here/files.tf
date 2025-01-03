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



# 00 infra build files

resource "local_file" "main_builder_terraform" {
  for_each = var.sites
  content = templatefile("templates/00_infra/builder_cluster.tftpl", { SITE = each.key, CLUSTER_TEMPLATE_ID = openstack_containerinfra_clustertemplate_v1.clustertemplate_1.id })
  filename = "../${each.key}/00_infra/main.tf"
}

resource "local_file" "infra_provider" {
  for_each = var.sites
  content = templatefile("templates/00_infra/provider.tftpl", { SITE = each.key, CLUSTER_TEMPLATE_ID = openstack_containerinfra_clustertemplate_v1.clustertemplate_1.id })
  filename = "../${each.key}/00_infra/provider.tf"
}

resource "local_file" "infra_variables" {
  for_each = var.sites
  content = templatefile("templates/00_infra/variables.tftpl", { SITE = each.key, CLUSTER_TEMPLATE_ID = openstack_containerinfra_clustertemplate_v1.clustertemplate_1.id })
  filename = "../${each.key}/00_infra/variables.tf"
}

resource "local_file" "infra_networks" {
  for_each = var.sites
  content = templatefile("templates/00_infra/networks.tftpl", { SITE = each.key, SAFE_SITE = replace(each.key, ".", "_"), CLUSTER_TEMPLATE = openstack_containerinfra_clustertemplate_v1.clustertemplate_1.name })
  filename = "../${each.key}/00_infra/networks.tf"
}

resource "local_file" "infra_outputs" {
  for_each = var.sites
  content = file("templates/00_infra/outputs.tftpl")
  filename = "../${each.key}/00_infra/outputs.tf"
}

resource "local_file" "infra_kubeconfig" {
  for_each = var.sites
  content = file("templates/00_infra/kubeconfig.tftpl")
  filename = "../${each.key}/00_infra/kubeconfig.tf"
}


# 10 infra config files

resource "local_file" "infra_config_storage_classes" {
  for_each = var.sites
  content = templatefile("templates/10_infra_config/storage_classes.tftpl", { SITE = each.key, CLUSTER_TEMPLATE_ID = openstack_containerinfra_clustertemplate_v1.clustertemplate_1.id })
  filename = "../${each.key}/10_infra_config/storage_classes.tf"
}

# resource "local_file" "infra_config_volume_types" {
#   for_each = var.sites
#   content = templatefile("templates/10_infra_config/volume_types.tftpl", { SITE = each.key, CLUSTER_TEMPLATE_ID = openstack_containerinfra_clustertemplate_v1.clustertemplate_1.id })
#   filename = "../${each.key}/10_infra_config/volume_types.tf"
# }

resource "local_file" "infra_config_provider" {
  for_each = var.sites
  content = templatefile("templates/10_infra_config/provider.tftpl", { SITE = each.key, CLUSTER_TEMPLATE_ID = openstack_containerinfra_clustertemplate_v1.clustertemplate_1.id })
  filename = "../${each.key}/10_infra_config/provider.tf"
}

resource "local_file" "infra_config_variables" {
  for_each = var.sites
  content = templatefile("templates/10_infra_config/variables.tftpl", { SITE = each.key, CLUSTER_TEMPLATE_ID = openstack_containerinfra_clustertemplate_v1.clustertemplate_1.id })
  filename = "../${each.key}/10_infra_config/variables.tf"
}





# 40 app deploy


resource "local_file" "app_deploy_jenkins" {
  for_each = var.sites
  content = templatefile("templates/40_app_deploy/jenkins.tftpl", { SITE = each.key, CLUSTER_TEMPLATE_ID = openstack_containerinfra_clustertemplate_v1.clustertemplate_1.id })
  filename = "../${each.key}/40_app_deploy/jenkins.tf"
}

resource "local_file" "app_deploy_provider" {
  for_each = var.sites
  content = templatefile("templates/40_app_deploy/provider.tftpl", { SITE = each.key, CLUSTER_TEMPLATE_ID = openstack_containerinfra_clustertemplate_v1.clustertemplate_1.id })
  filename = "../${each.key}/40_app_deploy/provider.tf"
}

resource "local_file" "app_deploy_outputs" {
  for_each = var.sites
  content = file("templates/40_app_deploy/outputs.tftpl")
  filename = "../${each.key}/40_app_deploy/outputs.tf"
}



# 45 app config - Jenkins

resource "local_file" "app_config_jenkins_haproxy_fragment" {
  for_each = var.sites
  content = file("templates/45_app_config_jenkins/haproxy.cfg.fragment")
  filename = "../${each.key}/45_app_config_jenkins/haproxy.cfg.fragment"
}

resource "local_file" "app_config_jenkins_haproxy_setup" {
  for_each = var.sites
  content = file("templates/45_app_config_jenkins/setup_haproxy.sh")
  filename = "../${each.key}/45_app_config_jenkins/setup_haproxy.sh"
}
