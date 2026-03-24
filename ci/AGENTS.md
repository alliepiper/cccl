# ci/ — Build, Test, and CI Scripts

This directory contains all build/test scripts, the CI matrix definition,
change detection, and supporting utilities for CCCL's CI system.

## Key Files

| Path | Purpose |
|------|---------|
| `matrix.yaml` | Central CI job matrix — defines all test combinations for PR/nightly/weekly |
| `build_common.sh` | Shared build configuration — sourced by all per-project build scripts |
| `build_{cub,thrust,libcudacxx,cudax,...}.sh` | Per-project full build scripts |
| `test_{cub,thrust,libcudacxx,cudax,...}.sh` | Per-project full test scripts (test implies build) |
| `inspect_changes.py` | Change detection — maps file diffs to dirty projects via `project_files_and_dependencies.yaml` |
| `project_files_and_dependencies.yaml` | File→project mapping and inter-project dependency graph |
| `ninja_summary.py` | Ninja build time analysis |
| `build_common.sh` | Shared option parsing, compiler setup, cmake helpers |
| `pretty_printing.sh` | CI output formatting |
| `pyenv_helper.sh` | Python environment setup for Python builds/tests |
| `generate_version.sh` | Generate version strings from `cccl-version.json` |
| `test_python_common.sh` | Common Python test setup |
| `nvrtc_libcudacxx.sh` | NVRTC compilation for libcudacxx |
| `verify_codegen_libcudacxx.sh` | Codegen verification |

## Subdirectories

| Path | Purpose |
|------|---------|
| `util/` | Utility scripts: targeted builds, bisect, artifacts, workflow queries |
| `test/` | Tests for CI infrastructure itself (e.g., inspect_changes tests) |
| `windows/` | Windows-specific PowerShell build/test scripts |
| `matx/`, `pytorch/`, `rapids/` | Third-party canary build scripts |

## Conventions

- All per-project build scripts **source** `build_common.sh` — they don't execute it.
- Common CLI args: `-cxx <compiler>`, `-std <standard>`, `-arch <architectures>`, `-cuda <nvcc_path>`, `-cmake-options <str>`
- Test scripts take the same arguments as build scripts and will build if needed.
- `matrix.yaml` uses special values: `'all'`, `'minmax'`, `'max'` for C++ standards; unversioned compiler names (e.g., `gcc`) resolve to latest.
- The `override` workflow in `matrix.yaml` replaces `pull_request` when non-empty — **blocks merge**.
- `project: 'target'` in matrix.yaml passes `args` directly to `util/build_and_test_targets.sh`.

## Warnings

- **Full builds are expensive.** Always use targeted builds (`util/build_and_test_targets.sh`) when possible. Full builds take 60+ minutes.
- **Do not cancel running builds/tests.** Long-running operations are normal.
- **`inspect_changes.py` controls job pruning.** If you change files that aren't mapped in `project_files_and_dependencies.yaml`, the affected project may not be tested in CI.
- **`build_common.sh` must be sourced**, not executed. It checks for this and exits with an error if run directly.

## Related Documentation

- `docs/maintainers/infrastructure/ci_scripts.rst` — CI scripts architecture guide
- `docs/cccl/development/build_and_bisect_tools.rst` — build_and_test_targets.sh and git_bisect.sh reference
- `AGENTS.md` (root) — build/test usage examples
- `.agents/skills/reproduce-ci-failure.md` — reproducing CI failures locally
