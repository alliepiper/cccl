# CCCL Infrastructure Documentation Areas

Hierarchical index of infrastructure systems to document.
Ordered by widest developer audience first.

**Legend:** existing = docs exist and are current | partial = some docs exist | stale = docs exist but need updating | none = no docs

---

## 1. Developer Workflow

| # | Area | Existing Docs |
|---|------|---------------|
| 1.1 | Pre-commit Hooks & Code Formatting | existing — CONTRIBUTING.md |
| 1.2 | Testing Patterns (%PARAM% variants, Catch2, lit) | existing — docs/cccl/development/testing.rst, docs/cub/test_overview.rst |
| 1.3 | Documentation Build & Preview | partial — CONTRIBUTING.md mentions skip-docs |

## 2. Development Containers

| # | Area | Existing Docs |
|---|------|---------------|
| 2.1 | Architecture & Container Variants | partial — .devcontainer/README.md covers setup |
| 2.2 | launch.sh Usage & Options | partial — AGENTS.md, ci-overview.md |
| 2.3 | Container Generation (make_devcontainers.sh) | none |
| 2.4 | GPU Passthrough & Runtime | partial — .devcontainer/README.md |
| 2.5 | sccache Integration & GitHub Auth | existing — .devcontainer/README.md, ci-overview.md |
| 2.6 | Devcontainer Verification CI | none |

## 3. Build System (CMake)

| # | Area | Existing Docs |
|---|------|---------------|
| 3.1 | Project Structure & Root CMakeLists.txt | partial — inline comments only |
| 3.2 | CMake Presets (CMakePresets.json) | partial — CONTRIBUTING.md, AGENTS.md cover usage |
| 3.3 | CMake Modules (cmake/*.cmake) | none — inline comments only |
| 3.4 | Build Options & Configuration | partial — scattered across AGENTS.md, CONTRIBUTING.md |
| 3.5 | CUDA Architecture Handling | partial — AGENTS.md, CONTRIBUTING.md mention basics |
| 3.6 | Installation & Packaging | none |

## 4. CI / GitHub Actions

| # | Area | Existing Docs |
|---|------|---------------|
| 4.1 | Workflow Architecture Overview (PR / Nightly / Weekly / Dispatch) | partial — ci-overview.md, AGENTS.md |
| 4.2 | Matrix System (ci/matrix.yaml) | partial — ci-overview.md, AGENTS.md |
| 4.3 | Job Generation Pipeline (workflow-build → build-workflow.py → inspect_changes.py) | partial — AGENTS.md mentions components |
| 4.4 | Job Execution (workflow-run-job-linux/windows) | none |
| 4.5 | Results Aggregation & Failure Reporting (workflow-results) | none |
| 4.6 | CI Commit Message Controls ([skip-*] tags, override matrix) | existing — ci-overview.md, AGENTS.md |
| 4.7 | copy-pr-bot & Security Model | partial — ci-overview.md |
| 4.8 | Third-Party Canary Builds (MatX, PyTorch, RAPIDS) | none |
| 4.9 | Signed Commits & Automatic CI Triggering | existing — ci-overview.md |

## 5. CI Build & Test Scripts

| # | Area | Existing Docs |
|---|------|---------------|
| 5.1 | Script Architecture (build_common.sh, per-project wrappers) | none |
| 5.2 | Per-Project Build Scripts (ci/build_*.sh) | partial — AGENTS.md, CONTRIBUTING.md show usage |
| 5.3 | Per-Project Test Scripts (ci/test_*.sh) | partial — AGENTS.md, CONTRIBUTING.md show usage |
| 5.4 | build_and_test_targets.sh — Targeted Builds | existing — AGENTS.md, docs/cccl/development/build_and_bisect_tools.rst |
| 5.5 | git_bisect.sh — Regression Bisection | existing — docs/cccl/development/build_and_bisect_tools.rst |
| 5.6 | inspect_changes.py — Change Detection & Dependency Graph | partial — AGENTS.md mentions briefly |
| 5.7 | Artifact System (ci/util/artifacts/) | existing — ci-overview.md has good section |
| 5.8 | Workflow Job Utilities (ci/util/workflow/) | existing — ci-overview.md has good section |
| 5.9 | Windows CI Scripts (ci/windows/) | none |

## 6. Benchmarking

| # | Area | Existing Docs |
|---|------|---------------|
| 6.1 | Benchmark Framework Overview (NVBench) | partial — docs/cub/benchmarking.rst is CUB-specific |
| 6.2 | Running & Analyzing Benchmarks (benchmarks/scripts/) | partial — docs/cub/benchmarking.rst |
| 6.3 | CUB Benchmark Integration | existing — docs/cub/benchmarking.rst |
| 6.4 | Performance Regression Checking (SASS diffs) | existing — AGENTS.md, CONTRIBUTING.md |

## 7. Release & Versioning

| # | Area | Existing Docs |
|---|------|---------------|
| 7.1 | Branching Strategy | existing — docs/maintainers/branching_strategy.rst |
| 7.2 | Release Automation Workflows | partial — .github/workflows/release-README.md |
| 7.3 | Version Management (cccl-version.json, scripts) | none |
| 7.4 | Backport Process | existing — docs/maintainers/backport_process.rst |
