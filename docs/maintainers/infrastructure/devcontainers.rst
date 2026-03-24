Development Containers
=====================

CCCL uses `Dev Containers <https://containers.dev/>`_ to provide reproducible
build environments for both local development and CI. Every CI job runs inside
one of these containers, so the same toolchain that validates a pull request is
available on a developer's workstation.

This page gives maintainers a high-level tour of the devcontainer system:
how the variants are organized, how to launch them, how they are generated,
and how they integrate with GPU passthrough, sccache, and CI verification.

For contributor-facing setup instructions, see
:file:`.devcontainer/README.md` and :file:`CONTRIBUTING.md`.

Key files
---------

.. list-table::
   :header-rows: 1
   :widths: 40 60

   * - Path
     - Purpose
   * - :file:`.devcontainer/devcontainer.json`
     - Top-level (default) devcontainer configuration; also serves as the
       template from which all variants are generated.
   * - :file:`.devcontainer/launch.sh`
     - Container launcher used by CI and local developers.
   * - :file:`.devcontainer/launch.py`
     - Python helper that merges devcontainer feature metadata with
       ``devcontainer.json`` and exports Docker variables for ``launch.sh``.
   * - :file:`.devcontainer/make_devcontainers.sh`
     - Generator script that reads ``ci/matrix.yaml`` and writes one
       ``devcontainer.json`` per CUDA-version / compiler combination.
   * - :file:`ci/matrix.yaml`
     - Single source of truth for the CUDA / compiler / OS matrix.
   * - :file:`.github/workflows/verify-devcontainers.yml`
     - CI workflow that ensures generated files stay in sync.


Architecture and container variants
------------------------------------

The ``.devcontainer/`` tree contains a top-level ``devcontainer.json`` plus
a subdirectory for every supported CUDA-toolkit / host-compiler pair. At the
time of writing there are 56 ``devcontainer.json`` files in total. Each
subdirectory follows the naming convention
``cuda<CTK_VERSION>-<COMPILER_VERSION>`` (for example,
``cuda12.9-gcc14`` or ``cuda13.1-llvm20``).

Variants whose directory name contains the ``ext`` suffix (for example,
``cuda12.9ext-gcc14``) use Docker images that ship additional CTK libraries
beyond the default set. These ``-ext`` variants set the container environment
variable ``CCCL_CUDA_EXTENDED=true``, and are selected at launch time with the
``--cuda-ext`` flag.

Every container exports a ``CCCL_BUILD_INFIX`` environment variable whose
value matches the subdirectory name (e.g. ``cuda12.9-gcc14``). CMake build
trees are placed under ``build/${CCCL_BUILD_INFIX}/${PRESET}``, which keeps
artefacts from different toolchains isolated when the same ``build/`` mount
is shared across containers.

All images are published under the ``rapidsai/devcontainers`` namespace on
Docker Hub.


``launch.sh`` usage and options
-------------------------------

:file:`.devcontainer/launch.sh` is the single entry point for starting a
devcontainer, whether from VSCode, a bare Docker session, or CI. It parses
options, resolves the correct ``devcontainer.json`` path, and then delegates to
either ``launch_docker`` (``-d`` / ``--docker`` mode) or ``launch_vscode``.

The most commonly used options are:

.. list-table::
   :header-rows: 1
   :widths: 30 70

   * - Flag
     - Description
   * - ``-d``, ``--docker``
     - Run the container via ``docker run`` instead of opening it in VSCode.
       Required for headless / CI use.
   * - ``-c``, ``--cuda <version>``
     - Select a CUDA Toolkit version (e.g. ``12.9``, ``13.1``).
   * - ``--cuda-ext``
     - Use the ``-ext`` variant with extended CTK libraries.
   * - ``-H``, ``--host <compiler>``
     - Select a host compiler (e.g. ``gcc14``, ``llvm20``).
   * - ``--gpus <request>``
     - GPU devices to pass through (e.g. ``all``). See
       :ref:`gpu-passthrough` below.
   * - ``-e``, ``--env <VAR=VAL>``
     - Set additional environment variables inside the container.
   * - ``-v``, ``--volume <spec>``
     - Bind-mount a volume.
   * - ``-- <script> [args...]``
     - Everything after ``--`` is executed inside the container once it starts.

When neither ``--cuda`` nor ``--host`` is supplied, the top-level
``.devcontainer/devcontainer.json`` is used. Otherwise the script resolves
the path ``.devcontainer/cuda<VERSION>-<COMPILER>/devcontainer.json``
(appending ``ext`` to the CUDA version when ``--cuda-ext`` is set).

Example: launch a Docker container with CUDA 13.1, GCC 14, and run a build
script:

.. code-block:: bash

   .devcontainer/launch.sh -d --cuda 13.1 --host gcc14 -- ci/build_cub.sh

Example: launch the same environment in VSCode (omit ``-d``):

.. code-block:: bash

   .devcontainer/launch.sh --cuda 13.1 --host gcc14

