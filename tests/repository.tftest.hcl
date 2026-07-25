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
