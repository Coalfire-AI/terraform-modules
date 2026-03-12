# Release Process

This document describes how to create releases and upgrade terraform-modules in consumer repositories.

## Overview

terraform-modules uses semantic versioning (`vMAJOR.MINOR.PATCH`) with GitHub releases. Consumer repositories reference specific versions via git tags, providing stable infrastructure deployments.

## Creating a Release

Releases are created via manual GitHub Actions workflow dispatch.

### Steps

1. Navigate to **Actions** > **Release** in the GitHub repository
2. Click **Run workflow**
3. Select the version bump type:
   - **patch** - Bug fixes, non-breaking changes (v1.0.0 -> v1.0.1)
   - **minor** - New features, backward-compatible changes (v1.0.0 -> v1.1.0)
   - **major** - Breaking changes (v1.0.0 -> v2.0.0)
4. Click **Run workflow**

The workflow will:
- Calculate the next version based on the latest tag
- Create and push the new git tag
- Create a GitHub release with auto-generated changelog

### Version Bump Guidelines

| Change Type | Bump | Example |
|-------------|------|---------|
| Bug fixes | patch | Fix validation error in module |
| Documentation updates | patch | Update README, add examples |
| New optional variables | minor | Add `enable_feature` variable with default |
| New module outputs | minor | Add `resource_arn` output |
| New features | minor | Add support for new AWS service |
| Variable renames | major | Rename `bucket_name` to `s3_bucket_name` |
| Variable type changes | major | Change variable from string to object |
| Removed outputs | major | Remove deprecated output |
| Resource restructuring | major | Change that requires `terraform state mv` |

## Upgrading in Consumer Repositories

### Before Upgrading

1. **Check release notes** for breaking changes
2. **Review the diff** between current and target version
3. **Plan during low-risk periods** for production environments

### Upgrade Steps

1. Update the module source reference:
   ```hcl
   # Before
   source = "git::ssh://git@github.com/Coalfire-AI/terraform-modules.git//modules/tra_infra?ref=v1.0.0"

   # After
   source = "git::ssh://git@github.com/Coalfire-AI/terraform-modules.git//modules/tra_infra?ref=v1.1.0"
   ```

2. Re-initialize Terraform to pull the new version:
   ```bash
   terraform init -upgrade
   ```

3. Review the plan for unexpected changes:
   ```bash
   terraform plan
   ```

4. Apply if changes are acceptable:
   ```bash
   terraform apply
   ```

### Handling Breaking Changes

When upgrading across major versions:

1. **Read the release notes carefully** - breaking changes are highlighted
2. **Update variable names/types** as documented
3. **Run state migrations** if required (documented in release notes)
4. **Test in non-production first** before applying to production

## Release Checklist

Before creating a release:

- [ ] All tests passing
- [ ] Documentation updated for new features
- [ ] Breaking changes documented
- [ ] CLAUDE.md updated if needed
- [ ] PR approved and merged to main

## Branching Strategy

- `main` - Stable releases only
- Feature branches for development
- Test changes via branch refs before release:
  ```hcl
  # Development/testing
  source = "...?ref=feature/my-feature"

  # Production
  source = "...?ref=v1.2.0"
  ```

## Rollback

To rollback to a previous version:

1. Update the module source to the previous version tag
2. Run `terraform init -upgrade`
3. Run `terraform plan` to review changes
4. Run `terraform apply`

## Support

For questions or issues:
- Check existing releases and changelogs
- Open an issue in the terraform-modules repository
