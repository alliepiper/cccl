CI / GitHub Actions Workflows
=============================

This guide describes the architecture of CCCL's Continuous Integration system.
The CI is built on GitHub Actions and uses a dynamically generated job matrix,
change-detection pruning, and NVIDIA self-hosted runners.  A typical pull-request
run spawns around 250 jobs; nightly and weekly runs exercise a broader matrix.

For contributor-oriented troubleshooting and local reproduction steps, see
the CI section of ``CONTRIBUTING.md``.


Workflow Architecture Overview
------------------------------

CCCL has three scheduled workflow tiers, plus an ad-hoc override mechanism:

.. list-table::
   :header-rows: 1
   :widths: 20 30 50

   * - Workflow
     - Trigger
     - Purpose
   * - **pull_request**
     - Push to ``pull-request/N`` branch (via ``copy-pr-bot``)
     - Validates every PR against a pruned matrix of build/test jobs.
   * - **nightly**
     - Cron (Mon--Fri, 03:00 UTC) or ``workflow_dispatch``
     - Full compiler x CTK x standard matrix builds; GPU tests on latest CTK.
   * - **weekly**
     - Cron (Sunday, 08:00 UTC) or ``workflow_dispatch``
     - Extended test configurations (e.g. compute-sanitizer, broader GPU coverage).

All three workflows share the same internal pipeline structure:

1. **build-workflow** -- Parse ``ci/matrix.yaml``, detect changed projects, generate a dispatch payload.
2. **dispatch-groups** -- Fan out the payload to per-platform dispatch workflows that launch individual jobs.
3. **workflow-run-job** -- Each job runs inside a devcontainer on a self-hosted runner.
4. **verify-workflow** (results) -- Collect artifacts, verify success, post a summary comment.

The following diagram shows the PR pipeline end-to-end:

.. code-block:: text

   PR Push
     |
     v
   copy-pr-bot copies to pull-request/N
     |
     v
   ci-workflow-pull-request.yml
     |
     v
   +------------------------------------------------------+
   | build-workflow job (ubuntu-latest)                    |
   |                                                      |
   |  1. inspect_changes.py                               |
   |       - diffs base..HEAD                             |
   |       - outputs FULL_BUILD / LITE_BUILD projects     |
   |                                                      |
   |  2. build-workflow.py                                |
   |       - reads ci/matrix.yaml                         |
   |       - prunes jobs by dirty-project info            |
   |       - writes workflow.json + job_ids.json          |
   |                                                      |
   |  3. prepare-workflow-dispatch.py                     |
   |       - formats dispatch.json for GHA matrix         |
   +------------------------------------------------------+
     |
     |  dispatch.json is split into four groups:
     |    - linux_two_stage     (build then test)
     |    - linux_standalone    (single-phase jobs)
     |    - windows_two_stage
     |    - windows_standalone
     |
     v
   +------------------------------------------------------+
   | dispatch-groups-*  (parallel, per-platform)           |
   |                                                      |
   |  Each entry becomes a matrix job that calls           |
   |  workflow-dispatch-{two-stage,standalone}-group-*.yml |
   |                                                      |
   |    +--------------------------------------------+    |
   |    | workflow-run-job-{linux,windows}            |    |
   |    |   - downloads workflow artifact             |    |
   |    |   - launches devcontainer                   |    |
   |    |   - runs ci/build_*.sh or ci/test_*.sh     |    |
   |    |   - uploads result artifacts                |    |
   |    +--------------------------------------------+    |
   +------------------------------------------------------+
     |
     v
   +------------------------------------------------------+
   | verify-workflow  (results aggregation)                |
   |                                                      |
   |  1. verify-job-success.py   - checks job artifacts   |
   |  2. parse-job-times.py      - collects timing data   |
   |  3. prepare-execution-summary.py                     |
   |  4. final-summary.py        - posts PR comment       |
   |  5. Fails if override matrix is present              |
   +------------------------------------------------------+
     |
     v
   ci job (branch protection gate)
     - checks verify-workflow, verify-devcontainers,
       docs-build, test-cpu-import


Key files
^^^^^^^^^

.. list-table::
   :header-rows: 1
   :widths: 55 45

   * - Path
     - Role
   * - ``.github/workflows/ci-workflow-pull-request.yml``
     - Top-level PR workflow
   * - ``.github/workflows/ci-workflow-nightly.yml``
     - Top-level nightly workflow
   * - ``.github/workflows/ci-workflow-weekly.yml``
     - Top-level weekly workflow
   * - ``.github/actions/workflow-build/action.yml``
     - Composite action: inspect changes, parse matrix, prepare dispatch
   * - ``.github/actions/workflow-run-job-linux/action.yml``
     - Composite action: run a single Linux job in a devcontainer
   * - ``.github/actions/workflow-run-job-windows/action.yml``
     - Composite action: run a single Windows job
   * - ``.github/actions/workflow-results/action.yml``
     - Composite action: aggregate results, post summary


