# terraform-google-artifact-registry

Terraform module that manages a [Google Cloud](https://cloud.google.com/)
Artifact Registry repository (`google_artifact_registry_repository`). It creates
a single repository of a chosen format (Docker, Maven, NPM, and more), with
optional cleanup policies and repository-scoped IAM grants.

## Usage

```hcl
module "artifact_registry" {
  source = "github.com/moveeeax/terraform-google-artifact-registry?ref=v1.0.0"

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
  source = "github.com/moveeeax/terraform-google-artifact-registry?ref=v1.0.0"

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

### Cleanup policies

```hcl
module "artifact_registry" {
  source = "github.com/moveeeax/terraform-google-artifact-registry?ref=v1.2.0"

  project_id    = var.project_id
  repository_id = "containers"
  location      = "us-central1"

  cleanup_policies = {
    # Untagged images left behind by CI after a week.
    "delete-untagged" = {
      action    = "DELETE"
      condition = { tag_state = "UNTAGGED", older_than = "604800s" }
    }
    # Always keep the newest 10 versions, whatever the rule above says.
    "keep-recent" = {
      action               = "KEEP"
      most_recent_versions = { keep_count = 10 }
    }
  }

  # Policies run in dry-run mode until this is set to false.
  # cleanup_policy_dry_run = false
}
```

Cleanup policies delete artifacts permanently, so the module creates none by
default, and once you declare some it keeps them in dry-run mode
(`cleanup_policy_dry_run = true`) until you set `cleanup_policy_dry_run = false`.
The provider's own default is `false`, meaning armed. Recommended rollout:
declare the policies, check what they would delete, then arm them.

Each policy has an `action` (`DELETE` or `KEEP`) and exactly one of
`condition` or `most_recent_versions` (`KEEP` only). KEEP policies win over
DELETE. A `DELETE` policy whose condition sets no matcher (or only
`tag_state = "ANY"`) would delete every version in the repository, so the
module rejects it at plan time.

### Repository IAM

```hcl
module "artifact_registry" {
  source = "github.com/moveeeax/terraform-google-artifact-registry?ref=v1.2.0"

  project_id    = var.project_id
  repository_id = "containers"
  location      = "us-central1"

  readers = ["serviceAccount:gke-nodes@${var.project_id}.iam.gserviceaccount.com"]
  writers = ["serviceAccount:ci@${var.project_id}.iam.gserviceaccount.com"]

  iam = {
    "roles/artifactregistry.repoAdmin" = ["group:platform@example.com"]
  }
}
```

`readers` and `writers` grant `roles/artifactregistry.reader` and
`roles/artifactregistry.writer` on this repository only, which is the
alternative to granting those roles project-wide. `iam` maps any other role to
its members. Grants are additive `google_artifact_registry_repository_iam_member`
resources, so principals granted outside the module are left alone and the
module never replaces the repository's IAM policy. Members need a type prefix
(`serviceAccount:`, `group:`, `user:`, ...), which also rejects `allUsers` and
`allAuthenticatedUsers`; a public repository has to be granted outside this
module. Members end up in `for_each` keys, so they must be known at plan time.

## Notes

- `format` is case-insensitive and normalised to upper case before it reaches
  the API, so `"docker"` and `"DOCKER"` behave identically.

## Requirements

| Name      | Version  |
|-----------|----------|
| terraform | >= 1.5   |
| google    | >= 5.14  |

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
| `cleanup_policies` | Cleanup policies keyed by policy id: `action` plus `condition` or `most_recent_versions`. See [Cleanup policies](#cleanup-policies). | `map(object)` | `{}` | no |
| `cleanup_policy_dry_run` | Evaluate cleanup policies without deleting. Ignored when `cleanup_policies` is empty.                     | `bool`        | `true`                   |    no    |
| `readers`        | Members granted `roles/artifactregistry.reader` on the repository.                                                  | `list(string)` | `[]`                   |    no    |
| `writers`        | Members granted `roles/artifactregistry.writer` on the repository.                                                  | `list(string)` | `[]`                   |    no    |
| `iam`            | Additional repository grants, role to members.                                                                      | `map(list(string))` | `{}`              |    no    |

## Outputs

| Name            | Description                        |
|-----------------|------------------------------------|
| `id`            | Identifier of the repository.     |
| `name`          | Name of the repository.           |
| `repository_id` | Repository id within the location.|
| `iam_members`   | Repository IAM grants created, as `{ role, member }` objects. |

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
