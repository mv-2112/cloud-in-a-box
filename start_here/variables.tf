variable "modules" {
  type = map(object({
    description   = string
    file_list     = list(string)
    template_list = list(string)
  }))

  default = {
    "backstage" = {
      description   = "Cloud-in-a-box Terraform Module for Backstage"
      file_list     = []
      template_list = []
    }
    "builder_infra" = {
      description = "Cloud-in-a-box Terraform Module for Builder Infrastructure"
      file_list = [
        "variables.tf",
        "outputs.tf",
        "provider.tf"
      ]
      template_list = [
        "main.tftpl"
      ]
    }
    "cert-manager" = {
      description = "Cloud-in-a-box Terraform Module for Cert Manager"
      file_list = [
        "main.tf",
        "variables.tf",
        "outputs.tf",
        "providers.tf"
      ]
      template_list = []
    }
    "trust-manager" = {
      description = "Cloud-in-a-box Terraform Module for Trust Manager"
      file_list = [
        "main.tf",
        "variables.tf",
        "outputs.tf",
        "providers.tf"
      ]
      template_list = []
    }
    "harness" = {
      description = "Cloud-in-a-box Terraform Module for Harness"
      file_list = [
        "main.tf",
        "variables.tf",
        "providers.tf"
      ]
      template_list = []
    }
    "ip-masq-agent" = {
      description = "Cloud-in-a-box Terraform Module for IP Masq Agent"
      file_list = [
        "main.tf",
        "variables.tf",
        "outputs.tf",
        "providers.tf"
      ]
      template_list = []
    }
    "istio" = {
      description = "Cloud-in-a-box Terraform Module for Istio"
      file_list = [
        "main.tf",
        "variables.tf",
        "outputs.tf",
        "providers.tf"
      ]
      template_list = []
    }
    "jaeger" = {
      description = "Cloud-in-a-box Terraform Module for Jaeger"
      file_list = [
        "main.tf",
        "variables.tf",
        "outputs.tf",
        "providers.tf",
        "jaeger.yaml"
      ]
      template_list = []
    }
    "jenkins" = {
      description = "Cloud-in-a-box Terraform Module for Jenkins"
      file_list = [
        "jenkins.tf",
        "variables.tf",
        "providers.tf",
        "jenkins_config.yaml"
      ]
      template_list = []
    }
    "storage-classes" = {
      description = "Cloud-in-a-box Terraform Module for Storage Classes"
      file_list = [
        "main.tf",
        "variables.tf",
        "provider.tf"
      ]
      template_list = []
    }
  }
}

variable "sites" {
  type = map(object({
    owner       = string
    description = string
  }))

  default = {
    "spanglywires.ddns.net" = {
      owner       = "Matt"
      description = "spanglywires.ddns.net"
    }
    # "www.example2.com" = {
    #   owner    = "Bob"
    #   description    = "www.example2.com"
    # }
  }
}



# For Magnum CAPI images until i can roll my own. These are at least Vexxhost
# https://static.atmosphere.dev/artifacts/magnum-cluster-api/
# Naming is in this style: ubuntu-jammy-kubernetes-1-31-1-1742226216.qcow2 
variable "k8s_templates" {
  type = map(object({
    coe_os_image        = string
    dns_servers         = list(string)
    glance_kube_version = string
  }))

  default = {
    "v1.32.8" = {
      coe_os_image        = "https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
      dns_servers         = ["8.8.8.8", "8.8.4.4"]
      glance_kube_version = "v1.32.8"
    }
  }
}

variable "github_token" {
  type        = string
  default     = "ghp_???????" # Replace with your actual GitHub token
  description = "GitHub token for accessing the repository"
}

variable "github_organization" {
  type        = string
  default     = "your_org_here"
  description = "GitHub organization for the repository"
}

variable "external_network" {
  type    = string
  default = "external-network"
}


variable "default_k8s_template" {
  type    = string
  default = "v1.32.8"
}
