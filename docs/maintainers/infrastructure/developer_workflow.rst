Developer Workflow Systems
==========================

This guide provides a high-level overview of the developer workflow systems
that support day-to-day CCCL development. It covers code formatting and
linting, the test infrastructure used across subprojects, and the
documentation build and preview pipeline. Understanding these systems helps
contributors produce clean, well-tested pull requests and gives maintainers
a quick reference when diagnosing workflow issues.

Pre-commit Hooks and Code Formatting
-------------------------------------

CCCL enforces consistent code style through `pre-commit <https://pre-commit.com/>`_
hooks defined in ``.pre-commit-config.yaml`` at the repository root. Every
commit -- whether local or in CI -- is expected to pass these hooks before
merge.

Key files
~~~~~~~~~

.. list-table::
   :header-rows: 1
   :widths: 40 60

   * - File
     - Purpose
   * - ``.pre-commit-config.yaml``
     - Declares all hooks and their pinned versions.
   * - ``.clang-format``
     - Style rules consumed by ``clang-format`` for C/C++/CUDA sources.
   * - ``pyproject.toml``
     - Contains configuration for ``codespell``, ``ruff``, and ``mypy``.

Configured hooks
~~~~~~~~~~~~~~~~

The following hooks run on every commit:

- **end-of-file-fixer / mixed-line-ending / trailing-whitespace** --
  Whitespace normalization (from ``pre-commit-hooks``).
- **clang-format** -- Formats C, C++, CUDA (``.cu``, ``.cuh``), and
  header files. Uses ``-style=file`` so the repo-local ``.clang-format``
  controls the style.
- **ruff / ruff-format** -- Python linting and formatting.
- **taplo-format** -- TOML formatting (excludes ``docs/``).
- **gersemi** -- CMake file formatting.
- **codespell** -- Catches common spelling mistakes.
- **mypy** -- Static type checking for the ``cuda.compute`` Python package.

Local setup
~~~~~~~~~~~

.. code-block:: bash

   pip install pre-commit        # or: conda install -c conda-forge pre-commit
   pre-commit install            # register the git hook
   pre-commit run --all-files    # one-time check of the entire tree

After ``pre-commit install``, hooks run automatically on ``git commit``.
To bypass them in a pinch, use ``git commit --no-verify``, but CI will
still enforce the checks.

pre-commit.ci in CI
~~~~~~~~~~~~~~~~~~~~

A `pre-commit.ci <https://pre-commit.ci>`_ check runs on every pull
request. If it reports failures, you can comment the following on the PR
to have the service push an autofix commit:

.. code-block:: text

   pre-commit.ci autofix

The autofix commit message is ``[pre-commit.ci] auto code formatting``.

.. warning::

   The autofix only applies changes that hooks can make automatically (e.g.,
   formatting). Linter errors that require manual intervention (such as
   ``codespell`` false positives or ``mypy`` type errors) must be fixed by
   the contributor.

Testing Patterns
-----------------

CCCL spans multiple subprojects, each with its own testing conventions. The
common thread is a CMake-based build that produces per-test executables,
optionally split into variants for parallelism.

``%PARAM%`` test variant system
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Large tests can exhaust RAM during compilation. To mitigate this, CCCL
provides a CMake mechanism that generates multiple executables from a single
source file. A special comment in the test source declares parameters:

.. code-block:: c++

   // %PARAM% TEST_FOO foo 0:1:2
   // %PARAM% TEST_LAUNCH lid 0:1

CMake parses these comments and produces the full cartesian product of
values, each compiled as a separate executable with the corresponding
preprocessor definitions. For the example above, six executables are
generated (``<name>.foo_0.lid_0`` through ``<name>.foo_2.lid_1``).

The implementation lives in ``cmake/CCCLTestParams.cmake``, which exposes
the helper functions ``cccl_parse_variant_params``,
``cccl_log_variant_params``, and ``cccl_get_variant_data``.

.. warning::

   CMake does not automatically reconfigure when source files change. After
   modifying ``%PARAM%`` comments, you must re-run CMake manually.

For a detailed reference, see :doc:`/cccl/development/testing`.

CUB: Catch2 and C2H
~~~~~~~~~~~~~~~~~~~~

CUB is migrating to the `Catch2 <https://github.com/catchorg/Catch2>`_
framework. New tests use the ``C2H_TEST`` macro and the ``c2h`` helper
library, which provides:

- ``c2h::device_vector`` / ``c2h::host_vector`` -- Stable alternatives to
  their Thrust counterparts.
- ``c2h::gen(C2H_SEED(N), ...)`` -- Seeded random data generation. Each
  seed multiplies the number of test runs.
- ``c2h::type_list`` / ``c2h::enum_type_list`` -- Compile-time type
  parameterization that forms a cartesian product with ``%PARAM%``
  variants.

New Catch2 tests must be named ``catch2_test_SCOPE_FACILITY.cu`` so CMake
can distinguish them from legacy tests (``test_SCOPE_FACILITY.cu``).

