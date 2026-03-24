CI Build and Test Scripts
=========================

This guide describes the shell scripts in ``ci/`` that build, test, and
support CCCL's continuous integration pipeline. The same scripts are used by
GitHub Actions runners and by developers reproducing CI results locally.

For targeted build/test usage and bisection examples aimed at contributors,
see :doc:`/cccl/development/build_and_bisect_tools`.

.. _ci-scripts-architecture:

Script Architecture -- ``build_common.sh``
------------------------------------------

:file:`ci/build_common.sh` is the foundation of the Linux CI scripts. It is
**sourced** (not executed) by every per-project build and test script.
Attempting to run it directly produces an error.

Responsibilities
~~~~~~~~~~~~~~~~

- **Option parsing** -- Provides a common CLI accepted by all per-project
  scripts: ``-cxx``, ``-std``, ``-cuda``, ``-arch``, ``-cmake-options``,
  ``-configure``, ``-v``/``-verbose``, and ``-disable-benchmarks``.
- **Compiler resolution** -- Resolves ``CXX`` and ``CUDACXX`` to absolute
  paths and validates that they exist.
- **Build directory management** -- Creates
  ``build/$CCCL_BUILD_INFIX/<preset>`` trees and maintains ``build/latest``
  and ``build/preset-latest`` symlinks.
- **Parallelism** -- Sets ``PARALLEL_LEVEL`` (defaults to ``nproc - 1``) and
  exports ``CMAKE_BUILD_PARALLEL_LEVEL`` and ``CTEST_PARALLEL_LEVEL``.
- **CMake helpers** -- ``configure_preset``, ``build_preset``,
  ``test_preset``, and the combined ``configure_and_build_preset`` functions
  wrap CMake/Ninja/CTest invocations with logging groups, sccache stats,
  memory monitoring, and CI timeouts.
- **GPU validation** -- ``fail_if_no_gpu`` guards test steps that require an
  NVIDIA device.

Key files
~~~~~~~~~

.. list-table::
   :header-rows: 1
   :widths: 40 60

   * - File
     - Purpose
   * - ``ci/build_common.sh``
     - Shared option parsing, compiler setup, and CMake helpers.
   * - ``ci/pretty_printing.sh``
     - Logging helpers (``begin_group`` / ``end_group``, ``run_command``).


.. _ci-scripts-per-project-build:

Per-Project Build Scripts
-------------------------

Each subproject has a dedicated build script that sources ``build_common.sh``
and then configures and builds using a CMake preset.

.. list-table::
   :header-rows: 1
   :widths: 35 65

   * - Script
     - Project
   * - ``ci/build_cub.sh``
     - CUB (block-level primitives)
   * - ``ci/build_thrust.sh``
     - Thrust (high-level parallel algorithms)
   * - ``ci/build_libcudacxx.sh``
     - libcu++ (CUDA C++ Standard Library)
   * - ``ci/build_cudax.sh``
     - CUDA Experimental
   * - ``ci/build_cccl_c_parallel.sh``
     - C Parallel Library
   * - ``ci/build_cccl_c_stf.sh``
     - C STF Library
   * - ``ci/build_cuda_cccl_python.sh``
     - Python CCCL packages (uses ``-py-version`` instead of compiler flags)
   * - ``ci/build_stdpar.sh``
     - Standard Parallelism
   * - ``ci/build_cuda_cccl_wheel.sh``
     - Python wheel packaging

The typical pattern inside a build script is:

.. code-block:: bash

   source "${ci_dir}/build_common.sh"
   print_environment_details

   PRESET="cub"
   CMAKE_OPTIONS=(
       -DCMAKE_CXX_STANDARD=$CXX_STANDARD
       -DCMAKE_CUDA_STANDARD=$CXX_STANDARD
   )
   configure_and_build_preset "CUB" "$PRESET" "${CMAKE_OPTIONS[*]}"
   print_time_summary

.. warning::

   Full builds are expensive -- allow **60+ minutes** for compilation. Use
   targeted builds (see :ref:`ci-scripts-targeted-builds`) whenever possible.

Usage example:

.. code-block:: bash

   ./ci/build_cub.sh -cxx g++ -std 17 -arch "80"


.. _ci-scripts-per-project-test:

Per-Project Test Scripts
------------------------

Test scripts follow the same sourcing pattern. When run outside GitHub
Actions they first invoke the corresponding build script, so **test implies
build** for local usage. On CI, pre-built test artifacts are downloaded from
a producer job instead.

