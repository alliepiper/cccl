# Reproduce a CI Failure Locally

**Applicable areas:** `.github/`, `ci/`, `.devcontainer/`

## When to use

A CI job has failed on a pull request and you need to reproduce the failure
in a local environment for debugging.

## Prerequisites

- Docker installed and running
- NVIDIA Container Toolkit (for GPU tests)
- NVIDIA GPU + driver (for GPU tests only)

## Steps

1. **Find the failing job's environment and command** in the GitHub Actions log.
   Look for the devcontainer image (CUDA version + compiler) and the
   build/test command. The failure summary usually includes a reproducer block.

2. **Launch the matching devcontainer:**

   ```bash
   .devcontainer/launch.sh -d --cuda <VERSION> --host <COMPILER> --gpus all
   ```

   Example:
   ```bash
   .devcontainer/launch.sh -d --cuda 13.1 --host gcc14 --gpus all
   ```

3. **Run the build/test command from the CI log.** For full builds:

   ```bash
   ./ci/build_cub.sh -cxx g++ -std 20 -arch "90"
   ./ci/test_cub.sh -cxx g++ -std 20 -arch "90"
   ```

   For targeted builds (faster):

   ```bash
   ci/util/build_and_test_targets.sh \
     --preset cub-cpp20 \
     --build-targets "cub.cpp20.test.iterator" \
     --ctest-targets "cub.cpp20.test.iterator"
   ```

4. **Or run non-interactively** (launch + execute in one command):

   ```bash
   .devcontainer/launch.sh -d --cuda 13.1 --host gcc14 --gpus all -- \
     ci/util/build_and_test_targets.sh \
       --preset cub-cpp20 \
       --build-targets "cub.cpp20.test.iterator" \
       --ctest-targets "cub.cpp20.test.iterator"
   ```

## Troubleshooting

- **Container won't start:** Verify Docker + NVIDIA Container Toolkit. Test with:
  `docker run --rm --gpus all nvidia/cuda:13.1.1-devel-ubuntu22.04 nvidia-smi`
- **Passes locally, fails in CI:** Ensure same CTK version, compiler, and `-arch` flags.
- **GPU-specific test:** Some tests need specific GPUs (H100/SM90). Focus on build repro if lacking hardware.
