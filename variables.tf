variable "project_id" {
  description = "ID of the project in which to create the repository."
  type        = string
}

variable "repository_id" {
  description = "Unique id of the Artifact Registry repository."
  type        = string
}

variable "location" {
  description = "Location of the repository, e.g. us-central1 or us."
  type        = string
}

variable "format" {
  description = <<-EOT
    Artifact format stored in the repository. Case-insensitive; it is normalised
    to the upper-case enum the API expects. One of DOCKER, MAVEN, NPM, PYTHON,
    APT, YUM, GOOGET, GO, KFP or GENERIC.
  EOT
  type        = string
  default     = "DOCKER"

  validation {
    condition = contains(
      ["DOCKER", "MAVEN", "NPM", "PYTHON", "APT", "YUM", "GOOGET", "GO", "KFP", "GENERIC"],
      upper(var.format)
    )
    error_message = "format must be one of DOCKER, MAVEN, NPM, PYTHON, APT, YUM, GOOGET, GO, KFP or GENERIC."
  }
}

variable "description" {
  description = "Description of the repository."
  type        = string
  default     = "Managed by Terraform"
}

variable "labels" {
  description = "Labels applied to the repository."
  type        = map(string)
  default     = {}
}

variable "kms_key_name" {
  description = <<-EOT
    Fully qualified Cloud KMS key used to encrypt repository contents
    (customer-managed encryption). Leave null to use Google-managed
    encryption. This cannot be changed after the repository is created, so
    setting it on an existing repository forces replacement.
  EOT
  type        = string
  default     = null

  validation {
    condition = var.kms_key_name == null || can(regex(
      "^projects/[^/]+/locations/[^/]+/keyRings/[^/]+/cryptoKeys/[^/]+$",
      coalesce(var.kms_key_name, "")
    ))
    error_message = "kms_key_name must be a fully qualified key, e.g. projects/p/locations/l/keyRings/kr/cryptoKeys/k."
  }
}

variable "immutable_tags" {
  description = <<-EOT
    Prevent existing tags in a DOCKER repository from being modified, moved or
    deleted. Only valid when format is DOCKER. Defaults to false to match the
    API default; enabling it breaks workflows that repeatedly push a moving tag
    such as `latest`.
  EOT
  type        = bool
  default     = false
}
