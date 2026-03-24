How to Bisect a Regression
==========================

When to use
-----------

A test or build that previously worked is now failing, and you need to find the
commit that introduced the regression.

Prerequisites
-------------

- A reproducer: a build target, test, or lit test that demonstrates the failure
- Knowledge of a "good" reference point (a commit, tag, or relative date where
  the test passed)
- Devcontainer access (recommended for consistent environment)

Steps
-----

1. **Identify the build/test target that reproduces the failure.**

   You need a ``--preset``, ``--build-targets``, and optionally
   ``--ctest-targets`` or ``--lit-tests`` that demonstrate the issue.

2. **Run the bisect locally.**

   .. code-block:: bash

      ci/util/git_bisect.sh \
        --preset cub-cpp20 \
        --build-targets "cub.cpp20.test.iterator" \
        --ctest-targets "cub.cpp20.test.iterator"

   By default, this bisects between the latest release tag (good) and
   ``origin/main`` (bad).

3. **Narrow the search range if possible.**

   Use ``--good-ref`` and ``--bad-ref`` to constrain the range:

   .. code-block:: bash

      ci/util/git_bisect.sh \
        --preset cub-cpp20 \
        --build-targets "cub.cpp20.test.iterator" \
        --ctest-targets "cub.cpp20.test.iterator" \
        --good-ref -7d \
        --bad-ref -1d

   The ``-Nd`` syntax means "origin/main N days ago."

4. **Use a devcontainer for a specific CTK/compiler.**

   .. code-block:: bash

      .devcontainer/launch.sh -d --cuda 12.9 --host gcc13 --gpus all -- \
        ci/util/git_bisect.sh \
          --preset cub-cpp20 \
          --build-targets "cub.cpp20.test.iterator" \
          --ctest-targets "cub.cpp20.test.iterator" \
          --good-ref -14d

5. **Use the remote bisect workflow for longer bisections.**

   Go to **Actions → Git Bisect → Run workflow** on GitHub. Provide the
   preset, targets, refs, and any launch arguments. The workflow runs on a
   remote runner and produces a Markdown report in the run summary with the
   culprit commit, associated PR, and reproduction steps.

Compute-sanitizer bisection
---------------------------

To bisect a compute-sanitizer failure, pass the sanitizer mode via environment:

.. code-block:: bash

   .devcontainer/launch.sh -d --cuda 12.9 --host gcc13 --gpus all \
     --env CCCL_TEST_MODE=compute-sanitizer-initcheck \
     --env C2H_SEED_COUNT_OVERRIDE=1 \
     -- ci/util/git_bisect.sh \
       --preset cub-cpp20 \
       --build-targets "cub.cpp20.test.iterator" \
       --ctest-targets "cub.cpp20.test.iterator" \
       --good-ref -28d --bad-ref -21d

Troubleshooting
---------------

- **Bisect takes too long:** Minimize the build scope. Use targeted
  ``--build-targets`` instead of full builds. Narrow the ``--good-ref`` /
  ``--bad-ref`` range.

- **Bisect skips commits that fail to build:** This is expected — ``git bisect``
  marks uncompilable commits as ``skip`` and continues searching.

- **Lit tests:** Use ``--lit-precompile-tests`` and ``--lit-tests`` instead of
  ``--build-targets`` / ``--ctest-targets`` for libcudacxx lit tests.

See also
--------

- :doc:`../infrastructure/ci_scripts` — build_and_test_targets.sh and git_bisect.sh
- `Build and Bisect Utilities <../../cccl/development/build_and_bisect_tools.rst>`_ — detailed option reference
