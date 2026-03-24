# cmake/ — CMake Build System Modules

This directory contains CMake modules that implement CCCL's build system.
They are included by the root `CMakeLists.txt` and provide project configuration,
target setup, testing infrastructure, and installation rules.

## Key Files

### Core Infrastructure

| Path | Purpose |
|------|---------|
| `CCCLUtilities.cmake` | Common CCCL utility functions and macros |
| `CCCLInstallRules.cmake` | Installation path configuration |
| `CCCLAddSubdir.cmake` | Subdirectory management for CCCL projects |
| `CCCLAddSubdirHelper.cmake` | Helper functions for subdirectory inclusion |
| `CPM.cmake` | CPM (C++ Package Manager) for dependency fetching |

### Build Configuration

| Path | Purpose |
|------|---------|
| `CCCLBuildCompilerTargets.cmake` | Compiler target setup (flags, warnings) |
| `CCCLConfigureTarget.cmake` | Per-target configuration (standard, CUDA arch) |
| `CCCLAddExecutable.cmake` | Wrapper for adding executables with CCCL settings |
| `CCCLCheckCudaArchitectures.cmake` | Validate and normalize CUDA architecture specifications |
| `CCCLDevBuildChecks.cmake` | Developer build validation (top-level checks) |

### Testing

| Path | Purpose |
|------|---------|
| `CCCLGenerateHeaderTests.cmake` | Generate header-only compilation tests |
| `CCCLTestParams.cmake` | `%PARAM%` test variant system — splits large tests into multiple executables |

### Dependencies & Meta-targets

| Path | Purpose |
|------|---------|
| `CCCLGetDependencies.cmake` | Dependency resolution (Catch2, NVBench, etc.) |
| `CCCLEnsureMetaTargets.cmake` | Create meta-targets that aggregate sub-targets |

### Tooling

| Path | Purpose |
|------|---------|
| `CCCLClangdCompileInfo.cmake` | Generate clangd compile_commands.json integration |
| `PrintCTestRunTimes.cmake` | Analyze and print CTest execution times |
| `PrintNinjaBuildTimes.cmake` | Analyze and print Ninja build times |
| `AppendOptionIfAvailable.cmake` | Conditionally append compiler flags |
| `CCCLHideThirdPartyOptions.cmake` | Hide third-party CMake options from the UI |

### Installation

| Path | Purpose |
|------|---------|
| `install/cccl.cmake` | CCCL umbrella package installation rules |
| `install/libcudacxx.cmake` | libcudacxx installation rules |
| `install/cub.cmake` | CUB installation rules |
| `install/thrust.cmake` | Thrust installation rules |
| `install/cudax.cmake` | CUDA Experimental installation rules |

### Templates

| Path | Purpose |
|------|---------|
| `header_test.cu.in` | Template for generated header tests |
| `link_check_main.cpp` | Source file for link verification tests |

## Conventions

- Module names use `CCCL` prefix: `CCCLSomething.cmake`.
- Build options use `CCCL_ENABLE_*` or `CCCL_USE_*` prefix.
- The root `CMakeLists.txt` conditionally includes modules — not all are loaded for every build.
- `CMakePresets.json` in the repo root defines standardized preset configurations that reference these modules.

## Warnings

- **Do not modify `CPM.cmake` directly.** It is an upstream dependency manager.
  Update it by fetching a newer version from the CPM repository.
- **`CCCLTestParams.cmake`** is critical for test splitting — changes affect
  how test executables are generated across the entire project.
- **Architecture handling:** `all-major-cccl` is defined in the presets, not in
  these modules. `CCCLCheckCudaArchitectures.cmake` validates user-provided values.

## Related Documentation

- `docs/maintainers/infrastructure/cmake.rst` — CMake architecture guide
- `CMakePresets.json` (repo root) — preset definitions
- `.agents/skills/add-cmake-preset.md` — adding new presets
