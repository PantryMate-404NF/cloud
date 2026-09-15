output "namespace" {
  value = helm_release.keda.namespace
}

output "release_name" {
  value = helm_release.keda.name
}