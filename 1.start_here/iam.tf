# Builder users

resource "openstack_identity_user_v3" "domain_user_1" {
  default_project_id = openstack_identity_project_v3.builder.id
  name               = "${var.build_project}-admin"
  description        = "Admin user for ${var.build_project}"
  domain_id          = openstack_identity_project_v3.domain.id

#   password = "abc123"
  password = random_password.password.result

  ignore_change_password_upon_first_use = true
}


# Builder groups

resource "openstack_identity_group_v3" "domain_group_1" {
  name        = "${var.domain}_admin_group"
  description = "${var.domain} Admin group"
  domain_id   = openstack_identity_project_v3.domain.id
}

# Builder group membership

resource "openstack_identity_user_membership_v3" "domain_user_membership_1" {
  user_id  = openstack_identity_user_v3.domain_user_1.id
  group_id = openstack_identity_group_v3.domain_group_1.id
}

# builder group assignment
resource "openstack_identity_role_assignment_v3" "builder_domain_role_assignment" {
  group_id   = openstack_identity_group_v3.domain_group_1.id
  project_id = openstack_identity_project_v3.domain.id
  role_id    = data.openstack_identity_role_v3.admin.id
}
resource "openstack_identity_role_assignment_v3" "builder_project_role_assignment" {
  group_id   = openstack_identity_group_v3.domain_group_1.id
  project_id = openstack_identity_project_v3.builder.id
  role_id    = data.openstack_identity_role_v3.admin.id
}