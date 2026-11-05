output "revision" {
  value = var.istio_version
}

output "istiod_name" {
  value = helm_release.istiod.name
}

output "gateway_enabled" {
  value = var.enable_gateway
}

output "ambient_enabled" {
  value = var.enable_ambient
}