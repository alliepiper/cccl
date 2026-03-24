# Infrastructure Systems Map

Working reference for authoring infrastructure documentation guides.

---

## 1. Build System (CMake)

### Components
- **Root CMakeLists.txt** — Project declaration, build options, subdirectory inclusion
  - Minimum CMake 3.18 (3.21 for dev builds)
  - Policy CMP0141 for sccache PDB compatibility
  - Top-level detection (`CMAKE_SOURCE_DIR == CMAKE_CURRENT_SOURCE_DIR`)
  - 12 build options (CCCL_ENABLE_*), all OFF by default
  - Conditionally includes subdirectories based on options

- **CMakePresets.json** — Standardized configure/build/test presets
  - Version 3, requires CMake 3.21+
  - Generator: Ninja
  - Build dir: `build/${CCCL_BUILD_INFIX}/${presetName}`
  - CCCL_BUILD_INFIX set by devcontainers for toolchain isolation
  - Base preset: Release, `all-major-cccl` architectures
  - Per-project presets: libcudacxx, cub-cpp{17,20}, thrust-cpp{17,20}, cudax-cpp20, cccl-c-parallel-cpp{17,20}
  - Install presets for packaging

- **cmake/ modules** (26 files):
  - Core: CCCLUtilities, CCCLInstallRules, CCCLAddSubdir[Helper], CPM
  - Build: CCCLBuildCompilerTargets, CCCLConfigureTarget, CCCLAddExecutable
  - Validation: CCCLCheckCudaArchitectures, CCCLDevBuildChecks
  - Testing: CCCLGenerateHeaderTests, CCCLTestParams
  - Dependencies: CCCLGetDependencies, CCCLEnsureMetaTargets
  - Tooling: CCCLClangdCompileInfo, PrintCTestRunTimes, PrintNinjaBuildTimes
  - Install: cmake/install/{cccl,libcudacxx,cub,thrust,cudax}.cmake

### Key Interactions
- CMakePresets.json → CMakeLists.txt (configure options)
- cmake/CCCLTestParams.cmake ← test source files (%PARAM% comments)
- ci/build_common.sh → CMake (passes -cxx, -std, -arch options)
- Devcontainers set CCCL_BUILD_INFIX for build directory isolation

---

## 2. Development Containers

### Components
- **Container definitions** — 56+ versioned devcontainer.json files
  - CUDA versions: 12.0, 12.9, 12.9-ext, 13.0, 13.0-ext, 13.1, 13.1-ext, 99.8, 99.9
  - Compilers: gcc7-14, clang14-20, llvm15-20, nvhpc25.7/25.9
  - `-ext` variants include extended CTK libraries
  - Each sets `CCCL_BUILD_INFIX` env var for build dir isolation

- **launch.sh** (~9000 lines) — Main container launcher
  - Options: -d/--docker, --cuda, --cuda-ext, --host, --gpus, -e/--env, -v/--volume
  - `-- <script>` to run commands inside container
  - Used by CI (workflow-run-job actions) and local development

- **make_devcontainers.sh** — Generates devcontainer.json files from templates
- **cccl-entrypoint.sh / docker-entrypoint.sh** — Container initialization
- **verify_devcontainer.sh** — Validates container setup (used by CI)

### Key Interactions
- CI workflow-run-job actions → launch.sh → Docker → ci/build_*.sh or ci/test_*.sh
- launch.sh sets CCCL_BUILD_INFIX → CMakePresets.json uses it for build dir
- make_devcontainers.sh generates the 56+ variant directories
- verify-devcontainers.yml workflow validates all variants

---

## 3. CI / GitHub Actions

### Workflow Architecture
```
PR push → copy-pr-bot copies to pull-request/N branch
  → ci-workflow-pull-request.yml triggers
    → build-workflow job:
        1. Export skip flags from commit message
        2. workflow-build action:
           a. inspect_changes.py detects dirty projects
           b. build-workflow.py parses matrix.yaml, prunes jobs
           c. prepare-workflow-dispatch.py formats dispatch payload
        3. Upload workflow artifact
    → dispatch jobs (Linux/Windows, 1-stage or 2-stage):
        → workflow-run-job-{linux,windows} action per job:
           a. Download workflow artifact
           b. Launch devcontainer via launch.sh
           c. Run ci/build_*.sh or ci/test_*.sh
           d. Upload result artifacts
    → workflow-results job:
        a. Download all result artifacts
        b. verify-job-success.py checks for failures
        c. parse-job-times.py analyzes timing
        d. prepare-execution-summary.py generates summary
        e. final-summary.py writes GitHub step summary
        f. Fail workflow if override matrix present
```

