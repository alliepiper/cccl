# AGENTS

This repository unifies the Thrust, CUB, and libcudacxx CUDA C++ libraries.
These notes help humans and AI agents contribute efficiently.

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

## Building and Testing
This project is very large and time consuming to build. Always identify the
smallest set of targets and test cases that reproduce your issue. When trying
new commands, consider using a fresh environment and add `-configure` to build
or test scripts to validate configuration without compiling or running tests.

Choose the option that matches your change:

- **C++/CUDA libraries (`thrust`, `cub`, `libcudacxx`):**
  ```bash
  ci/build_<library>.sh [-configure] -cxx <HOST_COMPILER> -std <CXX_STANDARD> -arch <GPU_ARCHS>
  ci/test_<library>.sh  [-configure] -cxx <HOST_COMPILER> -std <CXX_STANDARD> -arch <GPU_ARCHS>
  ```
  Add `-configure` to run only CMake configuration without compiling or
  executing tests. These scripts also expect extra tools (e.g., TBB for
  Thrust, lit for libcudacxx, and a recent CMake for CUB); ensure
  dependencies are installed or configuration will fail. Use
  `-cmake-options "<opts>"` to forward CMake definitions such as
  `-DTHRUST_MULTICONFIG_ENABLE_SYSTEM_TBB=OFF` to bypass TBB.
- **CMake presets:**
  ```bash
  cmake --preset <preset>
  cmake --build build/<preset>
  ctest --test-dir build/<preset>
  ```

### Useful CMake options
Pass additional CMake definitions via `-cmake-options "<opts>"` when using the
build or test scripts, or append `-D` flags when invoking `cmake` directly.
These can help tailor the build to available dependencies:

- `-DTHRUST_MULTICONFIG_ENABLE_SYSTEM_TBB=OFF` – disable Thrust's TBB backend to
  skip the TBB dependency.

### Targeted builds and tests
Use these techniques to compile or run highly specific pieces with verbose logs:

- **cmake preset syntax:**
  ```bash
  cmake --build --preset <preset> --target <target> -v
  ctest --preset <preset> -R <regex> -V
  ```
- **ninja directly:**
  ```bash
  ninja -C build/<preset> <target> -v
  ```
- **executables directly:**
  ```bash
  ./build/<preset>/path/to/<target> [args]  # add --verbose or -v if supported
  ```
- **ctest directly:**
  ```bash
  ctest --test-dir build/<preset> -R <regex> -V --output-on-failure
  ```
- **lit directly:**
  LIT tests require a site configuration generated in the build tree.
  Run from the repository root after building the preset.
  ```bash
  lit_site_cfg=build/<preset>/libcudacxx/test/libcudacxx/lit.site.cfg
  LIBCUDACXX_SITE_CONFIG=$lit_site_cfg \
  lit -v libcudacxx/test/libcudacxx/<path/to/test>
  ```

If required tools or hardware are unavailable, note this in the PR but do your best to run relevant tests.

## Documentation
- Sources live under `docs/`. Update docs when code changes user-facing behavior.
- Run `pre-commit` on modified docs as well.

## Commit and PR Guidelines
- Keep commits focused and messages descriptive.
- Ensure `git status` is clean before finishing.
- In PR descriptions, mention test commands and outcomes.
