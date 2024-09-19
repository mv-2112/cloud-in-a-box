resource "openstack_objectstorage_container_v1" "build_container" {
  region = "RegionOne"
  name   = "${var.build_project}-bucket-1"

  #   versioning_legacy {
  #     type     = "versions"
  #     location = "tf-test-container-versions"
  #   }

  # versioning = true

  container_read  = ".r:-${openstack_identity_user_v3.domain_user_1.name}"
  container_write = "${openstack_identity_user_v3.domain_user_1.name}"
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
}



