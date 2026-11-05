output "ingress_ip" {
  description = "Traefik's Octavia load balancer: the router's DNS points platform names here."
  value       = module.addons.ingress_load_balancer_ip
}

output "dns_records" {
  description = "Names to add to the router's DNS (RB4011_v4 src/lablan/34-dns.rsc), pointing at ingress_ip."
  value       = compact([local.backstage_hostname])
}

output "backstage_github_callback_url" {
  description = "The Backstage GitHub App's callback URL must be exactly this."
  value       = local.backstage_hostname != null ? "https://${local.backstage_hostname}/api/auth/github/handler/frame" : null
}

output "runners" {
  value = module.runners.scale_set
}

output "backstage_url" {
  value = var.backstage != null ? module.backstage[0].url : null
}
