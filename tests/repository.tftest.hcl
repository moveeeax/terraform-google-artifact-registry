# NOTE: mock_provider requires Terraform >= 1.7 / OpenTofu >= 1.7 to *run these
# tests*. The module itself still only requires >= 1.5, so consumers on 1.5/1.6
# are unaffected.
mock_provider "google" {}

variables {
  project_id    = "example-project"
  repository_id = "example-repo"
  location      = "us-central1"
}

run "defaults_are_docker_without_docker_config" {
  command = plan

  assert {
    condition     = google_artifact_registry_repository.this.format == "DOCKER"
    error_message = "format should default to DOCKER."
  }

  # docker_config must stay unset by default, otherwise every existing consumer
  # of this module would see a gratuitous diff after upgrading.
  assert {
    condition     = length(google_artifact_registry_repository.this.docker_config) == 0
    error_message = "docker_config must not be emitted when immutable_tags is false."
  }

  assert {
    condition     = google_artifact_registry_repository.this.kms_key_name == null
    error_message = "kms_key_name should default to null (Google-managed encryption)."
  }
}

run "format_is_normalised_to_upper_case" {
  command = plan

  variables {
    format = "docker"
  }

  # Without upper() the API would echo back "DOCKER" and every plan would show
  # a permanent diff.
  assert {
    condition     = google_artifact_registry_repository.this.format == "DOCKER"
    error_message = "lower-case format should be normalised to DOCKER."
  }
}

run "generic_format_is_accepted" {
  command = plan

  variables {
    format = "GENERIC"
  }

  assert {
    condition     = google_artifact_registry_repository.this.format == "GENERIC"
    error_message = "GENERIC is a supported Artifact Registry format and must not be rejected."
  }
}

run "googet_format_is_accepted" {
  command = plan

  variables {
    format = "GOOGET"
  }

  assert {
    condition     = google_artifact_registry_repository.this.format == "GOOGET"
    error_message = "GOOGET is a supported Artifact Registry format and must not be rejected."
  }
}

run "rejects_unknown_format" {
  command = plan

  variables {
    format = "HELM"
  }

  expect_failures = [var.format]
}

run "immutable_tags_emits_docker_config" {
  command = plan

  variables {
    immutable_tags = true
  }

  assert {
    condition     = length(google_artifact_registry_repository.this.docker_config) == 1
    error_message = "docker_config should be emitted when immutable_tags is true."
  }

  assert {
    condition     = google_artifact_registry_repository.this.docker_config[0].immutable_tags
    error_message = "immutable_tags should be true on the emitted docker_config block."
  }
}

# The API rejects docker_config on non-Docker repositories at apply time. The
# precondition turns that into a plan-time failure.
run "immutable_tags_on_non_docker_fails_at_plan" {
  command = plan

  variables {
    format         = "MAVEN"
    immutable_tags = true
  }

  expect_failures = [google_artifact_registry_repository.this]
}

run "cmek_key_is_passed_through" {
  command = plan

  variables {
    kms_key_name = "projects/example-project/locations/us-central1/keyRings/ar/cryptoKeys/repo"
  }

  assert {
    condition     = google_artifact_registry_repository.this.kms_key_name == "projects/example-project/locations/us-central1/keyRings/ar/cryptoKeys/repo"
    error_message = "kms_key_name should be forwarded to the repository resource."
  }
}

run "rejects_bare_kms_key_name" {
  command = plan

  variables {
    kms_key_name = "repo"
  }

  expect_failures = [var.kms_key_name]
}

run "labels_and_description_are_forwarded" {
  command = plan

  variables {
    description = "Container images for the platform team"
    labels      = { env = "prod" }
  }

  assert {
    condition     = google_artifact_registry_repository.this.description == "Container images for the platform team"
    error_message = "description should be forwarded."
  }

  assert {
    condition     = google_artifact_registry_repository.this.labels["env"] == "prod"
    error_message = "labels should be forwarded."
  }
}

# Existing callers must see no cleanup configuration after upgrading: no
# policies and cleanup_policy_dry_run left unset.
run "no_cleanup_policies_by_default" {
  command = plan

  assert {
    condition     = length(google_artifact_registry_repository.this.cleanup_policies) == 0
    error_message = "No cleanup policies should be emitted by default."
  }

  assert {
    condition     = google_artifact_registry_repository.this.cleanup_policy_dry_run == null
    error_message = "cleanup_policy_dry_run must stay null when no cleanup policies are declared."
  }
}

