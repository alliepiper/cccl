# .devcontainer/ — Development Containers

This directory defines reproducible development environments for CCCL, used
by both local development and CI. Each environment pairs a CUDA Toolkit
version with a host compiler.

## Key Files

| Path | Purpose |
|------|---------|
| `launch.sh` | Main container launcher — used by CI and local development |
| `launch.py` | Python launcher helper |
| `make_devcontainers.sh` | Generates devcontainer.json files for all CTK×compiler combinations |
| `verify_devcontainer.sh` | Validates a container configuration (used by CI) |
| `devcontainer.json` | Base/default devcontainer configuration |
| `cccl-entrypoint.sh` | CCCL-specific container initialization |
| `docker-entrypoint.sh` | Docker container entry point |
| `README.md` | Setup guide for VSCode, WSL, and Docker |
| `img/` | Screenshots for the README |

## Container Variants

56+ versioned directories, each containing a `devcontainer.json`:

- **Naming convention:** `cuda<VERSION>-<COMPILER><VERSION>` (e.g., `cuda13.1-gcc14`, `cuda12.9-clang20`)
- **`-ext` suffix:** Extended CTK libraries (e.g., `cuda13.1-ext-gcc14`)
- **CUDA versions:** 12.0, 12.9, 13.0, 13.1, plus `-ext` variants
- **Compilers:** gcc7–14, clang14–20, llvm15–20, nvhpc
- Each container sets `CCCL_BUILD_INFIX` to isolate build directories per toolchain

## launch.sh Options

```
.devcontainer/launch.sh [OPTIONS] [-- <script> [args...]]

  -d, --docker        Run without VSCode (required for CI/agents)
  --cuda <version>    Select CUDA Toolkit version
  --cuda-ext          Use extended CTK image (more libraries)
  --host <compiler>   Select host compiler (e.g., gcc14, clang20)
  --gpus <request>    GPU devices ('all' for all GPUs)
  -e, --env KEY=VAL   Pass environment variables
  -v, --volume SRC:DST Mount volumes
  -- <script>         Run script inside container after setup
```

## Conventions

- CI always uses `-d` (Docker mode, no VSCode).
- `launch.sh` is the **single entry point** for both local and CI container usage.
- `CCCL_BUILD_INFIX` is set automatically — do not override it manually.
- First launch pulls the Docker image (slow); subsequent launches are cached.

## Warnings

- **Do not manually create devcontainer.json files.** Use `make_devcontainers.sh` to generate them from templates.
- **GPU passthrough requires** the NVIDIA Container Toolkit and an NVIDIA driver on the host.
- **sccache access** requires GitHub authentication and membership in the NVIDIA or rapidsai GitHub organizations.

## Related Documentation

- `README.md` (this directory) — setup guide
- `docs/maintainers/infrastructure/devcontainers.rst` — architecture guide
- `.agents/skills/add-devcontainer.md` — adding new variants
- `.agents/skills/reproduce-ci-failure.md` — using containers to debug CI