Matrix System (``ci/matrix.yaml``)
-----------------------------------

``ci/matrix.yaml`` is the single source of truth for which jobs to run in each
workflow tier.  It contains named workflow sections, each holding a list of job
descriptors.

Workflow sections
^^^^^^^^^^^^^^^^^

.. list-table::
   :header-rows: 1
   :widths: 22 78

   * - Section
     - Description
   * - ``override``
     - When non-empty, **replaces** ``pull_request`` for PR runs. Useful for
       rapid iteration on a targeted subset. **Blocks merge** -- branch
       protection fails while any override jobs are present.
   * - ``pull_request``
     - The default PR matrix (~250 jobs). Covers build-only across old/new CTK
       and compilers, plus GPU test jobs on current CTK.
   * - ``pull_request_lite``
     - A reduced matrix used for **downstream dependency smoke tests**.  When
       ``inspect_changes.py`` determines that only a dependency changed (e.g. a
       libcudacxx header change affecting CUB), the dependent project runs the
       ``pull_request_lite`` matrix instead of the full ``pull_request`` matrix.
   * - ``nightly``
     - Full compiler x CTK build matrix, plus GPU test jobs.
   * - ``weekly``
     - Extended testing (compute-sanitizer, broader GPU/SM coverage).

Job descriptor fields
^^^^^^^^^^^^^^^^^^^^^

Each entry in a workflow section is a YAML mapping with the following fields:

.. list-table::
   :header-rows: 1
   :widths: 22 15 63

   * - Field
     - Required
     - Description
   * - ``jobs``
     - Yes
     - List of job types: ``build``, ``test``, ``test_gpu``, ``test_nolid``,
       ``test_lid0``, ``test_lid1``, ``test_lid2``, ``nvrtc``,
       ``verify_codegen``, ``install``, ``run_cpu``, ``run_gpu``, etc.
   * - ``project``
     - No
     - Subproject name (``libcudacxx``, ``cub``, ``thrust``, ``cudax``,
       ``cccl_c_parallel``, ``python``, ``packaging``, ``target``, etc.).
       Defaults to the set of "default" projects when omitted.
   * - ``ctk``
     - No
     - CUDA Toolkit version (``12.0``, ``12.X``, ``13.0``, ``13.X``).
       Defaults to the current latest when omitted.
   * - ``std``
     - No
     - C++ standard.  Special values: ``all`` (every supported standard),
       ``minmax`` (oldest and newest), ``max`` (newest only).
   * - ``cxx``
     - No
     - Host compiler(s).  Examples: ``gcc14``, ``clang19``, ``msvc2022``,
       ``gcc`` (latest GCC), ``clang`` (latest Clang), ``msvc`` (latest MSVC).
   * - ``gpu``
     - No
     - Target GPU runner (``rtx2080``, ``rtx4090``, ``rtxa6000``, ``h100``,
       ``l4``, ``rtxpro6000``).  Required for test jobs.
   * - ``cpu``
     - No
     - CPU architecture (``amd64`` default, ``arm64``).
   * - ``sm``
     - No
     - SM architectures, semicolon-separated (e.g. ``75;80;90;100``).
       Special value ``gpu`` selects the SM of the target GPU at runtime.
   * - ``cmake_options``
     - No
     - Extra CMake flags passed to the build script.
   * - ``args``
     - No
     - Raw arguments passed to ``ci/util/build_and_test_targets.sh``.
       Used primarily with ``project: 'target'`` for ad-hoc builds.
   * - ``py_version``
     - No
     - Python version (``3.10``, ``3.11``, ``3.12``, ``3.13``).
       Required for ``project: 'python'``.

Example override entry
^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: yaml

   workflows:
     override:
       - {jobs: ['build'], project: 'cudax', ctk: '12.0', std: 'all',
          cxx: ['msvc14.39', 'gcc10', 'clang14']}

.. warning::

   PR merges are **blocked** while an ``override`` section is non-empty.
   The override must be reset to empty before merging.  The results job
   explicitly checks for the presence of ``workflow/override.json`` and
   fails the workflow if it exists.


Job Generation Pipeline
-----------------------

