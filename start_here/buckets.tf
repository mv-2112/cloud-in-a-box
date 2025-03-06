resource "openstack_objectstorage_container_v1" "terraform_bucket" {
  region          = "RegionOne"
  name            = "terraform"
  # versioning      = true
  container_read  = ".r:*"
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

