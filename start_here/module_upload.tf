resource "github_repository" "module_repo" {
  for_each    = var.modules
  name        = "tf-mod-${each.key}"
  description = each.value.description

  visibility = "public"
  auto_init  = true

  #   template {
  #     owner                = "github"
  #     repository           = "terraform-template-module"
  #     include_all_branches = true
  #   }
}




resource "github_repository_file" "module_files" {
  for_each            = { for combination in flatten([
    for k,v in var.modules: [
        for file in v.file_list : {
            key = "${k}-${file}"
            module = k
            file = file
        }
    ]
  ]) : combination.key => combination}
  repository          = github_repository.module_repo[each.value.module].name
  branch              = "main"
  file                = each.value.file
  content             = file("modules/${each.value.module}/${each.value.file}")
  commit_message      = "Managed by Terraform"
  commit_author       = "Terraform User"
  commit_email        = "builder-admin@example.com"
  overwrite_on_create = true
}

resource "github_repository_file" "module_tpl_files" {
  for_each            = { for combination in flatten([
    for k,v in var.modules: [
        for template in v.template_list: {
            key = "${k}-${template}"
            module = k
            template = template
        }
    ]
  ]) : combination.key => combination}
  repository          = github_repository.module_repo[each.value.module].name
  branch              = "main"
  file                = replace(each.value.template, ".tftpl", ".tf")
  # example git@github.com:blackcatengineering/tf-mod-builder_infra.git
  content             = templatefile("modules/${each.value.module}/${each.value.template}", { GITHUB_URL = "git@github.com:${var.github_organization}" })
  commit_message      = "Managed by Terraform"
  commit_author       = "Terraform User"
  commit_email        = "builder-admin@example.com"
  overwrite_on_create = true
}