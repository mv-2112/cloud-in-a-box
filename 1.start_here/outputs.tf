output "builder_user" {
  value = [openstack_identity_user_v3.domain_user_1.name]
  sensitive = true
}

output "builder_pass" {
  value = [openstack_identity_user_v3.domain_user_1.password]
  sensitive = true
}