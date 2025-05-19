resource "random_password" "password" {
  for_each = var.sites
  length   = 16
  special  = false
}




resource "openstack_identity_user_v3" "domain_user" {
  for_each           = var.sites
  default_project_id = openstack_identity_project_v3.builder[each.key].id
  name               = "builder-admin"
  description        = "Admin user for builder in ${openstack_identity_project_v3.domain[each.key].name}"
  domain_id          = openstack_identity_project_v3.domain[each.key].id

  #   password = "abc123"
  password = random_password.password[each.key].result

  ignore_change_password_upon_first_use = true
}




# Builder groups

resource "openstack_identity_group_v3" "domain_admin_group" {
  for_each    = var.sites
  name        = "${each.key}_admin_group"
  description = "${each.key} Admin group"
  domain_id   = openstack_identity_project_v3.domain[each.key].id
}

# Builder group membership
resource "openstack_identity_user_membership_v3" "domain_admin_user_membership" {
  for_each = var.sites
  user_id  = openstack_identity_user_v3.domain_user[each.key].id
  group_id = openstack_identity_group_v3.domain_admin_group[each.key].id
}

# Add admin to group membership
resource "openstack_identity_user_membership_v3" "admin_membership" {
  for_each = var.sites
  user_id  = data.openstack_identity_user_v3.uber_admin.id
  group_id = openstack_identity_group_v3.domain_admin_group[each.key].id
}


# builder group assignment to domain
resource "openstack_identity_inherit_role_assignment_v3" "builder_domain_admin_role_assignment" {
  for_each = var.sites
  group_id = openstack_identity_group_v3.domain_admin_group[each.key].id
  # project_id = openstack_identity_project_v3.builder[each.key].id
  role_id   = data.openstack_identity_role_v3.admin.id
  domain_id = openstack_identity_project_v3.domain[each.key].id
}

# builder load-balancer_member assignment to domain
resource "openstack_identity_inherit_role_assignment_v3" "builder_domain_load-balancer_member_role_assignment" {
  for_each = var.sites
  group_id = openstack_identity_group_v3.domain_admin_group[each.key].id
  # project_id = openstack_identity_project_v3.builder[each.key].id
  role_id   = data.openstack_identity_role_v3.load-balancer_member.id
  domain_id = openstack_identity_project_v3.domain[each.key].id
}

# builder heat_stack_user assignment to domain
resource "openstack_identity_inherit_role_assignment_v3" "builder_domain_heat_stack_user_role_assignment" {
  for_each = var.sites
  group_id = openstack_identity_group_v3.domain_admin_group[each.key].id
  # project_id = openstack_identity_project_v3.builder[each.key].id
  role_id   = data.openstack_identity_role_v3.heat_stack_user.id
  domain_id = openstack_identity_project_v3.domain[each.key].id
}




resource "openstack_identity_group_v3" "domain_manager_group" {
  for_each    = var.sites
  name        = "${each.key}_manager_group"
  description = "${each.key} Manager group"
  domain_id   = openstack_identity_project_v3.domain[each.key].id
}

# Builder group membership
resource "openstack_identity_user_membership_v3" "domain_manager_user_membership" {
  for_each = var.sites
  user_id  = openstack_identity_user_v3.domain_user[each.key].id
  group_id = openstack_identity_group_v3.domain_manager_group[each.key].id
}

# Add admin to group membership
resource "openstack_identity_user_membership_v3" "manager_membership" {
  for_each = var.sites
  user_id  = data.openstack_identity_user_v3.uber_admin.id
  group_id = openstack_identity_group_v3.domain_manager_group[each.key].id
}

# builder group assignment to domain
resource "openstack_identity_inherit_role_assignment_v3" "builder_domain_manager_role_assignment" {
  for_each = var.sites
  group_id = openstack_identity_group_v3.domain_manager_group[each.key].id
  # project_id = openstack_identity_project_v3.builder[each.key].id
  role_id   = data.openstack_identity_role_v3.manager.id
  domain_id = openstack_identity_project_v3.domain[each.key].id
}



# # builder group assignment to builder project
# resource "openstack_identity_inherit_role_assignment_v3" "builder_project_role_assignment" {
#   for_each   = var.sites
#   group_id   = openstack_identity_group_v3.domain_group[each.key].id
#   project_id = openstack_identity_project_v3.builder[each.key].id
#   role_id    = data.openstack_identity_role_v3.admin.id
#   # domain_id   = openstack_identity_project_v3.domain[each.key].id
# }