run "cleanup_policies_default_to_dry_run" {
  command = plan

  variables {
    cleanup_policies = {
      "delete-untagged" = {
        action = "DELETE"
        condition = {
          tag_state  = "UNTAGGED"
          older_than = "604800s"
        }
      }
      "keep-recent" = {
        action = "KEEP"
        most_recent_versions = {
          keep_count = 10
        }
      }
      "keep-release" = {
        action = "KEEP"
        condition = {
          tag_state    = "TAGGED"
          tag_prefixes = ["v"]
        }
      }
    }
  }

  assert {
    condition     = google_artifact_registry_repository.this.cleanup_policy_dry_run == true
    error_message = "cleanup_policy_dry_run should default to true once policies are declared."
  }

  assert {
    condition     = length(google_artifact_registry_repository.this.cleanup_policies) == 3
    error_message = "Every declared cleanup policy should be emitted."
  }

  assert {
    condition = one([
      for p in google_artifact_registry_repository.this.cleanup_policies : p.condition[0].tag_state
      if p.id == "delete-untagged"
    ]) == "UNTAGGED"
    error_message = "condition fields should be forwarded."
  }

  assert {
    condition = one([
      for p in google_artifact_registry_repository.this.cleanup_policies : p.most_recent_versions[0].keep_count
      if p.id == "keep-recent"
    ]) == 10
    error_message = "most_recent_versions.keep_count should be forwarded."
  }
}

run "cleanup_policies_can_be_armed" {
  command = plan

  variables {
    cleanup_policy_dry_run = false
    cleanup_policies = {
      "delete-untagged" = {
        action    = "DELETE"
        condition = { tag_state = "UNTAGGED" }
      }
    }
  }

  assert {
    condition     = google_artifact_registry_repository.this.cleanup_policy_dry_run == false
    error_message = "cleanup_policy_dry_run = false should be forwarded."
  }
}

run "rejects_unknown_cleanup_action" {
  command = plan

  variables {
    cleanup_policies = {
      "p" = {
        action    = "delete"
        condition = { tag_state = "UNTAGGED" }
      }
    }
  }

  expect_failures = [var.cleanup_policies]
}

run "rejects_cleanup_policy_with_both_condition_and_most_recent_versions" {
  command = plan

  variables {
    cleanup_policies = {
      "p" = {
        action               = "KEEP"
        condition            = { tag_state = "TAGGED" }
        most_recent_versions = { keep_count = 5 }
      }
    }
  }

  expect_failures = [var.cleanup_policies]
}

run "rejects_cleanup_policy_with_neither_condition_nor_most_recent_versions" {
  command = plan

  variables {
    cleanup_policies = {
      "p" = { action = "KEEP" }
    }
  }

  expect_failures = [var.cleanup_policies]
}

run "rejects_most_recent_versions_on_delete" {
  command = plan

  variables {
    cleanup_policies = {
      "p" = {
        action               = "DELETE"
        most_recent_versions = { keep_count = 5 }
      }
    }
  }

  expect_failures = [var.cleanup_policies]
}

run "rejects_unknown_tag_state" {
  command = plan

  variables {
    cleanup_policies = {
      "p" = {
        action    = "KEEP"
        condition = { tag_state = "untagged" }
      }
    }
  }

  expect_failures = [var.cleanup_policies]
}

# An empty DELETE condition matches every version in the repository.
run "rejects_delete_policy_that_matches_everything" {
  command = plan

  variables {
    cleanup_policies = {
      "p" = {
        action    = "DELETE"
        condition = { tag_state = "ANY" }
      }
    }
  }

  expect_failures = [var.cleanup_policies]
}

run "rejects_overlong_cleanup_policy_id" {
  command = plan

  variables {
    cleanup_policies = {
      (join("", [for i in range(128) : "a"])) = {
        action    = "DELETE"
        condition = { tag_state = "UNTAGGED" }
      }
    }
  }

  expect_failures = [var.cleanup_policies]
}
