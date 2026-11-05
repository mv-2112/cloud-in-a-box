variable "admin_domain" {
  description = "Sunbeam's admin domain (OS_USER_DOMAIN_NAME in admin_openrc)."
  type        = string
  default     = "admin_domain"
}

variable "admin_project" {
  description = "Sunbeam's admin project (OS_PROJECT_NAME in admin_openrc)."
  type        = string
  default     = "admin"
}

variable "region" {
  type    = string
  default = "RegionOne"
}

variable "cloud_name" {
  description = "Name of this cloud where several share a router (CLOUD_NAME in bootstrap/site.env, default the host's short name). Written by render_manifest.py."
  type        = string
  default     = null
}

variable "s3_endpoint" {
  description = "Public RGW endpoint: openstack endpoint list --service s3 --interface public"
  type        = string
}

variable "rgw_project_namespacing" {
  description = "MicroCeph charm `namespace-projects` (set at deploy time, default false)."
  type        = bool
  default     = false
}

variable "external_network" {
  description = "Name of the external (VM access) network. Tenants and modules find it by this name."
  type        = string
  default     = "external-network"
}

variable "external_network_config" {
  description = <<-EOT
    The VM access network: provider network on physnet1 (the NIC/VLAN given in
    bootstrap/site.env). Written to site.auto.tfvars.json by
    bootstrap/render_manifest.py, so it always matches what Sunbeam was told.
  EOT
  type = object({
    cidr            = string
    gateway         = string
    range           = string # floating IP pool, "start-end"
    network_type    = string # flat | vlan
    segmentation_id = optional(number)
    ipv6_cidr       = optional(string) # the VLAN's /64 (stable ULA); null = IPv4 only
    ipv6_gateway    = optional(string) # the upstream router on it
  })
}

variable "tenant_ipv6_pool" {
  description = "IPv6 prefix carved into a /64 per tenant network (TENANT_V6_POOL in bootstrap/site.env). null = no tenant IPv6."
  type        = string
  default     = null
}

variable "management_ip_version" {
  description = "Management/API family from bootstrap/site.env (single-stack: 4 or 6). Informational; written by render_manifest.py."
  type        = number
  default     = 4

  validation {
    condition     = contains([4, 6], var.management_ip_version)
    error_message = "management_ip_version is 4 or 6."
  }
}

variable "flavors" {
  description = "Public flavors. Same names and sizes as Sunbeam's demo setup, which is switched off."
  type = map(object({
    vcpus   = number
    ram_mb  = number
    disk_gb = number
  }))
  default = {
    "m1.tiny"   = { vcpus = 1, ram_mb = 512, disk_gb = 4 }
    "m1.small"  = { vcpus = 1, ram_mb = 2048, disk_gb = 30 }
    "m1.medium" = { vcpus = 2, ram_mb = 4096, disk_gb = 60 }
    "m1.large"  = { vcpus = 4, ram_mb = 8192, disk_gb = 90 }
  }
}

variable "base_images" {
  description = "General-purpose images published publicly to all tenants."
  type = map(object({
    url         = string
    os_distro   = string
    disk_format = optional(string, "qcow2")
    decompress  = optional(bool, false)
    properties  = optional(map(string), {})
  }))
  default = {
    "ubuntu-24.04" = {
      url       = "https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
      os_distro = "ubuntu"
    }
  }
}

# For Magnum CAPI images. Naming upstream is in this style:
# ubuntu-jammy-kubernetes-1-31-1-1742226216.qcow2
variable "k8s_templates" {
  type = map(object({
    coe_os_image        = string
    dns_servers         = list(string)
    glance_kube_version = string
    flavor              = optional(string, "m1.medium")
    master_flavor       = optional(string, "m1.medium")
    # Octavia driver for the cluster's load balancers (API + LoadBalancer
    # Services). amphora: a small VM per load balancer; supports source
    # ranges, TLS/L7 and health monitors. ovn: no VMs and instant, but none
    # of those, and only the SOURCE_IP_PORT algorithm.
    octavia_provider = optional(string, "amphora")
  }))

  validation {
    condition     = alltrue([for t in values(var.k8s_templates) : contains(["amphora", "ovn"], t.octavia_provider)])
    error_message = "octavia_provider must be \"amphora\" or \"ovn\"."
  }

  default = {
    "v1.35.0" = {
      coe_os_image        = "https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
      dns_servers         = ["8.8.8.8", "8.8.4.4"]
      glance_kube_version = "v1.35.0"
    }
  }
}

