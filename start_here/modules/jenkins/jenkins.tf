locals {
  jenkins_charts_url = "https://charts.jenkins.io"
}



resource "helm_release" "jenkins" {
  repository = local.jenkins_charts_url
  chart      = "jenkins"
  name       = "jenkins"
  namespace  = "builder-system"
  create_namespace = true

  # Specify the values file for customizing the Helm chart deployment
  values = [
    file("${path.module}/jenkins_config.yaml"),                             # Path to the values file containing configuration settings
  ]

}
