locals {
  # The Artifact Registry API stores the format as an upper-case enum and
  # echoes it back that way. Normalising here lets callers pass "docker"
  # without provoking a permanent diff on every subsequent plan.
  format = upper(var.format)
}

resource "google_artifact_registry_repository" "this" {
  project       = var.project_id
  repository_id = var.repository_id
  location      = var.location
  format        = local.format
  description   = var.description
  labels        = var.labels

  # Customer-managed encryption key. When null the repository falls back to
  # Google-managed encryption, which is still encrypted at rest.
  kms_key_name = var.kms_key_name

  # Only emitted when immutable tags are requested, so enabling the module's
  # CMEK/description features does not produce a spurious diff for consumers
  # who never asked for docker_config.
  dynamic "docker_config" {
    for_each = var.immutable_tags ? [1] : []

    content {
      immutable_tags = true
    }
  }

  lifecycle {
    # docker_config is rejected by the API for non-Docker repositories. Catch
    # it during plan instead of letting the apply fail half-way through.
    precondition {
      condition     = !var.immutable_tags || local.format == "DOCKER"
      error_message = "immutable_tags is only supported on DOCKER repositories, but var.format is \"${var.format}\"."
    }
  }
}