For the full testing guide, see :doc:`/cub/test_overview`.

libcudacxx: LLVM lit
~~~~~~~~~~~~~~~~~~~~

libcudacxx uses the `LLVM lit <https://llvm.org/docs/CommandGuide/lit.html>`_
test runner. Tests live under ``libcudacxx/test/libcudacxx/`` and are
configured by ``libcudacxx/test/libcudacxx/lit.cfg``.

To precompile and run a single lit test:

.. code-block:: bash

   ci/util/build_and_test_targets.sh \
     --preset libcudacxx \
     --lit-precompile-tests \
       "std/algorithms/alg.nonmodifying/alg.any_of/any_of.pass.cpp" \
     --lit-tests \
       "std/algorithms/alg.nonmodifying/alg.any_of/any_of.pass.cpp"

Paths passed to ``--lit-precompile-tests`` and ``--lit-tests`` are relative
to ``libcudacxx/test/libcudacxx/``.

.. warning::

   Avoid building the full ``libcudacxx.test.lit.precompile`` target --
   it is extremely expensive. Prefer targeted test paths whenever possible.

compute-sanitizer
~~~~~~~~~~~~~~~~~

CUB tests can be executed under NVIDIA's ``compute-sanitizer`` to detect
GPU memory errors, race conditions, uninitialized memory reads, and
synchronization issues. Four tool modes are supported:

.. list-table::
   :header-rows: 1
   :widths: 35 65

   * - Flag
     - Tool
   * - ``-compute-sanitizer-memcheck``
     - Memory access checking
   * - ``-compute-sanitizer-racecheck``
     - Shared memory race detection
   * - ``-compute-sanitizer-initcheck``
     - Uninitialized device memory detection
   * - ``-compute-sanitizer-synccheck``
     - Synchronization correctness checking

Pass the desired flag to the test script:

.. code-block:: bash

   ./ci/test_cub.sh -cxx g++ -std 17 -arch "80" -compute-sanitizer-memcheck

In CI, compute-sanitizer jobs are declared in ``ci/matrix.yaml`` and use
the ``compute_sanitizer`` job type. When running under compute-sanitizer,
the seed count is automatically reduced to 1 (``C2H_SEED_COUNT_OVERRIDE=1``)
to keep run times manageable.

.. warning::

   compute-sanitizer runs are significantly slower than normal test
   execution. Some test cases are skipped entirely under specific tools
   via Catch2 tags (e.g., ``~[skip-cs-memcheck]``).

Documentation Build and Preview
--------------------------------

CCCL's documentation is built with `Sphinx <https://www.sphinx-doc.org/>`_
and lives under the ``docs/`` directory. Doxygen is used to extract API
reference information, and Sphinx assembles everything into a unified site.

Key files
~~~~~~~~~

.. list-table::
   :header-rows: 1
   :widths: 40 60

   * - File
     - Purpose
   * - ``docs/conf.py``
     - Sphinx configuration (theme, extensions, version variables).
   * - ``docs/gen_docs.bash``
     - Entry-point script that builds Doxygen output and runs Sphinx.
   * - ``.github/actions/docs-build/action.yml``
     - Composite action that installs dependencies and invokes
       ``gen_docs.bash``.
   * - ``.github/workflows/docs-deploy.yml``
     - Deploys built docs to GitHub Pages on pushes to ``main``.

Building docs locally
~~~~~~~~~~~~~~~~~~~~~

.. code-block:: bash

   cd docs
   ./gen_docs.bash          # build
   ./gen_docs.bash clean    # clean Sphinx output
   ./gen_docs.bash clean --all  # also remove Doxygen build cache

The output is written to ``docs/_build/html/``.

PR preview
~~~~~~~~~~

Every pull request automatically triggers a documentation build as part of
the ``ci-workflow-pull-request`` workflow. The build validates that docs
compile without errors. On the upstream ``NVIDIA/cccl`` repository, a
preview URL is posted as a comment on the PR, giving reviewers a live view
of how changes will appear on the documentation site.

Skipping the docs build
~~~~~~~~~~~~~~~~~~~~~~~~

If a PR does not touch documentation, include ``[skip-docs]`` in the
commit message to skip the docs build job and save CI resources:

.. code-block:: text

   Fix off-by-one in block_scan [skip-docs]

.. warning::

   ``[skip-docs]`` blocks merging. It must be removed and a successful
   docs build must complete before the PR can be merged. Use it only
   during early iteration.

Production deployment
~~~~~~~~~~~~~~~~~~~~~

The ``docs-deploy.yml`` workflow runs on pushes to ``main`` and publishes
documentation to GitHub Pages under ``docs/unstable/``. It can also be
triggered manually via ``workflow_dispatch`` to publish to a custom
directory (e.g., a versioned release path like ``docs/3.0/``).

The deployment uses ``peaceiris/actions-gh-pages`` to push to the
``gh-pages`` branch, preserving existing versioned content with
``keep_files: true``.
