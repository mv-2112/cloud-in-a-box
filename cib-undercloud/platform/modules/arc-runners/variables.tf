variable "github_repository_url" {
  description = "Repo the runners serve: https://github.com/<owner>/cib-tenants"
  type        = string
}

variable "github_app" {
  description = "GitHub App installed on that repo (Actions: read/write, Administration: read/write for self-hosted runners). Preferred over a PAT."
  type = object({
    app_id          = string
    installation_id = string
    private_key     = string
  })
  default   = null
  sensitive = true
}

variable "github_token" {
  description = "Fine-grained PAT with Administration read/write on the repo; used only if github_app is null."
  type        = string
  default     = null
  sensitive   = true

  validation {
    condition     = var.github_token == null ? true : length(var.github_token) > 0
    error_message = "github_token must not be empty."
  }
}

variable "scale_set_name" {
  type    = string
  default = "cib-platform"
}

variable "labels" {
  type    = list(string)
  default = ["self-hosted", "cib"]
}

variable "min_runners" {
  description = "Idle runners kept warm. 0 = pods only exist while jobs run."
  type        = number
  default     = 0
}

variable "max_runners" {
  type    = number
  default = 3
}

variable "chart_version" {
  type    = string
  default = "0.15.1"
}

variable "runner_image_tag" {
  description = "ghcr.io/actions/actions-runner tag; tags follow runner releases."
  type        = string
  default     = "2.338.2"
}

variable "ca_cert_pem" {
  type    = string
  default = null
}

variable "cluster_internal_cidrs" {
  description = "Pod and service CIDRs of the admin cluster; runner pods may not reach them. Defaults are Canonical Kubernetes'; check with `kubectl cluster-info dump | grep -m2 -E 'cluster-cidr|service-cluster-ip-range'`."
  type        = list(string)
  default     = ["10.1.0.0/16", "10.152.183.0/24"]
}