.. list-table::
   :header-rows: 1
   :widths: 35 65

   * - Script
     - Project
   * - ``ci/test_cub.sh``
     - CUB
   * - ``ci/test_thrust.sh``
     - Thrust
   * - ``ci/test_libcudacxx.sh``
     - libcu++
   * - ``ci/test_cudax.sh``
     - CUDA Experimental
   * - ``ci/test_cccl_c_parallel.sh``
     - C Parallel Library
   * - ``ci/test_cccl_c_stf.sh``
     - C STF Library
   * - ``ci/test_cuda_compute_python.sh``
     - Python ``cuda.compute`` tests
   * - ``ci/test_cuda_coop_python.sh``
     - Python ``cuda.coop`` tests
   * - ``ci/test_cuda_cccl_headers_python.sh``
     - Python ``cuda.cccl.headers`` tests
   * - ``ci/test_cuda_cccl_examples_python.sh``
     - Python example tests

Additional switches accepted by some test scripts:

- ``-compute-sanitizer-memcheck``, ``-compute-sanitizer-racecheck``,
  ``-compute-sanitizer-initcheck``, ``-compute-sanitizer-synccheck`` --
  Run under ``compute-sanitizer`` with the specified tool.
- ``-limited`` -- Restrict seed counts and device memory for faster
  validation (CUB/Thrust).

.. warning::

   Tests require an NVIDIA GPU. Expect **15+ minutes** per subproject.

Usage example:

.. code-block:: bash

   ./ci/test_cub.sh -cxx g++ -std 17 -arch "80"


.. _ci-scripts-targeted-builds:

Targeted Builds -- ``build_and_test_targets.sh``
------------------------------------------------

:file:`ci/util/build_and_test_targets.sh` builds and tests individual
CMake/Ninja/CTest/lit targets. It is **much faster** than a full project
build because it only compiles and runs exactly what you specify.

Options
~~~~~~~

.. list-table::
   :header-rows: 1
   :widths: 35 65

   * - Option
     - Description
   * - ``--preset <name>``
     - CMake preset (required unless ``--configure-override`` is used).
   * - ``--cmake-options <str>``
     - Extra CMake arguments appended to the preset configure step.
   * - ``--configure-override <cmd>``
     - Custom configuration command. Overrides ``--preset`` and ``--cmake-options``.
   * - ``--build-targets <targets>``
     - Space-separated Ninja targets to build. Omit to skip building.
   * - ``--ctest-targets <regex>``
     - Space-separated CTest ``-R`` regex patterns. Omit to skip testing.
   * - ``--lit-precompile-tests <paths>``
     - Precompile libcudacxx lit tests without running them.
       Paths are relative to ``libcudacxx/test/libcudacxx/``.
   * - ``--lit-tests <paths>``
     - Run libcudacxx lit tests.
       Paths are relative to ``libcudacxx/test/libcudacxx/``.
   * - ``--custom-test-cmd <cmd>``
     - Arbitrary command executed after all other steps.

Examples
~~~~~~~~

Build and test a single CUB test:

.. code-block:: bash

   ci/util/build_and_test_targets.sh \
     --preset cub-cpp20 \
     --build-targets "cub.cpp20.test.iterator" \
     --ctest-targets "cub.cpp20.test.iterator"

Precompile and run a single libcudacxx lit test:

.. code-block:: bash

   ci/util/build_and_test_targets.sh \
     --preset libcudacxx \
     --lit-precompile-tests \
       "std/algorithms/alg.nonmodifying/alg.any_of/any_of.pass.cpp" \
     --lit-tests \
       "std/algorithms/alg.nonmodifying/alg.any_of/any_of.pass.cpp"

Inside a devcontainer with a specific CUDA toolkit and host compiler:

.. code-block:: bash

   .devcontainer/launch.sh -d --cuda 12.3 --host gcc12 --gpus all -- \
     ci/util/build_and_test_targets.sh \
       --preset cub-cpp20 \
       --build-targets "cub.cpp20.test.iterator" \
       --ctest-targets "cub.cpp20.test.iterator"

See :doc:`/cccl/development/build_and_bisect_tools` for additional examples.


.. _ci-scripts-git-bisect:

Regression Bisection -- ``git_bisect.sh``
-----------------------------------------

:file:`ci/util/git_bisect.sh` wraps ``git bisect`` around
``build_and_test_targets.sh`` to pinpoint the commit that introduced a
regression.

Extra options (in addition to all ``build_and_test_targets.sh`` options)
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

.. list-table::
   :header-rows: 1
   :widths: 35 65

   * - Option
     - Description
   * - ``--good-ref <rev>``
     - Known good commit, tag, or branch. Accepts ``-Nd`` (e.g. ``-14d``)
       for "origin/main as of N days ago." Defaults to the latest release tag.
   * - ``--bad-ref <rev>``
     - Known bad commit, tag, or branch. Same ``-Nd`` syntax. Defaults to
       ``origin/main``.
   * - ``--summary-file <path>``
     - Write a Markdown report to this path (optional).
   * - ``--repeat <N>``
     - Re-run passing commits N times to detect flakiness (default: 1).

