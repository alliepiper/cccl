How to Reproduce a CI Failure Locally
=====================================

When to use
-----------

A CI job has failed on your pull request and you need to reproduce the failure
in a local environment for debugging.

Prerequisites
-------------

- Docker installed and running
- NVIDIA Container Toolkit installed (for GPU tests)
- NVIDIA GPU and driver (for GPU tests only — build-only failures do not require a GPU)
- The CCCL repository cloned locally

Steps
-----

1. **Find the failing job's environment and command.**

   Open the failing CI job's log in GitHub Actions. Near the top of the log,
   look for the devcontainer image (CUDA version + host compiler) and the
   build/test command. The CI failure summary usually includes a reproducer
   block with the exact commands.

2. **Launch the matching devcontainer.**

   Use ``launch.sh`` with the ``-d`` (Docker, no VSCode) flag and the same
   CUDA toolkit and host compiler as the CI job:

   .. code-block:: bash

      .devcontainer/launch.sh -d --cuda 13.1 --host gcc14 --gpus all

   This drops you into an interactive shell inside the container. The repo is
   mounted at the same path.

   .. note::

      First launch pulls the container image and may take several minutes.
      Subsequent launches reuse the cached image.

3. **Run the build/test command from the CI log.**

   For full project builds:

   .. code-block:: bash

      ./ci/build_cub.sh -cxx g++ -std 20 -arch "90"
      ./ci/test_cub.sh -cxx g++ -std 20 -arch "90"

   For targeted builds (faster):

   .. code-block:: bash

      ci/util/build_and_test_targets.sh \
        --preset cub-cpp20 \
        --build-targets "cub.cpp20.test.iterator" \
        --ctest-targets "cub.cpp20.test.iterator"

4. **Alternatively, run the command directly without entering the container.**

   Pass the command after ``--`` to execute it non-interactively:

   .. code-block:: bash

      .devcontainer/launch.sh -d --cuda 13.1 --host gcc14 --gpus all -- \
        ci/util/build_and_test_targets.sh \
          --preset cub-cpp20 \
          --build-targets "cub.cpp20.test.iterator" \
          --ctest-targets "cub.cpp20.test.iterator"

Troubleshooting
---------------

- **Container fails to start:** Ensure Docker is running and the NVIDIA
  Container Toolkit is installed. Run ``docker run --rm --gpus all nvidia/cuda:13.1.1-devel-ubuntu22.04 nvidia-smi``
  to verify GPU access.

- **Build succeeds locally but fails in CI:** Check that you are using the
  same CUDA toolkit version and host compiler. CI may use architecture flags
  that differ from the preset defaults — look for ``-arch`` or
  ``-DCMAKE_CUDA_ARCHITECTURES`` in the CI log.

- **Test requires a GPU you don't have:** Some tests require specific GPU
  architectures (e.g., H100 / SM 90). If you lack the hardware, focus on
  reproducing the build and ask a maintainer to run the test.

See also
--------

- :doc:`../infrastructure/devcontainers` — devcontainer architecture and launch.sh reference
- :doc:`../infrastructure/ci_scripts` — build and test script details