### Workflow Files
| File | Trigger | Purpose |
|------|---------|---------|
| `ci-workflow-pull-request.yml` | push to `pull-request/*` | Main PR CI (~250+ jobs) |
| `ci-workflow-nightly.yml` | schedule | Extended nightly testing |
| `ci-workflow-weekly.yml` | schedule | Comprehensive weekly testing |
| `workflow-dispatch-two-stage-{linux,windows}.yml` | called by PR/nightly/weekly | Dispatches build→test job pairs |
| `workflow-dispatch-standalone-group-{linux,windows}.yml` | called by PR/nightly/weekly | Dispatches standalone jobs |
| `git-bisect.yml` | manual dispatch | Remote git bisect on runners |
| `verify-devcontainers.yml` | PR | Validates devcontainer builds |
| `docs-deploy.yml` | push to main, PR | Documentation build/deploy |
| `build-{matx,pytorch,rapids}.yml` | called by PR workflow | Third-party canary builds |
| `release-create-new.yml` | manual dispatch | Create release branch |
| `release-update-rc.yml` | manual dispatch | Update release candidate |
| `release-finalize.yml` | manual dispatch | Finalize release tag |
| `release-wheels.yml` | manual dispatch | Build/publish Python wheels |
| `backport-prs.yml` | label/comment | Automated PR backporting |
| `update-branch-version.yml` | push to release branches | Version tracking updates |
| `build-and-test-python-wheels.yml` | called | Python wheel CI |
| `project_automation_*.yml` | issues/PRs | GitHub project board automation |
| `triage_rotation.yml` | schedule | Triage team rotation |
| `blackduck-sca.yml` | schedule | Security scanning |

### Custom Actions
| Action | Purpose |
|--------|---------|
| `workflow-build/` | Parse matrix.yaml → job list (build-workflow.py, prepare-workflow-dispatch.py) |
| `workflow-run-job-linux/` | Execute single CI job in Linux devcontainer |
| `workflow-run-job-windows/` | Execute single CI job in Windows devcontainer |
| `workflow-results/` | Aggregate results, detect failures, generate summaries |
| `docs-build/` | Build documentation site |
| `upload-artifacts/` | Upload CI artifacts |
| `version-update/` | Update version information |

### Matrix System (ci/matrix.yaml)
- Declares jobs per workflow: `override`, `pull_request`, `pull_request_lite`, `nightly`, `weekly`
- Job fields: `jobs`, `project`, `ctk`, `std`, `cxx`, `gpu`, `cpu`, `sm`, `cmake_options`, `args`, `py_version`
- Special values: `'all'`, `'minmax'`, `'max'` for std; unversioned compiler names = latest
- `override` workflow replaces `pull_request` when non-empty (blocks merge)
- `pull_request_lite` used for downstream dependency smoke tests
- `project: 'target'` enables arbitrary build_and_test_targets.sh commands

### Change Detection (ci/inspect_changes.py)
- Compares commits to find changed files
- Maps files to projects via `ci/project_files_and_dependencies.yaml`
- Outputs: FULL_BUILD (dirty projects) and LITE_BUILD (downstream dependents)
- Allows build-workflow.py to skip unaffected projects

### Commit Message Controls
- `[skip-matrix]`, `[skip-vdc]`, `[skip-docs]`, `[skip-third-party-testing]`/`[skip-tpt]`
- `[skip-matx]`, `[skip-pytorch]`, `[skip-rapids]`
- All block merge until removed

### Security Model
- NVIDIA self-hosted runners via nv-gha-runners
- copy-pr-bot copies PR code to `pull-request/N` branch for security
- External contributors require `/ok to test [SHA]` from approved account
- Internal contributors with signed commits get automatic CI

---

## 4. CI Build & Test Scripts

### Architecture
```
ci/build_*.sh / ci/test_*.sh (per-project wrappers)
  └── source ci/build_common.sh (shared configuration)
        └── invokes cmake/ninja with computed options

ci/util/build_and_test_targets.sh (targeted builds)
  └── cmake --preset → ninja <targets> → ctest -R <patterns>

ci/util/git_bisect.sh (regression bisect)
  └── wraps git bisect + build_and_test_targets.sh
```

### Per-Project Scripts
- `ci/build_{cub,thrust,libcudacxx,cudax,cccl_c_parallel,cccl_c_stf,cuda_cccl_python,stdpar}.sh`
- `ci/test_{cub,thrust,libcudacxx,cudax,cccl_c_parallel,cccl_c_stf,cuda_*_python}.sh`
- All source `build_common.sh` for shared option parsing (-cxx, -std, -arch, etc.)

### build_common.sh
- Shared by all per-project scripts (sourced, not executed)
- Parses common CLI args: -cxx, -std, -cuda, -arch, -cmake-options, -configure, -v
- Sets up build environment: compiler paths, PARALLEL_LEVEL, build directories
- Provides helper functions for cmake invocation

### Utility Scripts (ci/util/)
- `build_and_test_targets.sh` — Targeted configure/build/test with preset support
- `git_bisect.sh` — Automated regression bisection
- `memmon.sh` — Memory monitoring during builds
- `retry.sh` — Retry logic for transient failures
- `version_compare.sh` — Semantic version comparison
- `extract_switches.sh` — CMake switch extraction
- `create_mock_job_env.sh` — Fake CI environment for local artifact/workflow script testing

