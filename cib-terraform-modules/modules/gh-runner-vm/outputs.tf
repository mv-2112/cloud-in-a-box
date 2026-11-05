output "name" {
  value = openstack_compute_instance_v2.runner.name
}

output "ip" {
  value = openstack_compute_instance_v2.runner.access_ip_v4
}

output "labels" {
  value = var.labels
}

output "check_boot" {
  value = "openstack console log show ${openstack_compute_instance_v2.runner.name} | grep -i runner"
}
