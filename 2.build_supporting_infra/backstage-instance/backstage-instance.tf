
data "openstack_images_image_v2" "ubuntu" {
  name        = var.image
  most_recent = true
}

resource "random_password" "backstage_password" {
  length  = 16
  special = false
}


resource "openstack_compute_instance_v2" "backstage-instance" {
  name            = "${var.project}-backstage"
  image_name      = var.image
  flavor_name     = var.flavour
  key_pair        = "${var.project}-keypair"
  security_groups = ["${var.project}-backstage-secgroup"]
  #security_groups = ["${var.project}-backstage-secgroup", "${openstack_networking_secgroup_v2.backstage-secgroup.id}"]

  block_device {
    uuid                  = data.openstack_images_image_v2.ubuntu.id
    source_type           = "image"
    destination_type      = "local"
    boot_index            = 0
    delete_on_termination = true
  }

  user_data = templatefile("${path.module}/backstage.userdata", { project = var.project,
    domain                    = var.domain,
    BACKSTAGE_PASSWORD        = random_password.backstage_password.result,
    EXTERNAL_ADDRESS          = var.lb_floating_ip
    GITHUB_PAT                = var.github_pat,
    AUTH_GITHUB_CLIENT_ID     = var.auth_github_client_id,
    AUTH_GITHUB_CLIENT_SECRET = var.auth_github_client_secret
    }
  )

  network {
    name = "${var.project}-${var.domain}-network"
    # name = "external-network"

  }
}


# resource "openstack_blockstorage_volume_v3" "backstage-datavol" {
#   name = "backstage-datavol"
#   size = 10
# }


# resource "openstack_compute_volume_attach_v2" "attached" {
#   instance_id = "${openstack_compute_instance_v2.backstage-instance.id}"
#   volume_id   = "${openstack_blockstorage_volume_v3.backstage-datavol.id}"
# }
