# .github/ — GitHub Actions & CI Configuration

This directory contains all GitHub Actions workflows, custom actions, issue
templates, and repository configuration for CCCL's CI/CD system.

## Key Files

| Path | Purpose |
|------|---------|
| `workflows/ci-workflow-pull-request.yml` | Main PR CI workflow (~250+ jobs) |
| `workflows/ci-workflow-nightly.yml` | Nightly extended test suite |
| `workflows/ci-workflow-weekly.yml` | Weekly comprehensive testing |
| `workflows/git-bisect.yml` | Remote git bisect on CI runners |
| `workflows/verify-devcontainers.yml` | Validate devcontainer configurations |
| `workflows/docs-deploy.yml` | Documentation build and deployment |
| `workflows/build-{matx,pytorch,rapids}.yml` | Third-party canary builds |
| `workflows/release-*.yml` | Release automation (create, RC, finalize, wheels) |
| `workflows/workflow-dispatch-*.yml` | Job dispatch (standalone and two-stage) |
| `workflows/backport-prs.yml` | Automated PR backporting |
| `actions/workflow-build/` | Parse `ci/matrix.yaml` → job list |
| `actions/workflow-run-job-linux/` | Execute a CI job in a Linux devcontainer |
| `actions/workflow-run-job-windows/` | Execute a CI job in a Windows devcontainer |
| `actions/workflow-results/` | Aggregate results, detect failures, generate summaries |
| `actions/docs-build/` | Build documentation site |
| `actions/upload-artifacts/` | Upload CI artifacts |
| `actions/version-update/` | Update version information |
| `copy-pr-bot.yaml` | Security: copies PR code to `pull-request/N` branch |
| `CODEOWNERS` | Code ownership and review assignments |

## CI Pipeline Flow

```
PR push → copy-pr-bot → pull-request/N branch
  → ci-workflow-pull-request.yml
    → build-workflow job (workflow-build action):
        inspect_changes.py → build-workflow.py → prepare-workflow-dispatch.py
    → dispatch jobs (workflow-dispatch-*.yml):
        → workflow-run-job-{linux,windows} per matrix entry
    → workflow-results job:
        verify-job-success.py → final-summary.py
```

## Conventions

- Workflow names use kebab-case: `ci-workflow-pull-request.yml`
- Custom actions live in `actions/<name>/action.yml`
- All workflows use `bash --noprofile --norc -euo pipefail {0}` as default shell
- Dispatch workflows come in standalone (single job) and two-stage (build→test) variants
- Linux and Windows dispatch workflows are separate files

## Warnings

- **Do not rename workflow files** without updating all references (other workflows,
  branch protection rules, CODEOWNERS).
- **copy-pr-bot.yaml** is a security-critical file — it controls which branches
  trigger CI on self-hosted runners.
- The `workflow-results` action **intentionally fails** when an override matrix
  is present in `ci/matrix.yaml`, to block merging.

## Related Documentation

- `docs/maintainers/infrastructure/ci_workflows.rst` — CI architecture guide
- `CONTRIBUTING.md` — CI section (merged from former ci-overview.md)
- `ci/AGENTS.md` — build/test scripts
- `.agents/skills/add-ci-matrix-job.md` — how to add matrix jobs
- `.agents/skills/override-ci-matrix.md` — how to use override matrix
