# ci/util/ — CI Utility Scripts

This directory contains utility scripts for targeted builds, regression
bisection, artifact management, and workflow introspection.

## Key Files

| Path | Purpose |
|------|---------|
| `build_and_test_targets.sh` | Configure, build, and test specific CMake/Ninja/CTest/lit targets |
| `git_bisect.sh` | Automated regression bisection wrapping git bisect + build_and_test_targets.sh |
| `memmon.sh` | Memory monitoring during builds |
| `retry.sh` | Retry logic for transient failures |
| `version_compare.sh` | Semantic version comparison |
| `extract_switches.sh` | Extract CMake switches from build configuration |
| `create_mock_job_env.sh` | Create fake CI environment for local testing of artifact/workflow scripts |

## Subdirectories

### artifacts/ — CI Artifact Management

Registry-based system: uploads are staged, then bulk-uploaded when the job completes.

| Script | Purpose |
|--------|---------|
| `stage.sh` / `unstage.sh` | Build up / tear down file sets for upload |
| `upload.sh` / `download.sh` | Simple artifact upload/download (raw zip) |
| `upload_packed.sh` / `download_packed.sh` | Large artifacts (archive-in-zip, use pbzip2 for speed) |
| `upload_stage.sh` / `upload_stage_packed.sh` | Upload from staged file sets |

- All `stage.sh` calls for one artifact must use the same working directory with relative paths.
- `packed` variants are for large ephemeral artifacts (e.g., test executables between build→test jobs).
- Non-`packed` variants are for user-downloadable artifacts (e.g., Python wheels).
- Install `pbzip2` before packing to dramatically reduce compression time.

### workflow/ — Workflow Job Queries

Scripts to query the current CI workflow's job definitions and dependencies.
Only work from GitHub Actions jobs or with `create_mock_job_env.sh`.

| Script | Purpose |
|--------|---------|
| `initialize.sh` | Download and extract the workflow artifact |
| `get_job_def.sh` | Get current job's definition |
| `get_producers.sh` / `get_consumers.sh` | Query job dependency graph |
| `has_producers.sh` / `has_consumers.sh` | Check if job has dependencies |
| `get_producer_id.sh` | Find producer job's run ID (for artifact download) |
| `get_stable_job_hash.sh` | Consistent hash for artifact naming |
| `get_job_project.sh` | Determine job's project |
| `get_wheel_artifact_name.sh` | Wheel artifact naming convention |
| `common.sh` | Shared utilities |

## Conventions

- `build_and_test_targets.sh` is the **preferred way** to do targeted builds. Use `--preset` with `--build-targets` for fast iteration.
- `git_bisect.sh` accepts all `build_and_test_targets.sh` options plus `--good-ref` / `--bad-ref`.
- `-Nd` syntax for refs means "origin/main N days ago."
- Artifact scripts interact with the `workflow` artifact uploaded by the `workflow-build` GitHub Action.

## Related Documentation

- `docs/maintainers/infrastructure/ci_scripts.rst` — full architecture guide
- `docs/cccl/development/build_and_bisect_tools.rst` — usage examples
- `.agents/skills/bisect-regression.md` — step-by-step bisect procedure
- `.agents/skills/reproduce-ci-failure.md` — reproducing CI failures
