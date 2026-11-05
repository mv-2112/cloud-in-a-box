output "ingress_load_balancer_ip" {
  value = var.enable_traefik ? module.traefik[0].load_balancer_ip : null
}

output "storage_classes" {
  value = var.enable_storage_classes ? module.storage_classes[0].storage_classes : []
}
