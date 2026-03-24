# Existing Infrastructure Documentation Index

This file catalogs all existing documentation related to CCCL infrastructure (CI, CMake, GHA, benchmarking, devcontainers, release).

## Root-Level Documents

| Path | Topic | Status |
|------|-------|--------|
| `AGENTS.md` | Agent/developer instructions: build tools, CI overview, repo structure, SASS diffs | **Current** — recently created, comprehensive |
| `ci-overview.md` | CI environment, matrix testing, sccache, artifacts, workflow details, troubleshooting | **Mostly current** — some minor staleness (see tracker) |
| `CONTRIBUTING.md` | Contributor guide: fork/clone, building, testing, presets, pre-commit, CI, review | **Mostly current** — references ci-overview.md for CI details |
| `README.md` | Project overview, getting started, platform support, versioning | **Current** |
| `CLAUDE.md` | Stub pointing to AGENTS.md | **Current** |

## Development Container Docs

| Path | Topic | Status |
|------|-------|--------|
| `.devcontainer/README.md` | Dev container setup: VSCode, WSL, Docker quickstarts, sccache auth | **Mostly current** — container variant list may be stale |

## Docs Directory — Maintainer Section

| Path | Topic | Status |
|------|-------|--------|
| `docs/maintainers/index.rst` | Maintainer docs index (toctree for how_tos and references) | **Current** but sparse |
| `docs/maintainers/branching_strategy.rst` | Git methodology: canonical branches, tagging conventions | **Current** |
| `docs/maintainers/backport_process.rst` | How to backport fixes to release branches | **Current** |
| `docs/maintainers/how_tos/index.rst` | How-to index (only links backport_process) | **Incomplete** — needs more entries |
| `docs/maintainers/references/index.rst` | References index (only links branching_strategy) | **Incomplete** — needs more entries |

## Docs Directory — Development Section

| Path | Topic | Status |
|------|-------|--------|
| `docs/cccl/development/index.rst` | Development guide index (macros, testing, build/bisect tools) | **Current** |
| `docs/cccl/development/build_and_bisect_tools.rst` | build_and_test_targets.sh and git_bisect.sh usage and examples | **Current** |
| `docs/cccl/development/testing.rst` | %PARAM% test variant system, CMake variant functions | **Current** |
| `docs/cccl/development/macro.rst` | CCCL internal macros | **Current** (not infra-focused) |
| `docs/cccl/development/visibility/` | Device kernel visibility (3+ files) | **Current** (not infra-focused) |

## Docs Directory — Component-Specific

| Path | Topic | Status |
|------|-------|--------|
| `docs/cub/developer_overview.rst` | CUB architecture: thread/warp/block/device layers | **Current** (not infra-focused) |
| `docs/cub/test_overview.rst` | CUB test framework: Catch2, C2H helpers | **Current** |
| `docs/cub/benchmarking.rst` | NVBench benchmarks: building, running, comparing | **Current** |
| `docs/cub/tuning.rst` | CUB performance tuning infrastructure | **Current** |
| `docs/thrust/developer_overview.rst` | Thrust internal architecture | **Current** (not infra-focused) |

## CI/Build Source Comments

| Path | Topic | Status |
|------|-------|--------|
| `ci/matrix.yaml` (comments) | Override matrix examples, workflow semantics | **Current** |
| `ci/build_common.sh` (header/usage) | Build script options, examples | **Current** |
| `CMakeLists.txt` (comments) | Build options, policy notes | **Current** |
| `CMakePresets.json` | Preset definitions (self-documenting) | **Current** |

## GitHub Actions Docs

| Path | Topic | Status |
|------|-------|--------|
| `.github/actions/workflow-build/action.yml` | Action inputs/outputs for matrix parsing | **Current** (self-documenting) |
| `.github/workflows/release-README.md` | Release workflow documentation | **Not reviewed** |

## Undocumented Areas (no existing docs)

- `ci/util/artifacts/` — artifact staging/upload/download system
- `ci/util/workflow/` — workflow job query scripts
- `ci/inspect_changes.py` — change detection and dependency graph (only mentioned in AGENTS.md)
- `ci/windows/` — Windows CI scripts
- `cmake/*.cmake` modules — no module-level docs beyond inline comments
- `.github/actions/workflow-run-job-*/` — job execution actions
- `.github/actions/workflow-results/` — results aggregation
- `benchmarks/scripts/cccl/bench/` — benchmark framework internals
- Release automation workflows (`.github/workflows/release-*.yml`)
- `.devcontainer/make_devcontainers.sh` — container generation
- `.devcontainer/launch.sh` — only documented in AGENTS.md and ci-overview.md