variable "shared_security_groups" {
  description = "Platform-owned security groups that can be shared into tenant projects."
  type = map(object({
    description = string
    rules = list(object({
      direction        = optional(string, "ingress")
      ethertype        = optional(string, "IPv4")
      protocol         = optional(string)
      port_range_min   = optional(number)
      port_range_max   = optional(number)
      remote_ip_prefix = optional(string)
      description      = optional(string)
    }))
  }))

  default = {
    "egress-all" = {
      description = "Allow all outbound traffic"
      rules = [
        { direction = "egress", ethertype = "IPv4" },
        { direction = "egress", ethertype = "IPv6" },
      ]
    }
    # SSH from private address space only (your lab LAN), never the internet.
    # Narrow further to your admin subnet if you can.
    "ssh" = {
      description = "SSH from private networks (RFC 1918, IPv6 ULA)"
      rules = [
        { protocol = "tcp", port_range_min = 22, port_range_max = 22, remote_ip_prefix = "10.0.0.0/8" },
        { protocol = "tcp", port_range_min = 22, port_range_max = 22, remote_ip_prefix = "172.16.0.0/12" },
        { protocol = "tcp", port_range_min = 22, port_range_max = 22, remote_ip_prefix = "192.168.0.0/16" },
        # IPv6: ULA only (fd00::/8 covers the lab's fd18:aaa8:47c3::/48 and HomeLAN's fd00:50::/64), never global
        { protocol = "tcp", port_range_min = 22, port_range_max = 22, remote_ip_prefix = "fd00::/8", ethertype = "IPv6" },
      ]
    }
    "web" = {
      description = "HTTP and HTTPS from anywhere (IPv4 and IPv6)"
      rules = [
        { protocol = "tcp", port_range_min = 80, port_range_max = 80, remote_ip_prefix = "0.0.0.0/0" },
        { protocol = "tcp", port_range_min = 443, port_range_max = 443, remote_ip_prefix = "0.0.0.0/0" },
        { protocol = "tcp", port_range_min = 80, port_range_max = 80, remote_ip_prefix = "::/0", ethertype = "IPv6" },
        { protocol = "tcp", port_range_min = 443, port_range_max = 443, remote_ip_prefix = "::/0", ethertype = "IPv6" },
      ]
    }
    "icmp" = {
      description = "ICMP and ICMPv6 from anywhere"
      rules = [
        { protocol = "icmp", remote_ip_prefix = "0.0.0.0/0" },
        # ICMPv6 carries more than ping (neighbour discovery, path MTU); IPv6 breaks subtly without it
        { protocol = "ipv6-icmp", remote_ip_prefix = "::/0", ethertype = "IPv6" },
      ]
    }
  }
}

variable "share_security_groups_with_all" {
  description = "Share every core security group with all projects, rather than per tenant via cib-tenants."
  type        = bool
  default     = false
}

# ---- Cloud CA ----

variable "cloud_ca_cert_pem" {
  description = <<-EOT
    CA that signs the cloud's TLS endpoints (Sunbeam self-signed TLS). Trusted
    by the platform runner pods and handed to cib-tenants for tenant runners.
    admin_openrc points OS_CACERT at it:
      export TF_VAR_cloud_ca_cert_pem="$(cat "$OS_CACERT")"
  EOT
  type        = string
  default     = null
}

# ---- Admin Magnum cluster (admin_cluster.tf) ----

variable "admin_cluster" {
  description = "Platform Kubernetes cluster in the admin project (runs the platform runner and Backstage). null = none."
  type = object({
    kubernetes_version = optional(string) # defaults to the first k8s_templates key
    master_count       = optional(number, 1)
    node_count         = optional(number, 2)
  })
  default = {}
}

variable "platform_ingress_ip" {
  description = "Fixed floating IP for the admin cluster's ingress (Traefik), so DNS names like Backstage's stay put across rebuilds. Outside the floating IP pool, so nothing else takes it. PLATFORM_INGRESS_IP in bootstrap/site.env; written by render_manifest.py. null = Octavia picks a random one."
  type        = string
  default     = null
}
