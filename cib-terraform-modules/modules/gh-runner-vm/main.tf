# A GitHub Actions self-hosted runner VM, registered to ONE repository.
#
# Self-contained: own network, router, egress-only security group and VM, in
# whichever project the calling `openstack` provider is scoped to. Nothing
# else in that project depends on it, so a pipeline running on this runner
# can't accidentally destroy the network it's running on.
#
# The runner only makes outbound connections (GitHub, cloud APIs), so there
# are no ingress rules unless ssh_allowed_cidrs is set.

terraform {
  required_version = ">= 1.6"

  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 3.0"
    }
  }
}

data "openstack_networking_network_v2" "external" {
  name = var.external_network
}

data "openstack_images_image_v2" "image" {
  name        = var.image
  most_recent = true
}

data "openstack_compute_flavor_v2" "flavor" {
  name = var.flavor
}

resource "openstack_networking_network_v2" "runner" {
  name           = "${var.name}-network"
  admin_state_up = true
  tags           = var.tags
}

resource "openstack_networking_subnet_v2" "runner" {
  name            = "${var.name}-subnet"
  network_id      = openstack_networking_network_v2.runner.id
  cidr            = var.cidr
  ip_version      = 4
  dns_nameservers = var.dns_servers
}

resource "openstack_networking_router_v2" "runner" {
  name                = "${var.name}-router"
  external_network_id = data.openstack_networking_network_v2.external.id
  tags                = var.tags
}

resource "openstack_networking_router_interface_v2" "runner" {
  router_id = openstack_networking_router_v2.runner.id
  subnet_id = openstack_networking_subnet_v2.runner.id
}

# IPv6: a routed /64 from the platform's tenant pool, like tenant-network.
# Needed when management (and so the OpenStack APIs) is IPv6.
data "openstack_networking_subnetpool_v2" "ipv6" {
  count = var.ipv6_enabled ? 1 : 0
  name  = var.ipv6_subnetpool
}

resource "openstack_networking_subnet_v2" "ipv6" {
  count             = var.ipv6_enabled ? 1 : 0
  name              = "${var.name}-v6-subnet"
  network_id        = openstack_networking_network_v2.runner.id
  ip_version        = 6
  subnetpool_id     = data.openstack_networking_subnetpool_v2.ipv6[0].id
  prefix_length     = 64
  ipv6_ra_mode      = "slaac"
  ipv6_address_mode = "slaac"
}

resource "openstack_networking_router_interface_v2" "ipv6" {
  count     = var.ipv6_enabled ? 1 : 0
  router_id = openstack_networking_router_v2.runner.id
  subnet_id = openstack_networking_subnet_v2.ipv6[0].id
}

resource "openstack_networking_secgroup_v2" "runner" {
  name                 = "${var.name}-sg"
  description          = "GitHub runner: egress only${length(var.ssh_allowed_cidrs) > 0 ? " + SSH" : ""}"
  delete_default_rules = true
  tags                 = var.tags
}

resource "openstack_networking_secgroup_rule_v2" "egress" {
  for_each          = toset(["IPv4", "IPv6"])
  security_group_id = openstack_networking_secgroup_v2.runner.id
  direction         = "egress"
  ethertype         = each.key
}

resource "openstack_networking_secgroup_rule_v2" "ssh" {
  for_each          = toset(var.ssh_allowed_cidrs)
  security_group_id = openstack_networking_secgroup_v2.runner.id
  direction         = "ingress"
  ethertype         = strcontains(each.key, ":") ? "IPv6" : "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = each.key
}

resource "openstack_compute_keypair_v2" "runner" {
  count      = var.ssh_public_key != null ? 1 : 0
  name       = "${var.name}-key"
  public_key = var.ssh_public_key
}

resource "openstack_compute_instance_v2" "runner" {
  name            = var.name
  image_id        = data.openstack_images_image_v2.image.id
  flavor_id       = data.openstack_compute_flavor_v2.flavor.id
  key_pair        = try(openstack_compute_keypair_v2.runner[0].name, null)
  security_groups = [openstack_networking_secgroup_v2.runner.name]
  tags            = var.tags

  network {
    uuid = openstack_networking_network_v2.runner.id
  }

  block_device {
    uuid                  = data.openstack_images_image_v2.image.id
    source_type           = "image"
    destination_type      = "volume"
    volume_size           = var.disk_gb
    boot_index            = 0
    delete_on_termination = true
  }

  user_data = templatefile("${path.module}/templates/cloud-init.yaml.tftpl", {
    github_url         = var.github_repository_url
    registration_token = var.registration_token
    runner_version     = var.runner_version
    runner_labels      = join(",", var.labels)
    runner_name        = var.name
    ca_cert_pem        = var.ca_cert_pem
  })

  lifecycle {
    # The token is single-use and only read on first boot. A fresh one is
    # issued on every plan, so ignore it rather than rebuild the VM. To
    # rebuild deliberately: terraform apply -replace=<this resource>.
    ignore_changes = [user_data]
  }

  depends_on = [openstack_networking_router_interface_v2.runner, openstack_networking_router_interface_v2.ipv6]
}
