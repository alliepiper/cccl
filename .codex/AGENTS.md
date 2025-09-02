# AGENTS

## Subprojects

### Thrust (`thrust/`)
Parallel algorithms library offering STL-like interfaces and backend portability across GPUs and multicore CPUs.

### CUB (`cub/`)
CUDA-specific primitives and cooperative algorithms that provide building blocks for custom, speed-of-light kernels.

### libcudacxx (`libcudacxx/`)
CUDA C++ Standard Library implementation with host/device support and abstractions for CUDA hardware features.

### CUDA Experimental (`cudax/`)
Incubator for experimental CUDA features such as asynchronous containers, launch helpers, and execution utilities.

### C Parallel API (`c/parallel/`)
C bindings exposing CCCL algorithms for integration with other languages and runtime compilation tools.

### c2h test harness (`c2h/`)
Data generation and testing utilities shared across the repository.

### Python package (`python/cuda_cccl/`)
Python bindings that expose cooperative and parallel primitives to Python users.

### Examples and benchmarks (`examples/`, `benchmarks/`)
Sample projects and performance tests demonstrating library usage and expected results.

## Search and Navigation
- Use `rg` for finding text. Avoid `grep -R` and `ls -R` which are slow on this codebase.
- Display directories with `ls` or `find` scoped to the area you need.

## Formatting and Linting
- Install [pre-commit](https://pre-commit.com/) (included in the devcontainer).
- Run linters and formatters on modified files before committing:
  ```bash
  pre-commit run --files <path/to/file> [<more/files>]
  ```
  This executes clang-format for C++/CUDA, ruff for Python, taplo-format for TOML, codespell, and mypy.

## Build and Test Tools
All subprojects are expensive to compile and test. Use helper scripts to target the smallest set of work.

### CMake Presets
Presets live in `CMakePresets.json` at the repo root. Names follow a `<project>-<cxx-std>` style such as `cub-cpp20`, `thrust-cpp17`, or `libcudacxx-cpp20`. See the file or run `cmake --list-presets` for a complete list. When a preset is used, the build tree is placed in `build/${CCCL_BUILD_INFIX}/${PRESET}`.

### `.devcontainer/launch.sh`
Launch a container configured with a specific CUDA Toolkit and host compiler. Startup is costly, assuming the agent is even able to launch docker images, so prefer local builds when possible.

Common options:
- `-d`, `--docker` – run without VSCode; required for agent use
- `--cuda <version>` – choose CUDA Toolkit version (optional; defaults to a recent release)
- `--host <compiler>` – select host compiler (optional; defaults to a recent compiler)
- `--gpus all` – expose all GPUs (omit in the agent environment, which lacks GPUs)
- `-e/--env`, `-v/--volume` – set environment variables or mount volumes
- `-- <script>` – run a script in the container after setup; arguments after `--` are passed to that script

Example:
```bash
.devcontainer/launch.sh -d --cuda 13.0 --host gcc14 -- <script> [script_args...]
```

### `ci/util/build_and_test_targets.sh`
Configures, builds, and tests selected Ninja, CTest, and lit targets. Many tests require GPUs and a CUDA driver, so execution may fail in this environment. Compiling targets still works and is the preferred approach here. Options that generally work without GPUs are `--preset`, `--cmake-options`, `--configure-override`, `--build-targets`, `--lit-precompile-tests`, and `--custom-test-cmd`.

Omitting an option skips that phase entirely; for example, leaving out `--build-targets` means nothing is built. Use either `--preset` or `--configure-override` (not both). When `--configure-override` is given, the script runs that command instead of the preset and ignores any `--cmake-options`.

### Common Options:

- `--preset <name>`
  CMake preset to configure the build.

- `--cmake-options <str>`
  Additional CMake arguments.

- `--configure-override <cmd>`
  Custom configuration command (overrides preset).

- `--build-targets "<targets>"`
  Space-separated Ninja targets to build.

- `--ctest-targets "<regex>"`
  Space-separated CTest `-R` patterns (tests may fail without GPUs).

- `--lit-precompile-tests "<paths>"`
  Compile only specified libcudacxx lit tests. Paths are relative to `libcudacxx/test/libcudacxx`.

- `--lit-tests "<paths>"`
  Execute specified libcudacxx lit tests. Paths are relative to `libcudacxx/test/libcudacxx` and may require GPUs.

- `--custom-test-cmd "<cmd>"`
  Run an arbitrary command after tests; a non-zero exit code stops the script.

### `ci/util/git_bisect.sh`
Wraps `git bisect` around the build/test helper. Accepts all options above plus:
- `--good-ref <rev>` – known good commit, tag, or `-Nd` for origin/main N days ago (defaults to latest release)
- `--bad-ref <rev>` – known bad commit, tag, or `-Nd` for origin/main N days ago (defaults to `origin/main`)

See `docs/cccl/development/build_and_bisect_tools.rst` and the script comments for complete usage information.

## Building and Testing
Invoke `ci/util/build_and_test_targets.sh` with the appropriate preset to build each library. Adjust target names to the files you are modifying to minimize build time.

- **CUB (`cub/`):**

  ```bash
  ci/util/build_and_test_targets.sh \
    --preset cub-cpp20 \
    --build-targets "cub.cpp20.test.iterator"
  ```

- **Thrust (`thrust/`):**

  ```bash
  ci/util/build_and_test_targets.sh \
    --preset thrust-cpp20 \
    --build-targets "thrust.cpp20.test.reduce"
  ```

- **libcudacxx (`libcudacxx/`):**

  Avoid the expensive `libcudacxx.cpp20.precompile.lit` target; precompile only a few lit tests at a time.

  ```bash
  ci/util/build_and_test_targets.sh \
    --preset libcudacxx-cpp20 \
    --lit-precompile-tests "std/algorithms/alg.nonmodifying/alg.any_of/any_of.pass.cpp"
  ```

- **CUDA Experimental (`cudax/`):**

  ```bash
  ci/util/build_and_test_targets.sh \
    --preset cudax-cpp20 \
    --build-targets "cudax.cpp20.test.async_buffer"
  ```

- **C Parallel API (`c/parallel/`):**

  ```bash
  ci/util/build_and_test_targets.sh \
    --preset cccl-c-parallel \
    --build-targets "cccl.c.test.reduce"
  ```

If required tools or hardware are unavailable, note this in the PR but do your best to run relevant tests.

## Documentation
- Sources live under `docs/`. Update docs when code changes user-facing behavior.
- Run `pre-commit` on modified docs as well.

## Commit and PR Guidelines
- Keep commits focused and messages descriptive.
- Ensure `git status` is clean before finishing.
- In PR descriptions, mention test commands and outcomes.
