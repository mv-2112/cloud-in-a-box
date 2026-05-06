# Drop out files for each domain and builder projects

resource "local_sensitive_file" "output-app-rcfile" {
  for_each        = var.sites
  filename        = "../sites/${each.key}-starter/builder_openrc"
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

# resource "local_file" "main_builder_terraform" {
#   for_each = var.sites
#   content  = templatefile("templates/main.tftpl", { SITE = each.key })
#   filename = "../sites/${each.key}/main.tf"
# }

# resource "local_file" "main_variables" {
#   for_each = var.sites
#   content  = templatefile("templates/variables.tftpl", { SITE = each.key, SAFE_SITE = replace(each.key, ".", "_"), CLUSTER_TEMPLATE = openstack_containerinfra_clustertemplate_v1.clustertemplate_flannel[var.default_k8s_template].name })
#   filename = "../sites/${each.key}/variables.tf"
# }


resource "local_sensitive_file" "output-aws-config" {
  for_each        = var.sites
  filename        = "../sites/${each.key}-starter/aws_config"
  content         = <<-EOF
[default]
region = RegionOne
endpoint_url = ${data.openstack_identity_endpoint_v3.s3_endpoint.url}
services = ${each.key}-builder

[profile ${each.key}-builder-admin]
region = RegionOne
output = json
services = ${each.key}-builder

[services ${each.key}-builder]
s3 =
  endpoint_url = ${data.openstack_identity_endpoint_v3.s3_endpoint.url}
  signature_version = s3v4

s3api =
  endpoint_url = ${data.openstack_identity_endpoint_v3.s3_endpoint.url}
EOF
  file_permission = "0600"
}

resource "local_sensitive_file" "output-aws-credentials" {
  for_each        = var.sites
  filename        = "../sites/${each.key}-starter/aws_credentials"
  content         = <<-EOF
[default]
aws_access_key_id = ${openstack_identity_ec2_credential_v3.domain_user_ec2_key[each.key].access}
aws_secret_access_key = ${openstack_identity_ec2_credential_v3.domain_user_ec2_key[each.key].secret}
[${each.key}-builder-admin]
aws_access_key_id = ${openstack_identity_ec2_credential_v3.domain_user_ec2_key[each.key].access}
aws_secret_access_key = ${openstack_identity_ec2_credential_v3.domain_user_ec2_key[each.key].secret}

EOF
  file_permission = "0600"
}