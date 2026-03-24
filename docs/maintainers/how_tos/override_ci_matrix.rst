How to Override the CI Matrix
=============================

When to use
-----------

You want to limit a PR's CI run to a targeted subset of jobs — for example,
to iterate quickly on an infrastructure change, test a fix for a specific
compiler, or debug a nightly failure.

Prerequisites
-------------

- Write access to push commits to the PR branch

Steps
-----

1. **Edit** ``ci/matrix.yaml`` **and add entries under** ``override``.

   The ``override`` workflow replaces the ``pull_request`` workflow when
   non-empty.

   .. code-block:: yaml

      workflows:
        override:
          # Full project build for a specific compiler:
          - {jobs: ['test'], project: 'thrust', std: 17, ctk: '12.X', cxx: ['gcc12', 'clang16']}

          # Targeted test using build_and_test_targets.sh:
          - {jobs: ['run_gpu'], project: 'target', ctk: '13.X', cxx: ['gcc'], gpu: 'rtxa6000',
             args: '--preset cub-cpp20 --build-targets "cub.cpp20.test.iterator" --ctest-targets "cub.cpp20.test.iterator"'}

        pull_request:
          # ... (leave unchanged) ...

2. **Combine with skip tags for further reduction.**

   If you only care about matrix jobs, skip other CI checks:

   .. code-block:: bash

      git commit -m "Debug thrust gcc12 failure [skip-vdc][skip-docs][skip-tpt]"

3. **Push and verify.** The CI summary will show the override matrix and a
   reduced job count.

4. **Remove the override before merging.**

   .. warning::

      **The override matrix blocks PR merging.** The ``workflow-results``
      action explicitly fails the workflow when an override is present.

   Set the override back to empty (do **not** remove the key entirely):

   .. code-block:: yaml

      workflows:
        override:

        pull_request:
          # ...

5. **Push a final commit** to trigger a full CI run without the override.
   All branch protection checks must pass before merging.

Using ``project: 'target'`` for arbitrary commands
--------------------------------------------------

The special ``target`` project passes ``args`` directly to
``ci/util/build_and_test_targets.sh``, allowing targeted builds/tests:

.. code-block:: yaml

   override:
     # CPU-only build (no GPU needed):
     - {jobs: ['run_cpu'], project: 'target', ctk: ['12.X', '13.X'], cxx: ['gcc', 'clang', 'msvc'],
        args: '--preset cub-cpp20 --build-targets "cub.cpp20.test.iterator"'}

     # GPU test:
     - {jobs: ['run_gpu'], project: 'target', ctk: '13.X', cxx: ['gcc'], gpu: 'rtx2080',
        args: '--preset cub-cpp20 --build-targets "cub.cpp20.test.iterator" --ctest-targets "cub.cpp20.test.iterator"'}

     # Lit tests (libcudacxx):
     - {jobs: ['run_cpu'], project: 'target', ctk: '13.X', cxx: ['gcc'],
        args: '--preset libcudacxx --lit-precompile-tests "cuda/utility/basic_any.pass.cpp"'}
     - {jobs: ['run_gpu'], project: 'target', ctk: '13.X', cxx: ['gcc'], gpu: 'rtx2080',
        args: '--preset libcudacxx --lit-tests "cuda/utility/basic_any.pass.cpp"'}

See also
--------

- :doc:`../infrastructure/ci_workflows` — CI architecture and matrix system
- :doc:`add_ci_matrix_job` — adding permanent matrix entries
