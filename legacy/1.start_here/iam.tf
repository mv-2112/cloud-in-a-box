# Builder users

resource "random_password" "password" {
  length  = 16
  special = false
}

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


resource "openstack_identity_role_assignment_v3" "app_project_role_assignment" {
  for_each   = toset(var.app_projects)
  group_id   = openstack_identity_group_v3.domain_group_1.id
  project_id = openstack_identity_project_v3.app_projects[each.key].id
  role_id    = data.openstack_identity_role_v3.admin.id
}


# Now... automagically create our groups and users

# We need a lookup array of this data at a later stage
data "openstack_identity_role_v3" "roles-lookup" {
  for_each = toset(var.roles)
  name     = each.key
}



# This is the structure of our user and group objects
locals {
  project_users = toset(flatten([
    for project_name, users in var.users : [
      for user_name, user in users : {
        name         = user_name
        project_name = project_name
        role         = user.role
        groups       = user.groups
      }
    ]
  ]))
  project_groups = toset(flatten([
    for project_name, groups in var.groups : [
      for group_name, group in groups : {
        name         = group_name
        project_name = project_name
        role         = group.role
        description  = group.description
      }
    ]
  ]))
}





# This is our first clever moment, take each of the elements 
# in var.groups from our locals and create group resources.
resource "openstack_identity_group_v3" "groups" {
  for_each = {
    for group in local.project_groups : "${group.name}" => group
  }
  name        = each.value.name
  description = each.value.description
  domain_id   = openstack_identity_project_v3.domain.id
}


# Similar to the above assign our users to groups
resource "openstack_identity_user_membership_v3" "group_user_membership" {
  for_each = {
    for user in local.project_users : "${user.name}" => user
  }
  user_id  = openstack_identity_user_v3.users[each.value.name].id
  group_id = openstack_identity_group_v3.groups[each.value.groups].id
}


# Assign roles to our groups using the data lookup array for the role
resource "openstack_identity_role_assignment_v3" "group_role_assignment" {
  for_each = {
    for group in local.project_groups : "${group.name}" => group
  }
  group_id   = openstack_identity_group_v3.groups[each.value.name].id
  project_id = openstack_identity_project_v3.app_projects[each.value.project_name].id
  role_id    = data.openstack_identity_role_v3.roles-lookup[each.value.role].id
}

# We need an array of passwords
resource "random_password" "user_password" {
  for_each = {
    for user in local.project_users : "${user.name}" => user
  }
  length  = 16
  special = false
}

# take each of the elements in var.users from our locals and create 
# user resources.
resource "openstack_identity_user_v3" "users" {
  for_each = {
    for user in local.project_users : "${user.name}" => user
  }

  default_project_id = openstack_identity_project_v3.app_projects[each.value.project_name].id

  name = each.value.name

  domain_id   = openstack_identity_project_v3.domain.id
  description = "${each.value.name} user for ${each.value.project_name}"
  password = random_password.user_password[each.value.name].result

  ignore_change_password_upon_first_use = true
}
