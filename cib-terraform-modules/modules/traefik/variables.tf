variable "chart_version" {
  type    = string
  default = "42.1.3"
}

variable "namespace" {
  type    = string
  default = "traefik"
}

variable "default_ingress_class" {
  type    = bool
  default = true
}

variable "service_annotations" {
  description = "Extra annotations on the LoadBalancer Service (e.g. Octavia/CCM options)."
  type        = map(string)
  default     = {}
}

variable "load_balancer_ip" {
  description = "Floating IP for Traefik's load balancer, created beforehand in the cluster's project (a stable address for DNS). null = Octavia picks one, which changes whenever the load balancer is recreated."
  type        = string
  default     = null
}
