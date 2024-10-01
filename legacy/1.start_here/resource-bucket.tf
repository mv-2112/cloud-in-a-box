resource "openstack_objectstorage_container_v1" "build_container" {
  region = "RegionOne"
  name   = "${var.build_project}-bucket-1"

  #   versioning_legacy {
  #     type     = "versions"
  #     location = "tf-test-container-versions"
  #   }

  # versioning = true

  container_read  = ".r:-${openstack_identity_user_v3.domain_user_1.name},.rlistings"
  container_write = openstack_identity_user_v3.domain_user_1.name
}


resource "openstack_objectstorage_account_v1" "builder_container_account" {
  region = "RegionOne"
  project_id = openstack_identity_project_v3.builder.id

  # metadata = {
  #   Temp-Url-Key = "testkey"
  #   test         = "true"
  # }
}



resource "openstack_objectstorage_object_v1" "build_doc" {
  region         = "RegionOne"
  container_name = openstack_objectstorage_container_v1.build_container.name
  name           = "test/default.json"

  content_type = "application/json"
  source       = "./default.json"
}

resource "openstack_objectstorage_container_v1" "app_container" {
  for_each = toset(var.app_projects)
  region   = "RegionOne"
  name     = "${each.key}-bucket-1"

  # container_read  = ".r:-${each.key}-admin"
  container_read  = ".r,:${openstack_identity_user_v3.users["${each.key}-admin"].name},.rlistings"
  # container_write = ".w:${openstack_identity_user_v3.users["${each.key}-admin"].name}"
  # container_read  = ".r:-${var.username}"
  # container_write = "${data.openstack_identity_auth_scope_v3.current.project_id}:${var.username}"
}



resource "openstack_objectstorage_account_v1" "app_container_account" {
  for_each = toset(var.app_projects)
  region = "RegionOne"
  project_id = openstack_identity_project_v3.app_projects[each.key].id

  # metadata = {
  #   Temp-Url-Key = "testkey"
  #   test         = "true"
  # }
}






