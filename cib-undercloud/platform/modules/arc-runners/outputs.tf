output "scale_set" {
  value = {
    name    = var.scale_set_name
    labels  = var.labels
    runs_on = "[${join(", ", var.labels)}]"
  }
}
