locals {
  # The Artifact Registry API stores the format as an upper-case enum and
  # echoes it back that way. Normalising here lets callers pass "docker"
  # without provoking a permanent diff on every subsequent plan.
  format = upper(var.format)

  # readers and writers are shorthands for the two roles almost every caller
  # needs; iam covers the rest. Keyed by role and member so the same grant
  # listed twice (e.g. in writers and in iam) collapses into one resource.
  iam_members = merge(
    { for m in var.readers : "roles/artifactregistry.reader/${m}" => { role = "roles/artifactregistry.reader", member = m } },
    { for m in var.writers : "roles/artifactregistry.writer/${m}" => { role = "roles/artifactregistry.writer", member = m } },
    merge([
      for role, members in var.iam : {
        for m in members : "${role}/${m}" => { role = role, member = m }
      }
    ]...),
  )
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

  # Cleanup policies delete artifacts permanently, so none exist unless the
  # caller declares them. While any are declared, cleanup_policy_dry_run
  # follows var.cleanup_policy_dry_run (true by default: the policies are
  # evaluated and logged but nothing is deleted). With no policies it stays
  # null, so repositories that never used cleanup policies see no diff.
  cleanup_policy_dry_run = length(var.cleanup_policies) > 0 ? var.cleanup_policy_dry_run : null

  dynamic "cleanup_policies" {
    for_each = var.cleanup_policies

    content {
      id     = cleanup_policies.key
      action = cleanup_policies.value.action

      dynamic "condition" {
        for_each = cleanup_policies.value.condition == null ? [] : [cleanup_policies.value.condition]

        content {
          tag_state             = condition.value.tag_state
          tag_prefixes          = condition.value.tag_prefixes
          version_name_prefixes = condition.value.version_name_prefixes
          package_name_prefixes = condition.value.package_name_prefixes
          older_than            = condition.value.older_than
          newer_than            = condition.value.newer_than
        }
      }

      dynamic "most_recent_versions" {
        for_each = cleanup_policies.value.most_recent_versions == null ? [] : [cleanup_policies.value.most_recent_versions]

        content {
          package_name_prefixes = most_recent_versions.value.package_name_prefixes
          keep_count            = most_recent_versions.value.keep_count
        }
      }
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

# Additive grants only (iam_member, never iam_binding or iam_policy), so
# principals granted outside this module are left alone and the module cannot
# wipe an existing repository policy.
resource "google_artifact_registry_repository_iam_member" "this" {
  for_each = local.iam_members

  project    = google_artifact_registry_repository.this.project
  location   = google_artifact_registry_repository.this.location
  repository = google_artifact_registry_repository.this.repository_id
  role       = each.value.role
  member     = each.value.member
}
