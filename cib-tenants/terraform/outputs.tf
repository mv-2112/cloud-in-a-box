output "tenants" {
  description = "Non-secret summary per tenant. Credentials go straight into the tenant's GitHub repo."
  value       = { for k, v in module.tenant : k => v.summary }
}

# Consumed by as-tenant/apply-all.sh, which applies as-tenant/ once per
# tenant authenticated as that tenant. Includes builder-admin's password,
# hence sensitive; it never leaves the platform pipeline.
output "tenant_stage_targets" {
  sensitive = true
  value = {
    for domain, t in local.tenants : domain => merge(module.tenant[domain].runner_auth, {
      enabled        = try(t.github.enabled, false)
      runner_enabled = try(t.runner.enabled, false)
      runner_flavor  = try(t.runner.flavor, "m1.small")
      repository     = try(t.github.repository, domain)
      ca_cert_pem    = data.terraform_remote_state.undercloud.outputs.cloud_ca_cert_pem
    })
  }
}

# First-login passwords for people in each tenant. Read with
#   terraform output -json initial_passwords
# and hand over out of band (not via the tenant repo). Users must change them.
output "initial_passwords" {
  sensitive = true
  value     = { for k, v in module.tenant : k => v.initial_passwords }
}