Example
~~~~~~~

Bisect a CUB regression introduced in the last week:

.. code-block:: bash

   .devcontainer/launch.sh -d --cuda 12.3 --host gcc12 --gpus all -- \
     ci/util/git_bisect.sh \
       --preset cub-cpp20 \
       --build-targets "cub.cpp20.test.iterator" \
       --ctest-targets "cub.cpp20.test.iterator" \
       --good-ref -7d

.. warning::

   Bisection can take a **very long time** -- each step performs a full
   configure, build, and test cycle. Minimize scope by restricting build and
   test targets to the smallest reproducer.

The **Workflow/Bisect** GitHub Actions workflow
(Actions > Git Bisect > Run workflow) runs ``git_bisect.sh`` on a remote
runner. The run's **Summary** page renders the final Markdown report with the
culprit commit, PR link, reproduction steps, and bisect log.


.. _ci-scripts-inspect-changes:

Change Detection -- ``inspect_changes.py``
-------------------------------------------

:file:`ci/inspect_changes.py` detects which CCCL subprojects have changed
between two commits so the CI workflow can skip unaffected jobs.

Configuration
~~~~~~~~~~~~~

:file:`ci/project_files_and_dependencies.yaml` defines:

- **Per-project file patterns** -- ``include_regexes`` and
  ``exclude_regexes`` map repository paths to projects.
- **Dependency graph** -- ``full_dependencies`` and ``lite_dependencies``
  declare how changes propagate between projects. A dirty dependency
  triggers a rebuild in all dependents.
- **Project exclusions** -- ``exclude_project_files`` prevents double-counting
  files that belong to a more specific sub-project (e.g. ``libcudacxx_public``
  vs. ``libcudacxx_internal``).

Usage
~~~~~

.. code-block:: bash

   # Compare two refs:
   ci/inspect_changes.py --refs origin/main HEAD

   # Read dirty paths from a file:
   ci/inspect_changes.py --file /tmp/dirty_paths.txt

   # Read dirty paths from stdin:
   git diff --name-only origin/main | ci/inspect_changes.py --stdin

Outputs
~~~~~~~

The script writes two GitHub Actions output variables:

- ``FULL_BUILD`` -- Space-separated list of projects requiring a full rebuild.
- ``LITE_BUILD`` -- Space-separated list of projects requiring only a lite
  (dependency-triggered) rebuild.

When the ``core`` bucket has dirty files (i.e. infrastructure changes not
owned by any subproject), **all** projects are marked dirty.


.. _ci-scripts-artifacts:

Artifact System -- ``ci/util/artifacts/``
-----------------------------------------

CI jobs share build products between stages (e.g. build -> test) using a
registry-based artifact system. Uploads are **staged** and then
**bulk-uploaded** when the job completes, working around GitHub Actions
limitations for artifact uploads.

Key files
~~~~~~~~~

.. list-table::
   :header-rows: 1
   :widths: 35 65

   * - Script
     - Purpose
   * - ``stage.sh``
     - Stage files matching regexes for later upload.
   * - ``unstage.sh``
     - Remove previously staged files.
   * - ``upload_stage.sh``
     - Upload a previously staged artifact as a plain zip.
   * - ``upload_stage_packed.sh``
     - Upload a previously staged artifact as a compressed archive inside a zip.
   * - ``upload.sh``
     - Convenience wrapper: stage + upload in one step.
   * - ``upload_packed.sh``
     - Convenience wrapper: stage + packed upload in one step.
   * - ``download.sh``
     - Download and extract a plain-zip artifact.
   * - ``download_packed.sh``
     - Download and extract a packed (archive-in-zip) artifact.
   * - ``common.sh``
     - Shared environment variables and paths.

Staging rules
~~~~~~~~~~~~~

All ``stage.sh`` / ``unstage.sh`` calls for a given artifact **must** be made
from the same working directory using relative paths. The stage directory
records the original working directory and will reject operations from a
different path.

Packed vs. plain artifacts
~~~~~~~~~~~~~~~~~~~~~~~~~~

- **Packed** (``upload_packed.sh`` / ``download_packed.sh``) -- Archive
  files into a ``tar.zst`` inside a zip wrapper. Best for large,
  temporary artifacts (e.g. test executables passed between build and test
  jobs). Install ``pbzip2`` for significantly faster compression.
- **Plain** (``upload.sh`` / ``download.sh``) -- Simple zip. Best for
  small artifacts that developers may want to download (e.g. Python wheels,
  installation archives).

Example: staging and uploading test artifacts:

.. code-block:: bash

   ci/util/artifacts/stage.sh test_artifacts 'bin/.*' 'lib/.*' '.*cmake$'
   ci/util/artifacts/upload_stage_packed.sh test_artifacts

Example: downloading packed artifacts in a test job:

