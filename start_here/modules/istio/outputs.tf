output "revision" {
  value = var.istio_version
}

output "istiod_name" {
  value = helm_release.istiod.name
}

output "ingress_enabled" {
  value = var.enable_ingress
}

output "ambient_enabled" {
  value = local.is_ambient
}