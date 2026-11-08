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

variable "cleanup_policies" {
  description = <<-EOT
    Cleanup policies, keyed by policy id (under 128 characters). Each policy has
    an `action` of DELETE or KEEP and exactly one of:
      * `condition` - match versions by `tag_state` (TAGGED, UNTAGGED, ANY),
        `tag_prefixes`, `version_name_prefixes`, `package_name_prefixes`,
        `older_than` or `newer_than` (durations, e.g. "2592000s").
      * `most_recent_versions` - keep the newest `keep_count` versions,
        optionally per `package_name_prefixes`. KEEP only.
    KEEP policies take precedence over DELETE. A DELETE policy must set at
    least one matcher, because an empty condition matches every version in the
    repository. Defaults to no policies; deletions only happen once
    cleanup_policy_dry_run is set to false.
  EOT
  type = map(object({
    action = string
    condition = optional(object({
      tag_state             = optional(string)
      tag_prefixes          = optional(list(string))
      version_name_prefixes = optional(list(string))
      package_name_prefixes = optional(list(string))
      older_than            = optional(string)
      newer_than            = optional(string)
    }))
    most_recent_versions = optional(object({
      package_name_prefixes = optional(list(string))
      keep_count            = optional(number)
    }))
  }))
  default = {}

  validation {
    condition     = alltrue([for id, p in var.cleanup_policies : length(id) > 0 && length(id) < 128])
    error_message = "cleanup_policies keys are policy ids and must be 1 to 127 characters long."
  }

  validation {
    condition     = alltrue([for id, p in var.cleanup_policies : contains(["DELETE", "KEEP"], p.action)])
    error_message = "Each cleanup policy action must be DELETE or KEEP."
  }

  validation {
    condition = alltrue([
      for id, p in var.cleanup_policies : (p.condition == null) != (p.most_recent_versions == null)
    ])
    error_message = "Each cleanup policy must set exactly one of condition or most_recent_versions."
  }

  validation {
    condition = alltrue([
      for id, p in var.cleanup_policies : p.most_recent_versions == null || p.action == "KEEP"
    ])
    error_message = "most_recent_versions is only valid on a KEEP cleanup policy."
  }

  validation {
    condition = alltrue([
      for id, p in var.cleanup_policies :
      p.condition == null || contains(["TAGGED", "UNTAGGED", "ANY"], coalesce(try(p.condition.tag_state, null), "ANY"))
    ])
    error_message = "cleanup policy condition.tag_state must be TAGGED, UNTAGGED or ANY."
  }

  # A DELETE condition with no matcher (or only tag_state = "ANY") matches every
  # version in the repository. The API accepts it; this module does not.
  validation {
    condition = alltrue([
      for id, p in var.cleanup_policies : p.action != "DELETE" || p.condition == null || anytrue([
        !contains([null, "ANY"], try(p.condition.tag_state, null)),
        length(coalesce(try(p.condition.tag_prefixes, null), [])) > 0,
        length(coalesce(try(p.condition.version_name_prefixes, null), [])) > 0,
        length(coalesce(try(p.condition.package_name_prefixes, null), [])) > 0,
        try(p.condition.older_than, null) != null,
        try(p.condition.newer_than, null) != null,
      ])
    ])
    error_message = "A DELETE cleanup policy must set at least one of condition.tag_state (TAGGED or UNTAGGED), tag_prefixes, version_name_prefixes, package_name_prefixes, older_than or newer_than; an empty condition deletes every version."
  }
}

variable "cleanup_policy_dry_run" {
  description = <<-EOT
    Evaluate cleanup_policies without deleting anything. Defaults to true, the
    opposite of the provider default, so a new or mistaken policy can be
    reviewed before it deletes artifacts. Set to false to arm the policies. Has no effect when cleanup_policies is empty.
  EOT
  type        = bool
  default     = true
}

variable "readers" {
  description = <<-EOT
    Members granted roles/artifactregistry.reader on this repository only, e.g.
    the GKE node service account that pulls images. Members need a type prefix
    ("serviceAccount:", "group:", "user:", ...) and must be known at plan time.
  EOT
  type        = list(string)
  default     = []

  # A bare email is only rejected by the IAM API at apply time. Requiring a type
  # prefix also keeps allUsers and allAuthenticatedUsers off the repository.
  validation {
    condition     = alltrue([for m in var.readers : can(regex("^[a-zA-Z]+:.+$", m))])
    error_message = "Each member in readers must carry a type prefix, e.g. \"serviceAccount:name@project.iam.gserviceaccount.com\" or \"group:team@example.com\". allUsers and allAuthenticatedUsers are not accepted."
  }
}

variable "writers" {
  description = <<-EOT
    Members granted roles/artifactregistry.writer on this repository only, e.g.
    the CI service account that pushes images. Same member rules as readers.
  EOT
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for m in var.writers : can(regex("^[a-zA-Z]+:.+$", m))])
    error_message = "Each member in writers must carry a type prefix, e.g. \"serviceAccount:name@project.iam.gserviceaccount.com\" or \"group:team@example.com\". allUsers and allAuthenticatedUsers are not accepted."
  }
}

variable "iam" {
  description = <<-EOT
    Additional repository-scoped grants as a map of role to members, e.g.
    { "roles/artifactregistry.repoAdmin" = ["group:platform@example.com"] }.
    Roles must be predefined ("roles/...") or custom
    ("projects/<p>/roles/..." or "organizations/<o>/roles/..."). Same member
    rules as readers.
  EOT
  type        = map(list(string))
  default     = {}

  validation {
    condition = alltrue([
      for role, members in var.iam : can(regex("^(roles/|projects/[^/]+/roles/|organizations/[^/]+/roles/)[^/]+$", role))
    ])
    error_message = "Each key in iam must be a role such as \"roles/artifactregistry.repoAdmin\", \"projects/p/roles/custom\" or \"organizations/123/roles/custom\"."
  }

  validation {
    condition     = alltrue(flatten([for role, members in var.iam : [for m in members : can(regex("^[a-zA-Z]+:.+$", m))]]))
    error_message = "Each member in iam must carry a type prefix, e.g. \"serviceAccount:name@project.iam.gserviceaccount.com\" or \"group:team@example.com\". allUsers and allAuthenticatedUsers are not accepted."
  }
}
