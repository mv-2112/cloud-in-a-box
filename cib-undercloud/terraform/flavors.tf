# Public flavors. Sunbeam's demo setup used to create these; it's off, so the
# platform owns them. Names match, so cluster templates and modules that ask
# for m1.small / m1.medium keep working.

resource "openstack_compute_flavor_v2" "flavor" {
  for_each  = var.flavors
  name      = each.key
  vcpus     = each.value.vcpus
  ram       = each.value.ram_mb
  disk      = each.value.disk_gb
  is_public = true
}
