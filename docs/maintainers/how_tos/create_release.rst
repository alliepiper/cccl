How to Create a Release
=======================

When to use
-----------

It is time to cut a new CCCL release from the ``main`` branch.

Prerequisites
-------------

- Membership in the ``cccl-release-owners`` GitHub team
- All desired changes merged to ``main``
- CI passing on ``main``

Steps
-----

1. **Create the release branch.**

   Go to **Actions → Release: Create New → Run workflow** on GitHub.

   Provide the version number (e.g., ``3.4.0``). The workflow:

   - Creates ``branch/3.4.x`` from ``main``
   - Tags the branch with ``v3.4.0.dev``
   - Updates version numbers in ``cccl-version.json`` on both the release
     branch and ``main``

2. **Test the release branch.**

   The nightly and weekly CI workflows run against release branches
   automatically. Monitor for failures.

3. **Tag a release candidate.**

   Go to **Actions → Release: Update RC → Run workflow**.

   Provide the release branch (``branch/3.4.x``) and RC number. The workflow
   tags ``v3.4.0-rc1`` (or ``-rc2``, etc.) on the release branch.

4. **Apply fixes if needed.**

   If issues are found, fix them on ``main`` first, then backport to the
   release branch. See :doc:`../backport_process`.

5. **Finalize the release.**

   Go to **Actions → Release: Finalize → Run workflow**.

   Provide the release branch. The workflow:

   - Tags ``v3.4.0`` on the release branch
   - Creates a GitHub release with release notes

6. **Build and publish Python wheels.**

   Go to **Actions → Release: Wheels → Run workflow**.

   This builds and publishes ``cuda-cccl`` wheels to PyPI for the release tag.

Version management
------------------

- ``cccl-version.json`` is the single source of truth for the project version.
- ``ci/generate_version.sh`` reads the JSON and emits version strings.
- ``ci/update_version.sh`` modifies the JSON.
- ``update-branch-version.yml`` automatically updates version info when
  commits land on release branches.

.. warning::

   Only ``cccl-release-owners`` team members can merge PRs to release
   branches or run release workflows.

See also
--------

- :doc:`../infrastructure/release_and_versioning` — release system architecture
- :doc:`../backport_process` — backporting fixes to release branches
- :doc:`../../maintainers/branching_strategy` — branching model and tagging conventions
