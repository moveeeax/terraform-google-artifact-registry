# terraform-google-artifact-registry

Terraform module that manages a [Google Cloud](https://cloud.google.com/)
Artifact Registry repository (`google_artifact_registry_repository`). It creates
a single repository of a chosen format (Docker, Maven, NPM, and more).

## Usage

```hcl
module "artifact_registry" {
  source = "github.com/moveeeax/terraform-google-artifact-registry"

  project_id    = var.project_id
  repository_id = "containers"
  location      = "us-central1"
  format        = "DOCKER"
}
```

A runnable example lives in [`examples/basic`](examples/basic).

### Hardened Docker repository

```hcl
module "artifact_registry" {
  source = "github.com/moveeeax/terraform-google-artifact-registry"

  project_id    = var.project_id
  repository_id = "containers"
  location      = "us-central1"
  format        = "DOCKER"

  # Encrypt repository contents with your own Cloud KMS key instead of a
  # Google-managed one. Immutable after creation.
  kms_key_name = "projects/${var.project_id}/locations/us-central1/keyRings/ar/cryptoKeys/repo"

  # Stop published tags from being moved or deleted. Incompatible with
  # workflows that repeatedly re-push a moving tag such as `latest`.
  immutable_tags = true
}
```

## Notes

- **No IAM is managed by this module.** It deliberately creates no
  `google_artifact_registry_repository_iam_*` resources, so it cannot grant
  `allUsers` / `allAuthenticatedUsers` and cannot clobber an existing IAM
  policy. Grant access separately, and prefer the non-authoritative
  `google_artifact_registry_repository_iam_member` over `..._iam_binding` or
  `..._iam_policy` — the authoritative variants silently remove every principal
  they do not list.
- **No cleanup policies are managed by this module** either. A mistaken
  `cleanup_policies` condition permanently deletes live artifacts, and the
  provider's `cleanup_policy_dry_run` defaults to `false` (deletions armed). If
  you need them, declare them alongside this module and start with
  `cleanup_policy_dry_run = true`.
- `format` is case-insensitive and normalised to upper case before it reaches
  the API, so `"docker"` and `"DOCKER"` behave identically.

## Requirements

| Name      | Version  |
|-----------|----------|
| terraform | >= 1.5   |
| google    | >= 5.0   |

## Inputs

| Name             | Description                                                                                                        | Type          | Default                  | Required |
|------------------|--------------------------------------------------------------------------------------------------------------------|---------------|--------------------------|:--------:|
| `project_id`     | ID of the project in which to create the repository.                                                               | `string`      | n/a                      |   yes    |
| `repository_id`  | Unique id of the repository.                                                                                       | `string`      | n/a                      |   yes    |
| `location`       | Location of the repository.                                                                                        | `string`      | n/a                      |   yes    |
| `format`         | Artifact format. One of `DOCKER`, `MAVEN`, `NPM`, `PYTHON`, `APT`, `YUM`, `GOOGET`, `GO`, `KFP`, `GENERIC`.         | `string`      | `"DOCKER"`               |    no    |
| `description`    | Description of the repository.                                                                                     | `string`      | `"Managed by Terraform"` |    no    |
| `labels`         | Labels applied to the repository.                                                                                  | `map(string)` | `{}`                     |    no    |
| `kms_key_name`   | Fully qualified Cloud KMS key for customer-managed encryption. `null` uses Google-managed keys. Immutable.          | `string`      | `null`                   |    no    |
| `immutable_tags` | Prevent existing tags from being moved or deleted. `DOCKER` repositories only.                                      | `bool`        | `false`                  |    no    |

## Outputs

| Name            | Description                        |
|-----------------|------------------------------------|
| `id`            | Identifier of the repository.     |
| `name`          | Name of the repository.           |
| `repository_id` | Repository id within the location.|

## Development

```sh
terraform fmt -recursive
terraform init -backend=false && terraform validate
terraform test            # mocked provider; no GCP credentials required
```

`terraform test` uses `mock_provider`, which needs Terraform/OpenTofu >= 1.7.
That is a requirement for running the test suite only — the module itself still
supports >= 1.5.

## License

[MIT](LICENSE)
