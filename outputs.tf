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

output "iam_members" {
  description = "Repository-scoped IAM grants created by the module, as a list of { role, member } objects."
  value       = [for k, g in google_artifact_registry_repository_iam_member.this : { role = g.role, member = g.member }]
}
