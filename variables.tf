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
  description = "Artifact format stored in the repository."
  type        = string
  default     = "DOCKER"

  validation {
    condition     = contains(["DOCKER", "MAVEN", "NPM", "PYTHON", "APT", "YUM", "GO", "KFP"], var.format)
    error_message = "format must be one of DOCKER, MAVEN, NPM, PYTHON, APT, YUM, GO or KFP."
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