The ``workflow-build`` composite action (``.github/actions/workflow-build/``)
orchestrates three scripts in sequence:

Step 1: Inspect changes (``ci/inspect_changes.py``)
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Compares the PR's merge-base to HEAD using ``git diff --name-only`` and
classifies each changed file into a project, as defined by
``ci/project_files_and_dependencies.yaml``.

Outputs two sets of project names as GitHub Actions outputs:

- **FULL_BUILD** -- Projects whose own files changed, or whose
  ``full_dependencies`` are dirty.  These run the ``pull_request`` matrix.
- **LITE_BUILD** -- Projects whose ``lite_dependencies`` (or transitive
  dependencies) are dirty.  These run the ``pull_request_lite`` matrix.

Projects are split into "public" and "internal" sub-projects in the dependency
configuration.  A change to ``libcudacxx/include/`` (public API) marks
downstream consumers as dirty, while a change to ``libcudacxx/test/`` (internal)
does not.

If a file falls outside all project patterns, it is attributed to the ``core``
pseudo-project, which triggers a **full rebuild of every project**.

Step 2: Build workflow (``build-workflow.py``)
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Parses ``ci/matrix.yaml`` and:

1. Selects the requested workflow section(s) (e.g. ``pull_request``).
2. If ``--allow-override`` is set and the ``override`` section is non-empty,
   uses that instead.
3. Expands shorthand values (``all``, ``minmax``, ``max`` for ``std``; bare
   compiler names to versioned defaults).
4. Prunes the job list using the ``FULL_BUILD`` and ``LITE_BUILD`` project
   sets from Step 1.
5. Writes ``workflow/workflow.json`` (the complete job list), ``workflow/job_ids.json``
   (unique identifiers), and ``workflow/job_list.txt`` (human-readable summary).

Step 3: Prepare dispatch (``prepare-workflow-dispatch.py``)
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Transforms ``workflow/workflow.json`` into ``workflow/dispatch.json``, which
groups jobs by platform and execution mode:

- ``linux_two_stage`` -- Jobs that require a separate build phase before testing.
- ``linux_standalone`` -- Single-phase jobs (build-only, install, codegen, etc.).
- ``windows_two_stage`` and ``windows_standalone`` -- Windows equivalents.

Each group contains a list of keys (used as the GHA matrix) and a mapping from
key to the job parameters needed by the dispatch workflow.


Job Execution
-------------

Each dispatched job is handled by the ``workflow-run-job-linux`` or
``workflow-run-job-windows`` composite action.

Linux jobs
^^^^^^^^^^

1. Download the ``workflow`` artifact to get job metadata.
2. Obtain AWS credentials for the ``sccache`` bucket.
3. Launch the appropriate devcontainer (selected by CTK version and host
   compiler).
4. Run the CI build/test script (e.g. ``ci/build_cub.sh``, ``ci/test_thrust.sh``)
   inside the container.
5. Upload result artifacts (``zz_jobs-*`` prefix) for the results action.

Windows jobs follow the same pattern using PowerShell and Windows runners.

Two-stage jobs split execution into a **build** phase that uploads test
artifacts and a **test** phase that downloads those artifacts and runs tests on
a GPU runner.  This avoids tying up expensive GPU runners during compilation.


Results Aggregation
-------------------

The ``workflow-results`` composite action
(``.github/actions/workflow-results/``) runs after all dispatch groups complete
(using ``if: always() && !cancelled()``).

Scripts executed in order:

.. list-table::
   :header-rows: 1
   :widths: 40 60

   * - Script
     - Purpose
   * - ``verify-job-success.py``
     - Checks that every job ID in ``job_ids.json`` has a corresponding
       success artifact.  Outputs a pass/fail flag.
   * - ``parse-job-times.py``
     - Joins ``workflow.json`` against the GitHub API's job timing data to
       produce ``job_times.md``.
   * - ``prepare-execution-summary.py``
     - Generates a heading and execution summary for the final comment.
   * - ``final-summary.py``
     - Combines all markdown fragments into ``final_summary.md`` and writes
       the GitHub step summary.

After aggregation, the action checks whether ``workflow/override.json`` exists.
If it does, the workflow is **explicitly failed** even if all jobs passed,
blocking the PR from merging until the override is removed.

For PR workflows, a sticky comment is posted to the pull request with a link to
the run summary.


CI Commit Message Controls
--------------------------

Tags in the **most recent commit message** on a PR branch control which job
groups are spawned.  These are parsed in the ``build-workflow`` job's
``export-flags`` step.

