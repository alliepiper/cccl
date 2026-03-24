# Create a Release

**Applicable areas:** `.github/workflows/release-*.yml`, `ci/`

## When to use

It is time to cut a new CCCL release from `main`.

## Prerequisites

- Membership in the `cccl-release-owners` GitHub team
- All desired changes merged to `main`
- CI passing on `main`

## Steps

1. **Create the release branch.**

   Go to **Actions → Release: Create New → Run workflow**.
   Provide the version (e.g., `3.4.0`).

   This workflow:
   - Creates `branch/3.4.x` from `main`
   - Tags `v3.4.0.dev`
   - Updates `cccl-version.json` on both branches

2. **Monitor CI** on the release branch (nightly/weekly run automatically).

3. **Tag a release candidate.**

   **Actions → Release: Update RC → Run workflow**.
   Provide branch (`branch/3.4.x`) and RC number → tags `v3.4.0-rc1`.

4. **Apply fixes if needed.**

   Fix on `main` first, then backport:
   - Add label `backport branch/3.4.x` to the merged PR, OR
   - Comment `/backport branch/3.4.x` on an already-merged PR
   - Review and merge the generated backport PR

5. **Finalize the release.**

   **Actions → Release: Finalize → Run workflow**.
   Tags `v3.4.0` and creates a GitHub release with notes.

6. **Publish Python wheels.**

   **Actions → Release: Wheels → Run workflow**.
   Builds and publishes `cuda-cccl` wheels to PyPI.

## Version management

- `cccl-version.json` — single source of truth
- `ci/generate_version.sh` — reads version JSON
- `ci/update_version.sh` — updates version JSON
- `update-branch-version.yml` — auto-updates on release branch pushes

## Warning

Only `cccl-release-owners` can merge to release branches or run release workflows.
