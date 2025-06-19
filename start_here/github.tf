resource "github_repository" "starter_repo" {
  for_each    = var.sites
  name        = each.key
  description = each.value.description

  visibility = "public"
  auto_init = true

#   template {
#     owner                = "github"
#     repository           = "terraform-template-module"
#     include_all_branches = true
#   }
}


resource "github_repository_file" "gitignore" {
  for_each    = var.sites
  repository          = github_repository.starter_repo[each.key].name
  branch              = "main"
  file                = ".gitignore"
  content             = "**/*.tfstate"
  commit_message      = "Managed by Terraform"
  commit_author       = "Terraform User"
  commit_email        = "builder-admin@example.com"
  overwrite_on_create = true
}



# Start the modularisation - not fully in use yet
resource "github_repository_file" "main_builder_terraform" {
  for_each    = var.sites
  repository          = github_repository.starter_repo[each.key].name
  branch              = "main"
  file                = "main.tf"
  content             = templatefile("templates/main.tftpl", { SITE = each.key, GITHUB_URL = "git@github.com:${var.github_organization}" })
  commit_message      = "Managed by Terraform"
  commit_author       = "Terraform User"
  commit_email        = "builder-admin@example.com"
  overwrite_on_create = true
}

resource "github_repository_file" "main_variables" {
  for_each    = var.sites
  repository          = github_repository.starter_repo[each.key].name
  branch              = "main"
  file                = "variables.tf"
  content             = templatefile("templates/variables.tftpl", { SITE = each.key, SAFE_SITE = replace(each.key, ".", "_"), CLUSTER_TEMPLATE = openstack_containerinfra_clustertemplate_v1.clustertemplate_flannel[var.default_k8s_template].name, GITHUB_URL = "git@github.com:${var.github_organization}" })
  commit_message      = "Managed by Terraform"
  commit_author       = "Terraform User"
  commit_email        = "builder-admin@example.com"
  overwrite_on_create = true
}