.. code-block:: bash

   ci/util/artifacts/download_packed.sh "$artifact_name" /home/coder/cccl


.. _ci-scripts-workflow-utilities:

Workflow Job Utilities -- ``ci/util/workflow/``
-----------------------------------------------

These scripts query information about the current GitHub Actions workflow run.
They are designed to be called from CI jobs launched via ``ci/matrix.yaml``
and operate on the ``workflow`` artifact produced by the ``build-workflow``
action.

Key files
~~~~~~~~~

.. list-table::
   :header-rows: 1
   :widths: 40 60

   * - Script
     - Purpose
   * - ``initialize.sh``
     - Download and unpack the workflow definition if not already present.
   * - ``get_job_def.sh``
     - Print the JSON job definition for a given job ID.
   * - ``get_producers.sh``
     - Return producer job definitions for a consumer job.
   * - ``get_consumers.sh``
     - Return consumer job definitions for a producer job.
   * - ``has_producers.sh``
     - Check whether the current job has any producers.
   * - ``has_consumers.sh``
     - Check whether the current job has any consumers.
   * - ``get_producer_id.sh``
     - Return the producer's job ID for artifact naming.
   * - ``get_job_project.sh``
     - Return the project name associated with a job.
   * - ``get_stable_job_hash.sh``
     - Compute a stable hash for cache keying.
   * - ``get_wheel_artifact_name.sh``
     - Derive the artifact name for a Python wheel from the job definition.
   * - ``common.sh``
     - Shared variables (``$WORKFLOW_DIR``, ``$WORKFLOW_ARTIFACT``).

Local testing with ``create_mock_job_env.sh``
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

:file:`ci/util/create_mock_job_env.sh` spawns a shell that mimics a CI job's
environment, allowing the workflow and artifact scripts to run locally inside
a devcontainer:

.. code-block:: bash

   ci/util/create_mock_job_env.sh <run_id> <job_id>

The ``<run_id>`` is from the GitHub Actions workflow URL and the ``<job_id>``
appears at the start of the "Run Command" step in the job log.

.. warning::

   This script clears ``/tmp/workflow``, artifact stage/archive directories,
   and similar caches on the caller's filesystem.


.. _ci-scripts-windows:

Windows CI Scripts -- ``ci/windows/``
-------------------------------------

Windows CI uses PowerShell equivalents of the Linux scripts. The shared
module :file:`ci/windows/build_common.psm1` provides the same role as
``build_common.sh`` on Linux: option parsing (``-std``, ``-arch``,
``-cmake-options``), compiler resolution, and CMake invocation helpers.

Key files
~~~~~~~~~

.. list-table::
   :header-rows: 1
   :widths: 40 60

   * - Script
     - Purpose
   * - ``build_common.psm1``
     - Shared option parsing, compiler setup, and CMake helpers (PowerShell module).
   * - ``build_common_python.psm1``
     - Shared helpers for Python package builds.
   * - ``build_cub.ps1`` / ``test_cub.ps1``
     - CUB build and test.
   * - ``build_thrust.ps1`` / ``test_thrust.ps1``
     - Thrust build and test.
   * - ``build_libcudacxx.ps1`` / ``test_libcudacxx.ps1``
     - libcu++ build and test.
   * - ``build_cudax.ps1`` / ``test_cudax.ps1``
     - CUDA Experimental build and test.
   * - ``build_cccl_c_parallel.ps1`` / ``test_cccl_c_parallel.ps1``
     - C Parallel Library build and test.
   * - ``build_cuda_cccl_python.ps1``
     - Python CCCL package build.
   * - ``test_cuda_compute_python.ps1``
     - Python ``cuda.compute`` tests.
   * - ``test_cuda_coop_python.ps1``
     - Python ``cuda.coop`` tests.
   * - ``test_cuda_cccl_headers_python.ps1``
     - Python ``cuda.cccl.headers`` tests.
   * - ``test_cuda_cccl_examples_python.ps1``
     - Python example tests.
   * - ``install_gpu_driver.ps1``
     - Install NVIDIA GPU drivers on Windows CI runners.
   * - ``run_gpu_target.ps1`` / ``run_cpu_target.ps1``
     - Execute GPU or CPU test targets.
   * - ``run_gpu_bisect.ps1`` / ``run_cpu_bisect.ps1``
     - Run bisection on Windows.
   * - ``test_packaging.ps1``
     - Test installation packaging.


Further Reading
---------------

- :doc:`/cccl/development/build_and_bisect_tools` -- Contributor-facing
  guide with step-by-step targeted build and bisection examples.
- ``AGENTS.md`` (repository root) -- Build, test, and CI reference for
  agent-assisted development.
- ``CONTRIBUTING.md`` (repository root) -- CI environment, matrix testing,
  and troubleshooting (CI section).
