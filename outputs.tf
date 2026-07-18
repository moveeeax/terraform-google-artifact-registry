output "id" {
  description = "Identifier of the repository."
  value       = google_artifact_registry_repository.this.id
}

output "name" {
  description = "Name of the repository."
  value       = google_artifact_registry_repository.this.name
}

output "repository_id" {
  description = "Repository id within the location."
  value       = google_artifact_registry_repository.this.repository_id
}
