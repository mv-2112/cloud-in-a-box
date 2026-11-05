variable "s3_endpoint" {
  description = "Public RGW endpoint (same as stage 1)."
  type        = string
}

variable "kubeconfig" {
  description = "The admin cluster's kubeconfig, written by ../tools/admin-kubeconfig.sh."
  type        = string
  default     = "~/.kube/cib-platform.yaml"
}

variable "github_owner" {
  description = "GitHub org holding the cib repos."
  type        = string
}

variable "platform_runner" {
  description = "Platform runners (ARC) registered to the cib-tenants repo. Credentials: platform_runner_github_app (preferred) or platform_runner_github_token."
  type = object({
    repository  = optional(string, "cib-tenants")
    max_runners = optional(number, 3)
  })
  default = {}
}

# Credentials are separate variables so only they are secret, and so
# tools/github-apps.py can write them to github-apps.auto.tfvars.json without
# replacing the settings above.
variable "platform_runner_github_app" {
  description = "GitHub App for the platform runners (tools/github-apps.py runners creates it)."
  type = object({
    app_id          = string
    installation_id = string
    private_key     = string
  })
  default   = null
  sensitive = true

  # Easy mix-ups when copying from GitHub by hand: the Client ID (Iv23...)
  # looks like an ID but isn't the App ID.
  validation {
    condition = var.platform_runner_github_app == null || (
      can(regex("^[0-9]+$", var.platform_runner_github_app.app_id)) &&
      can(regex("^[0-9]+$", var.platform_runner_github_app.installation_id)) &&
      can(regex("-----BEGIN [A-Z ]*PRIVATE KEY-----", var.platform_runner_github_app.private_key))
    )
    error_message = "platform_runner_github_app: app_id and installation_id must be numbers (App ID from the app's General page, not the Client ID Iv23...; installation ID: not shown on any page; open github.com/organizations/<org>/settings/installations, click Configure next to the app, and take the number at the end of the URL), and private_key a PEM private key."
  }
}

variable "platform_runner_github_token" {
  description = "Fallback to a GitHub App: a PAT with repo admin on the runners' repository."
  type        = string
  default     = null
  sensitive   = true
}

variable "backstage" {
  description = "Backstage on the admin cluster. null = don't deploy. Not secret: its GitHub App credentials are in backstage_github_app."
  type = object({
    image    = optional(string, "docker.io/verranm/backstage:0.0.93")
    hostname = optional(string) # null = backstage.<cloud_name>.<dns_domain>
  })
  default = null
}

# Kept apart from `backstage` so only these are secret: a sensitive
# `backstage` made the hostname (and the deploy-or-not decision) secret too,
# which Terraform refuses for outputs and count.
variable "backstage_github_app" {
  description = "Backstage's GitHub App (sign-in and catalog). Required when backstage is set."
  type = object({
    app_id        = string
    client_id     = string
    client_secret = string
    private_key   = string
  })
  default   = null
  sensitive = true

  validation {
    condition     = var.backstage == null || var.backstage_github_app != null
    error_message = "Set backstage_github_app when deploying Backstage."
  }

  validation {
    condition = var.backstage_github_app == null || (
      can(regex("^[0-9]+$", var.backstage_github_app.app_id)) &&
      can(regex("^Iv", var.backstage_github_app.client_id)) &&
      can(regex("-----BEGIN [A-Z ]*PRIVATE KEY-----", var.backstage_github_app.private_key))
    )
    error_message = "backstage_github_app: app_id must be the numeric App ID, client_id the Client ID (Iv...), both from the app's General page; private_key a PEM private key."
  }
}

variable "dns_domain" {
  description = "Domain the router's DNS serves for the lab (RB4011_v4 src/lablan/34-dns.rsc). Platform names default to <service>.<cloud_name>.<dns_domain>."
  type        = string
  default     = "lab.home.arpa"
}
