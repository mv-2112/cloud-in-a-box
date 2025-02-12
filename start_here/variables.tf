variable "sites" {
  type = map(object({
    owner       = string
    description = string

  }))

  default = {
    "example.com" = {
      owner       = "Matt"
      description = "example.com"
    }
    # "www.example2.com" = {
    #   owner    = "Bob"
    #   description    = "www.example2.com"
    # }
  }
}


variable "k8s_templates" {
  type = map(object({
    core_os_image                  = string
    container_runtime              = string
    containerd_version             = string
    containerd_tarball_sha256      = string
    cloud_provider_tag             = string
    cinder_csi_plugin_tag          = string
    k8s_keystone_auth_tag          = string
    magnum_auto_healer_tag         = string
    octavia_ingress_controller_tag = string
    calico_tag                     = string
    octavia_provider               = string
    octavia_lb_algorithm           = string
    # Added to hopefully keep LB's live - may still not solve no traffic issue...
    octavia_lb_healthcheck = bool
  }))

  default = {
    "v1.27.8-rancher2" = {
      core_os_image                  = "38.20230806.3.0"
      container_runtime              = "containerd"
      containerd_version             = "1.6.28"
      containerd_tarball_sha256      = "f70736e52d61e5ad225f4fd21643b5ca1220013ab8b6c380434caeefb572da9b"
      cloud_provider_tag             = "v1.27.3"
      cinder_csi_plugin_tag          = "v1.27.3"
      k8s_keystone_auth_tag          = "v1.27.3"
      magnum_auto_healer_tag         = "v1.27.3"
      octavia_ingress_controller_tag = "v1.27.3"
      calico_tag                     = "v3.26.4"
      octavia_provider               = "ovn"
      octavia_lb_algorithm           = "SOURCE_IP_PORT"
      # Added to hopefully keep LB's live - may still not solve no traffic issue...
      octavia_lb_healthcheck = false
    }
    "v1.28.9-rancher1" = {
      core_os_image                  = "38.20230806.3.0"
      container_runtime              = "containerd"
      containerd_version             = "1.6.31"
      containerd_tarball_sha256      = "75afb9b9674ff509ae670ef3ab944ffcdece8ea9f7d92c42307693efa7b6109d"
      cloud_provider_tag             = "v1.27.3"
      cinder_csi_plugin_tag          = "v1.27.3"
      k8s_keystone_auth_tag          = "v1.27.3"
      magnum_auto_healer_tag         = "v1.27.3"
      octavia_ingress_controller_tag = "v1.27.3"
      calico_tag                     = "v3.26.4"
      octavia_provider               = "ovn"
      octavia_lb_algorithm           = "SOURCE_IP_PORT"
      # Added to hopefully keep LB's live - may still not solve no traffic issue...
      octavia_lb_healthcheck = false
    }
    "v1.30.5-rancher1" = {
      core_os_image                  = "38.20230806.3.0"
      container_runtime              = "containerd"
      containerd_version             = "1.6.31"
      containerd_tarball_sha256      = "75afb9b9674ff509ae670ef3ab944ffcdece8ea9f7d92c42307693efa7b6109d"
      cloud_provider_tag             = "v1.30.2"
      cinder_csi_plugin_tag          = "v1.30.2"
      k8s_keystone_auth_tag          = "v1.30.2"
      magnum_auto_healer_tag         = "v1.30.2"
      octavia_ingress_controller_tag = "v1.30.2"
      calico_tag                     = "v3.26.4"
      octavia_provider               = "ovn"
      octavia_lb_algorithm           = "SOURCE_IP_PORT"
      # Added to hopefully keep LB's live - may still not solve no traffic issue...
      octavia_lb_healthcheck = false
    }
    "v1.31.5-rancher1" = {
      core_os_image                  = "38.20230806.3.0"
      container_runtime              = "containerd"
      containerd_version             = "1.6.31"
      containerd_tarball_sha256      = "75afb9b9674ff509ae670ef3ab944ffcdece8ea9f7d92c42307693efa7b6109d"
      cloud_provider_tag             = "v1.30.2"
      cinder_csi_plugin_tag          = "v1.30.2"
      k8s_keystone_auth_tag          = "v1.30.2"
      magnum_auto_healer_tag         = "v1.30.2"
      octavia_ingress_controller_tag = "v1.30.2"
      calico_tag                     = "v3.26.4"
      octavia_provider               = "ovn"
      octavia_lb_algorithm           = "SOURCE_IP_PORT"
      # Added to hopefully keep LB's live - may still not solve no traffic issue...
      octavia_lb_healthcheck = false
    }

  }
}

variable "external_network" {
  type    = string
  default = "external-network"
}

variable "dns_servers" {
  type    = list(any)
  default = ["8.8.8.8", "8.8.4.4"]
}


variable "default_coreos_image" {
  type    = string
  default = "38.20230806.3.0"
}

variable "default_k8s_template" {
  type    = string
  default = "v1.31.5-rancher1"
}