.. list-table::
   :header-rows: 1
   :widths: 35 65

   * - Tag
     - Effect
   * - ``[skip-matrix]``
     - Skips all ``ci/matrix.yaml`` build/test jobs.  Docs, devcontainer
       verification, and third-party builds still run.
   * - ``[skip-vdc]``
     - Skips "Verify Devcontainer" jobs.  Safe unless CI or devcontainer
       infrastructure changed.
   * - ``[skip-docs]``
     - Skips the documentation build/preview.
   * - ``[skip-third-party-testing]`` / ``[skip-tpt]``
     - Skips all third-party canary builds (MatX, PyTorch, RAPIDS).
   * - ``[skip-matx]``
     - Skips the MatX canary build only.
   * - ``[skip-pytorch]``
     - Skips the PyTorch canary build only.
   * - ``[skip-rapids]``
     - Skips the RAPIDS canary build only.

.. warning::

   **All skip tags block merging.**  The ``ci`` branch-protection job requires
   every component to pass.  Remove skip tags and push a clean commit before
   requesting review or merge.

Example usage during early iteration:

.. code-block:: bash

   git commit -m "WIP refactor [skip-matrix][skip-vdc][skip-docs][skip-tpt]"


copy-pr-bot and Security Model
-------------------------------

CCCL CI runs on `NVIDIA self-hosted action runners
<https://docs.gha-runners.nvidia.com/runners/>`_.  For security, PR code never
runs directly on these runners from a fork branch.

The ``copy-pr-bot`` GitHub application copies PR source code to a branch named
``pull-request/N`` inside the ``NVIDIA/cccl`` repository.  The
``ci-workflow-pull-request.yml`` workflow triggers **only** on pushes to
``pull-request/*`` branches, ensuring that self-hosted runners execute vetted
code.

External contributors
^^^^^^^^^^^^^^^^^^^^^

For PRs from forks (external contributors), ``copy-pr-bot`` does **not**
automatically copy the code.  A repository member must review the changes and
post:

.. code-block:: text

   /ok to test <commit-SHA>

This triggers ``copy-pr-bot`` to copy that specific commit to
``pull-request/N``, starting a CI run.

Internal contributors (signed commits)
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

For PRs from branches within ``NVIDIA/cccl`` where the latest commit is
**signed**, ``copy-pr-bot`` automatically copies the code and CI starts
immediately.  Unsigned commits from internal contributors still require
an ``/ok to test`` comment.


Third-Party Canary Builds
--------------------------

CCCL runs smoke-test builds of key downstream consumers to catch breakage
early.  These are reusable workflows invoked from both PR and nightly
pipelines:

.. list-table::
   :header-rows: 1
   :widths: 30 30 40

   * - Workflow
     - File
     - What it tests
   * - **MatX**
     - ``build-matx.yml``
     - Builds the `MatX <https://github.com/NVIDIA/MatX>`_ library against
       the PR's CCCL headers.
   * - **PyTorch**
     - ``build-pytorch.yml``
     - Builds PyTorch's CUDA components against the PR's CCCL headers.
   * - **RAPIDS**
     - ``build-rapids.yml``
     - Builds the RAPIDS suite (cuDF, cuML, etc.) against the PR's CCCL
       headers.

In PR workflows these jobs are labeled *"(optional)"* and their failure does
not block the ``ci`` gate.  In nightly runs they are unconditional and send
Slack alerts on failure.

These canary builds can be individually skipped with the commit-message tags
``[skip-matx]``, ``[skip-pytorch]``, ``[skip-rapids]``, or collectively with
``[skip-tpt]`` / ``[skip-third-party-testing]``.


Signed Commits and Auto-triggering
------------------------------------

Signed commits allow internal NVIDIA contributors to skip the manual
``/ok to test`` step.  ``copy-pr-bot`` recognizes the signature and
automatically copies the branch.

To set up SSH commit signing:

.. code-block:: bash

   # Configure git to use SSH for signing:
   git config --global gpg.format ssh
   git config --global user.signingKey ~/.ssh/YOUR_PUBLIC_KEY_FILE_HERE.pub

   # Optionally auto-sign all commits and tags:
   git config --global commit.gpgsign true
   git config --global tag.gpgsign true

Then upload the public key to your `GitHub Signing Keys
<https://github.com/settings/keys>`_ page (under **Signing Keys**, not just
Authentication Keys):

.. code-block:: bash

   gh ssh-key add ~/.ssh/YOUR_PUBLIC_KEY_FILE_HERE.pub --type signing

.. warning::

   The same SSH key can serve for both authentication and signing, but it
   must be uploaded separately under each category on GitHub.
