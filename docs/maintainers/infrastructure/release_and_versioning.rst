Release and Versioning
======================

This guide describes the release lifecycle, version management, and backport
infrastructure used to publish CCCL releases. It is intended for maintainers
who create, stabilize, and finalize releases.

For the branching model itself, see :doc:`/maintainers/branching_strategy`.
For the backport workflow used to apply fixes to release branches, see
:doc:`/maintainers/backport_process`.

Branching Strategy
------------------

CCCL follows a two-branch model:

- **main** -- the default development branch. All new work lands here via
  pull request.
- **branch/X.Y.x** -- release-stabilization branches. Created from ``main``
  by automation when a release cycle begins. Only backported fixes are merged
  here.

Three tag patterns mark lifecycle milestones:

.. list-table::
   :header-rows: 1
   :widths: 30 70

   * - Tag
     - Meaning
   * - ``vX.Y.Z``
     - Finalized release on a release branch.
   * - ``vX.Y.Z-rcN``
     - Release-candidate tag for pre-release validation.
   * - ``vX.Y.Z.dev``
     - First commit of development for the next version (the version-bump
       commit).

Release Automation Workflows
-----------------------------

All release workflows are manually dispatched from the GitHub Actions UI.
Detailed usage notes live in ``.github/workflows/release-README.md``.

.. list-table::
   :header-rows: 1
   :widths: 40 60

   * - Workflow
     - Purpose
   * - ``release-create-new.yml``
     - Begin a release cycle. Creates ``branch/X.Y.x`` (if needed), sets
       the branch version, and optionally opens a PR to bump ``main`` to
       the next development version.
   * - ``release-update-rc.yml``
     - Tag a new release candidate from the HEAD of a prepared release
       branch. Determines the next ``-rcN`` suffix automatically, runs CI,
       and tags only if CI passes.
   * - ``release-finalize.yml``
     - Promote a release candidate to a final release. Must be started on
       an ``-rcN`` tag. Pushes the ``vX.Y.Z`` tag, generates source and
       install archives, and creates a draft GitHub Release with
       auto-generated notes.
   * - ``release-wheels.yml``
     - Build and publish Python wheels to PyPI or TestPyPI. Requires the
       run ID of a prior workflow that produced validated artifacts and a
       destination index (``pypi`` or ``testpypi``).
   * - ``update-branch-version.yml``
     - Update the version number in any branch (``main`` or a release
       branch) via a pull request. Used by other release workflows and can
       also be triggered independently.

Typical release sequence
~~~~~~~~~~~~~~~~~~~~~~~~

#. Run ``release-create-new.yml`` on ``main`` (or an existing release branch)
   to create ``branch/X.Y.x`` and bump ``main`` to the next version.
#. Apply any needed fixes via the :doc:`backport process </maintainers/backport_process>`.
#. Run ``release-update-rc.yml`` on ``branch/X.Y.x`` to tag an RC.
#. Validate the RC. If issues are found, backport fixes and repeat step 3.
#. Run ``release-finalize.yml`` on the chosen ``-rcN`` tag to cut the final
   release.
#. Run ``release-wheels.yml`` to publish Python packages.

Version Management
------------------

Single source of truth
~~~~~~~~~~~~~~~~~~~~~~

``cccl-version.json`` at the repository root holds the current version:

.. code-block:: json

   {
     "full": "3.4.0",
     "major": 3,
     "minor": 4,
     "patch": 0
   }

All version-aware tooling reads from this file.

Key files
~~~~~~~~~

.. list-table::
   :header-rows: 1
   :widths: 40 60

   * - File
     - Purpose
   * - ``cccl-version.json``
     - Canonical version record (``full``, ``major``, ``minor``, ``patch``).
   * - ``ci/generate_version.sh``
     - Generates a version string from ``cccl-version.json`` and ``git
       describe``. Appends ``.devN`` on development branches or
       ``.postN`` on release branches when the commit is ahead of the
       last tag.
   * - ``ci/update_version.sh``
     - Updates ``cccl-version.json`` and propagates the new version across
       all subproject files that embed it. Usage:
       ``./ci/update_version.sh [--dry-run] <major> <minor> <patch>``.
   * - ``ci/update_rapids_version.sh``
     - Syncs RAPIDS-specific version references (devcontainer images,
       ``ci/matrix.yaml``, etc.) to a given ``YY.MM.PP`` version.
   * - ``.github/actions/version-update/action.yml``
     - Composite action that automates the version-bump-and-PR pattern.
       Called by ``update-branch-version.yml`` and the release-create
       workflow.

Backport Process
----------------

Fixes destined for a release branch follow the backport workflow documented in
:doc:`/maintainers/backport_process`. The key points are summarized here for
quick reference.

Triggering a backport
~~~~~~~~~~~~~~~~~~~~~

- **Before merge:** add the label ``backport branch/X.Y.x`` to the PR
  targeting ``main``. After the PR merges, the ``backport-prs.yml``
  workflow automatically opens a backport PR against the release branch.
- **After merge:** comment ``/backport branch/X.Y.x`` on the already-merged
  PR. The same workflow picks up the comment and creates the backport PR.

Merging backport PRs
~~~~~~~~~~~~~~~~~~~~

Only members of the
`cccl-release-owners <https://github.com/orgs/NVIDIA/teams/cccl-release-owners>`_
GitHub team can merge pull requests into release branches.

Key files
~~~~~~~~~

.. list-table::
   :header-rows: 1
   :widths: 40 60

   * - File
     - Purpose
   * - ``.github/workflows/backport-prs.yml``
     - Triggers on merged PRs (via label) or on ``/backport`` comments.
       Uses the ``korthout/backport-action`` to cherry-pick commits into
       a backport PR.