.. warning::

   The first launch of a container image pulls several gigabytes from Docker
   Hub. Subsequent starts reuse the cached image and are much faster.


Container generation
--------------------

:file:`.devcontainer/make_devcontainers.sh` is the script that generates the
variant subdirectories. It works as follows:

1. Parses :file:`ci/matrix.yaml` to discover every unique CUDA version,
   compiler name/version, and ``-ext`` flag.
2. Copies the top-level :file:`.devcontainer/devcontainer.json` as a template.
3. For each combination it emits a subdirectory
   ``cuda<VERSION>-<COMPILER>`` (or ``cuda<VERSION>ext-<COMPILER>``),
   adjusting only the Docker image tag, container name, and environment
   variables such as ``CCCL_BUILD_INFIX``, ``CCCL_CUDA_VERSION``,
   ``CCCL_HOST_COMPILER``, ``CCCL_HOST_COMPILER_VERSION``, and
   ``CCCL_CUDA_EXTENDED``.

Run it with ``--clean`` to remove stale subdirectories that no longer appear
in the matrix:

.. code-block:: bash

   .devcontainer/make_devcontainers.sh --clean

.. warning::

   Never hand-edit a generated ``devcontainer.json`` inside a
   ``cuda*`` subdirectory. The CI verification workflow will detect the
   drift and fail. Instead, change the template
   (:file:`.devcontainer/devcontainer.json`) or the matrix
   (:file:`ci/matrix.yaml`) and re-run ``make_devcontainers.sh``.


.. _gpu-passthrough:

GPU passthrough and runtime
---------------------------

Running GPU-dependent tests inside a container requires the
`NVIDIA Container Toolkit <https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html>`_
and a compatible host driver.

Pass ``--gpus all`` (or a specific device request) to ``launch.sh`` to enable
GPU access:

.. code-block:: bash

   .devcontainer/launch.sh -d --cuda 13.1 --host gcc14 --gpus all

In the ``devcontainer.json`` files, ``hostRequirements.gpu`` is set to
``"optional"``, meaning the container starts regardless of whether a GPU is
available. Building CCCL does not require a GPU; only running tests does.

.. warning::

   On WSL, the ``nvidia-container-toolkit`` must be installed **inside** the
   WSL distribution, not on the Windows host. The NVIDIA GPU driver, however,
   is installed on the Windows host and is automatically forwarded into WSL.


sccache integration and GitHub auth
------------------------------------

Every devcontainer is preconfigured with `sccache
<https://github.com/mozilla/sccache>`_ backed by an S3 bucket that is shared
with CI. This means a local build can reuse object files that CI already
compiled, dramatically reducing build times.

Relevant environment variables set in each ``devcontainer.json``:

- ``SCCACHE_REGION`` / ``SCCACHE_BUCKET`` -- S3 location of the shared cache.
- ``SCCACHE_S3_USE_PREPROCESSOR_CACHE_MODE`` -- enables the preprocessor cache
  mode for higher hit rates.
- ``AWS_ROLE_ARN`` -- IAM role assumed via GitHub OIDC to access the bucket.

To access the remote cache, authenticate with GitHub after the container
starts. VSCode prompts automatically; in Docker mode you can run the
``devcontainer-utils-vault-s3-init`` script manually.

.. warning::

   Remote sccache access is limited to members of the ``NVIDIA`` or
   ``rapidsai`` GitHub organisations. Without authentication the cache
   still works locally on the filesystem, but builds will not benefit from
   CI-produced artefacts.

For more details see the
`rapidsai/devcontainers usage guide <https://github.com/rapidsai/devcontainers/blob/main/USAGE.md#build-caching-with-sccache>`_.


Devcontainer verification CI
-----------------------------

The :file:`.github/workflows/verify-devcontainers.yml` workflow ensures
that the generated ``devcontainer.json`` files stay in sync with
``ci/matrix.yaml`` and the template.

The workflow performs these steps:

1. Runs ``make_devcontainers.sh --verbose --clean`` to regenerate all
   files from scratch.
2. Checks ``git diff`` and ``git status`` for any changes or untracked files.
   If differences exist, the job fails with an error indicating the files are
   out of date.
3. Inspects the diff between the PR head and base to decide whether
   devcontainer or matrix files were modified; if not, the remaining
   verification is skipped.
4. For each ``devcontainer.json`` (excluding ``cuda99.*`` test fixtures),
   a matrix job pulls the corresponding Docker image to verify it exists and
   is accessible.

The workflow runs only on the ``NVIDIA/cccl`` repository (not forks) to avoid
out-of-memory failures on public runners.

.. warning::

   If you modify ``ci/matrix.yaml`` or the devcontainer template, always
   re-run ``make_devcontainers.sh --clean`` and commit the resulting changes
   before pushing. The ``[skip-vdc]`` commit-message tag can temporarily skip
   this workflow during early iteration, but it **must** be removed before
   merge.