### Artifact System (ci/util/artifacts/)
- `stage.sh` / `unstage.sh` — Build up file sets for upload
- `upload.sh` / `download.sh` — Simple artifact upload/download (raw zip)
- `upload_packed.sh` / `download_packed.sh` — Large artifacts (archive-in-zip, pbzip2)
- `upload_stage.sh` / `upload_stage_packed.sh` — Upload from staged file set
- `upload/` subdirectory: register.sh, build.sh, set_compression.sh, print_matrix.sh
- `download/` subdirectory: fetch.sh, unpack.sh
- Registry-based: uploads are staged then bulk-uploaded at job completion

### Workflow Utilities (ci/util/workflow/)
- `initialize.sh` — Download and extract workflow artifact
- `get_job_def.sh` — Get current job's definition from workflow
- `get_producers.sh` / `get_consumers.sh` — Query job dependency graph
- `has_producers.sh` / `has_consumers.sh` — Check for dependencies
- `get_producer_id.sh` — Find producer job's run ID for artifact download
- `get_stable_job_hash.sh` — Consistent job hashing for artifact naming
- `get_job_project.sh` — Determine job's project
- `get_wheel_artifact_name.sh` — Wheel artifact naming
- `common.sh` — Shared workflow utilities

### Windows Scripts (ci/windows/)
- `build_common.psm1` — PowerShell equivalent of build_common.sh
- Per-project build/test scripts in PowerShell
- GPU driver installation (`install_gpu_driver.ps1`)

### Support Scripts
- `ci/inspect_changes.py` (~23K lines) — Change detection + dependency graph
- `ci/ninja_summary.py` — Ninja build time analysis
- `ci/pretty_printing.sh` — CI output formatting
- `ci/pyenv_helper.sh` — Python environment setup
- `ci/generate_version.sh` / `ci/update_version.sh` — Version management
- `ci/nvrtc_libcudacxx.sh` — NVRTC compilation
- `ci/verify_codegen_libcudacxx.sh` — Codegen verification

---

## 5. Benchmarking

### Components
- **benchmarks/scripts/run.py** — Main benchmark runner
- **benchmarks/scripts/analyze.py** — Results analysis
- **benchmarks/scripts/compare.py** — Multi-run comparison
- **benchmarks/scripts/search.py** — Result searching
- **benchmarks/scripts/verify.py** — Benchmark verification
- **benchmarks/scripts/sol.py** — Specific test execution
- **benchmarks/scripts/submit_benchmark_job.sh** — Job submission to runners

### Framework (benchmarks/scripts/cccl/bench/)
- `cmake.py` — CMake integration for benchmark builds
- `build.py` — Build management
- `config.py` — Configuration handling
- `storage.py` — Result storage
- `bench.py` — Benchmark execution
- `logger.py` — Logging
- `score.py` — Result scoring

### CMake Integration
- `benchmarks/cmake/CCCLBenchmarkRegistry.cmake` — Benchmark registration macros
- NVBench as the underlying benchmark framework
- CUB is the primary user of benchmarks (docs/cub/benchmarking.rst)

### SASS Diff Analysis
- Documented in AGENTS.md
- Uses cuobjdump -sass for disassembly
- Normalization rules to filter noise
- Manual process: build baseline, build candidate, compare

---

## 6. Release & Versioning

### Components
- **cccl-version.json** — Single source of truth for project version
- **ci/generate_version.sh** — Generate version from json
- **ci/update_version.sh** — Update version in json
- **ci/update_rapids_version.sh** — RAPIDS-specific version updates

### Release Workflows
- `release-create-new.yml` — Create release branch from main
- `release-update-rc.yml` — Tag release candidate
- `release-finalize.yml` — Finalize release tag
- `release-wheels.yml` — Build and publish Python wheels
- `update-branch-version.yml` — Auto-update version on release branches
- `backport-prs.yml` — Automated PR backporting via labels/comments

### Branching Strategy
- `main` — Default development branch
- `branch/X.Y.x` — Release stabilization branches
- Tags: `vX.Y.Z` (release), `vX.Y.Z-rcN` (RC), `vX.Y.Z.dev` (dev start)

---

## 7. Developer Workflow

### Pre-commit
- `.pre-commit-config.yaml` — Defines hooks (clang-format, etc.)
- Required before committing; CI enforces via pre-commit.ci
- `pre-commit.ci autofix` comment available on PRs

### Testing Patterns
- **%PARAM% system** — Split large tests into multiple executables (cmake/CCCLTestParams.cmake)
- **Catch2** — CUB test framework (C2H helpers)
- **lit** — libcudacxx test framework
- **compute-sanitizer** — Memory checking via `-compute-sanitizer-memcheck` flag

### Documentation
- Sphinx-based documentation under `docs/`
- `docs-deploy.yml` — Builds and deploys on push to main
- `docs-build/` action — Builds docs
- PR preview via `[skip-docs]` control
