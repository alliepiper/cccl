How to Add a CI Matrix Job
==========================

When to use
-----------

You need to add a new build or test job to the CI matrix — for example, to
cover a new compiler version, GPU architecture, CUDA toolkit, or project.

Prerequisites
-------------

- Understanding of the ``ci/matrix.yaml`` format
- Familiarity with the existing job entries for the target workflow

Steps
-----

1. **Open** ``ci/matrix.yaml`` **and locate the target workflow.**

   Jobs are grouped under workflow names: ``pull_request``, ``nightly``,
   ``weekly``. Most new jobs go into ``pull_request``.

2. **Add a new job entry.**

   Each entry is a YAML dictionary with these fields:

   .. code-block:: yaml

      - jobs: ['build']           # Job type(s): build, test, test_gpu, test_nolid, test_lid0, etc.
        project: 'cub'            # Project: cub, thrust, libcudacxx, cudax, cccl_c_parallel, python, etc.
        ctk: '13.X'               # CUDA toolkit version (optional, defaults to current)
        std: 'max'                 # C++ standard: 'all', 'minmax', 'max', or specific like 17, 20
        cxx: ['gcc14', 'clang20'] # Host compiler(s)
        gpu: 'rtxa6000'           # GPU type (for test jobs): rtx2080, rtx4090, rtxa6000, h100, l4, etc.
        cpu: 'amd64'              # CPU architecture (optional): amd64, arm64
        sm: '90'                  # SM architecture override (optional)
        cmake_options: '-DFOO=ON' # Extra CMake options (optional)
        args: '--preset ...'      # Args for build_and_test_targets.sh (project: 'target' only)

   Unversioned compiler names (e.g., ``gcc``, ``clang``, ``msvc``) resolve to
   the latest supported version.

3. **Follow existing patterns.**

   Look at neighboring entries for the same project. Keep the style consistent:
   old CTK entries first, then current CTK, then testing entries.

4. **Test with an override matrix.**

   Before pushing a full CI run, add your new job(s) to the ``override``
   workflow to test only your additions:

   .. code-block:: yaml

      workflows:
        override:
          - {jobs: ['build'], project: 'cub', ctk: '13.X', std: 'max', cxx: ['gcc14']}
        pull_request:
          # ... existing entries ...

   .. warning::

      The override matrix **blocks PR merging**. Remove it (set to empty)
      before the final CI run and merge.

5. **Push and verify the CI run.**

   Confirm the new job appears in the CI matrix summary on the PR page and
   passes successfully.

Troubleshooting
---------------

- **Job doesn't appear in CI:** Check that the project is not being pruned by
  ``inspect_changes.py``. If your PR only touches infra files, the project may
  be skipped. Use ``[skip-matrix]`` removal or ensure the project files are
  marked dirty.

- **Invalid matrix entry:** ``build-workflow.py`` will fail with an error if
  the YAML is malformed or uses unrecognized field values. Check the CI
  ``build-workflow`` job log for details.

See also
--------

- :doc:`../infrastructure/ci_workflows` — CI architecture and matrix system
- :doc:`override_ci_matrix` — how to use the override workflow
