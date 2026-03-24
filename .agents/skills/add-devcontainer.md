# Add a Devcontainer Variant

**Applicable areas:** `.devcontainer/`

## When to use

A new CUDA toolkit version or host compiler needs a devcontainer configuration.

## Steps

1. **Edit `.devcontainer/make_devcontainers.sh`** if the new CTK or compiler
   version isn't already in the generation arrays.

2. **Run the generator:**

   ```bash
   .devcontainer/make_devcontainers.sh
   ```

   This creates/updates devcontainer.json files for all CTK × compiler combinations.

3. **Verify the new container builds:**

   ```bash
   .devcontainer/launch.sh -d --cuda <VERSION> --host <COMPILER>
   ```

   First launch pulls the Docker image (may take several minutes).

4. **For `-ext` variants** (extended CTK libraries):

   ```bash
   .devcontainer/launch.sh -d --cuda <VERSION> --cuda-ext --host <COMPILER>
   ```

5. **Update `ci/matrix.yaml`** if CI coverage for the new combo is needed.
   See the `add-ci-matrix-job` skill.

6. **Push and verify** the `verify-devcontainers.yml` CI workflow passes.

## Naming convention

- Directory format: `cuda<VERSION>-<COMPILER><VERSION>` (e.g., `cuda13.1-gcc14`)
- Extended: `cuda<VERSION>-ext-<COMPILER><VERSION>` (e.g., `cuda13.1-ext-gcc14`)

## Troubleshooting

- **Docker image not found:** The NVIDIA base image for the new CTK may not be published yet.
- **Compiler missing in container:** The Docker image must include the compiler.
  Check the base image contents or the Dockerfile.
