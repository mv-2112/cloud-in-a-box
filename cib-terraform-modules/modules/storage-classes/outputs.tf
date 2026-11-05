output "storage_classes" {
  value = keys(kubernetes_storage_class_v1.cinder)
}

output "default_class" {
  value = var.default_class
}
