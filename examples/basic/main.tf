terraform {
  required_version = ">= 1.5"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

module "artifact_registry" {
  source = "../.."

  project_id    = var.project_id
  repository_id = "example-repo"
  location      = var.region
  format        = "DOCKER"
}

variable "project_id" {
  description = "Project ID to deploy the example repository into."
  type        = string
}

variable "region" {
  description = "Region for the google provider and repository."
  type        = string
  default     = "us-central1"
}

output "repository_name" {
  value = module.artifact_registry.name
}
