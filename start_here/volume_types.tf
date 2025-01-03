resource "openstack_blockstorage_volume_type_v3" "multiattach" {
  name        = "multiattach"
  description = "Multiattach-enabled volume type"
  extra_specs = {
    multiattach = "<is> True"
  }
  is_public = true
}

resource "openstack_blockstorage_volume_type_v3" "standard" {
  name        = "standard"
  description = "Standard volume type"
  is_public   = true
}
