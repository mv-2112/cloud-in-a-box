resource "openstack_objectstorage_container_v1" "terraform_bucket" {
  region = "RegionOne"
  name   = "terraform"
  # versioning      = true
  container_read = ".r:*,.rlistings"
  container_write = ""
}


# resource "openstack_objectstorage_account_v1" "builder_container_account" {
#   region     = "RegionOne"
#   project_id = openstack_identity_project_v3.builder.id

#   # metadata = {
#   #   Temp-Url-Key = "testkey"
#   #   test         = "true"
#   # }
# }




resource "openstack_objectstorage_container_v1" "build_container" {
  for_each = var.sites
  region   = "RegionOne"
  name     = "${openstack_identity_project_v3.domain[each.key].name}-bucket-1"

  #   versioning_legacy {
  #     type     = "versions"
  #     location = "tf-test-container-versions"
  #   }

  # versioning = true

  container_read  = ".r:-${openstack_identity_user_v3.domain_user[each.key].name},.rlistings"
  container_write = openstack_identity_user_v3.domain_user[each.key].name
}


# resource "openstack_objectstorage_account_v1" "builder_container_account" {
#   for_each   = var.sites
#   region     = "RegionOne"
#   project_id = openstack_identity_project_v3.builder[each.key].id

#   # metadata = {
#   #   Temp-Url-Key = "testkey"
#   #   test         = "true"
#   # }
# }