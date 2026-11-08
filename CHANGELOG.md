# Changelog

All notable changes to this module are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses
[Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- `cleanup_policies` input: cleanup policies keyed by policy id, each with an
  `action` (`DELETE` or `KEEP`) and either a `condition` or
  `most_recent_versions`. Validated at plan time, including a check that
  rejects a `DELETE` policy matching every version.
- `cleanup_policy_dry_run` input, `true` by default, so declared policies do
  not delete anything until it is set to `false`. Left unset on the repository
  when no policies are declared, so existing repositories plan no change.

### Changed

- The minimum `hashicorp/google` provider version is now `5.14`, the first
  release with `cleanup_policies` and `cleanup_policy_dry_run` in the GA
  provider.

## [1.1.0] - 2026-11-05

### Changed

- CI: bump actions to their current majors, pin tool versions, and restrict the
  workflow token to `contents: read`.
- CI: add Dependabot for GitHub Actions and the Terraform provider.
- Docs: pin the README usage `source` to a release tag; fix the LICENSE year.

## [1.0.0] - 2026-07-26

### Added

- Customer-managed encryption (`kms_key_name`) and Docker immutable tags
  (`immutable_tags`).
- Plan-only test suite using `mock_provider`.

### Fixed

- `format` validation now accepts every Artifact Registry format and is
  case-insensitive.

Initial release (`v0.1.0` points at the same commit).

[Unreleased]: https://github.com/moveeeax/terraform-google-artifact-registry/compare/v1.1.0...HEAD
[1.1.0]: https://github.com/moveeeax/terraform-google-artifact-registry/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/moveeeax/terraform-google-artifact-registry/releases/tag/v1.0.0
