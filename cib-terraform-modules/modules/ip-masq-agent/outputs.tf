output "daemon_set" {
  value = "${kubernetes_daemon_set_v1.ip_masq_agent.metadata[0].namespace}/${kubernetes_daemon_set_v1.ip_masq_agent.metadata[0].name}"
}
