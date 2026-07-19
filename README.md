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

## Requirements

| Name      | Version  |
|-----------|----------|
| terraform | >= 1.5   |
| google    | >= 5.0   |

## Inputs

| Name            | Description                                              | Type          | Default                  | Required |
|-----------------|----------------------------------------------------------|---------------|--------------------------|:--------:|
| `project_id`    | ID of the project in which to create the repository.     | `string`      | n/a                      |   yes    |
| `repository_id` | Unique id of the repository.                             | `string`      | n/a                      |   yes    |
| `location`      | Location of the repository.                              | `string`      | n/a                      |   yes    |
| `format`        | Artifact format stored in the repository.               | `string`      | `"DOCKER"`               |    no    |
| `description`   | Description of the repository.                           | `string`      | `"Managed by Terraform"` |    no    |
| `labels`        | Labels applied to the repository.                       | `map(string)` | `{}`                     |    no    |

## Outputs

| Name            | Description                        |
|-----------------|------------------------------------|
| `id`            | Identifier of the repository.     |
| `name`          | Name of the repository.           |
| `repository_id` | Repository id within the location.|

## License

[MIT](LICENSE)
