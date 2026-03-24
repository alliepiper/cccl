How to Add a Devcontainer Variant
=================================

When to use
-----------

A new CUDA toolkit version or host compiler needs to be supported, requiring
a new devcontainer configuration.

Prerequisites
-------------

- Understanding of the naming convention: ``cuda<VERSION>-<COMPILER><VERSION>``
  (e.g., ``cuda13.1-gcc14``, ``cuda12.9-ext-clang20``)
- The base Docker image for the new CTK/compiler combination must exist

Steps
-----

1. **Run** ``make_devcontainers.sh`` **to regenerate all configurations.**

   .. code-block:: bash

      .devcontainer/make_devcontainers.sh

   This script generates devcontainer.json files from templates. It creates
   directories for each supported CTK × compiler combination.

2. **If adding a new CTK or compiler not already in the generation script:**

   Edit ``.devcontainer/make_devcontainers.sh`` and add the new version to the
   appropriate arrays (CUDA versions, compiler versions). Then re-run the
   script.

3. **Verify the new devcontainer builds.**

   .. code-block:: bash

      .devcontainer/launch.sh -d --cuda <VERSION> --host <COMPILER>

   This will pull the Docker image and start the container. Verify that the
   compiler and CUDA toolkit are correctly configured inside the container.

4. **Update** ``ci/matrix.yaml`` **if CI coverage is needed.**

   Add job entries for the new CTK/compiler combination. See
   :doc:`add_ci_matrix_job`.

5. **Test the devcontainer verification CI.**

   The ``verify-devcontainers.yml`` workflow validates all devcontainer
   configurations. Ensure it passes after your changes.

.. note::

   The ``-ext`` suffix variants include extended CTK libraries. These use
   ``--cuda-ext`` with ``launch.sh`` and are needed for projects that depend
   on libraries beyond the base CTK installation.

Troubleshooting
---------------

- **Docker image not found:** The base images are published by NVIDIA. If a
  new CTK version image is not yet available, the devcontainer will fail to
  launch. Check the NVIDIA container registry for available images.

- **Compiler not found in container:** The Docker image must include the
  specified compiler. If adding a new compiler version, you may need to update
  the Dockerfile or use a different base image.

See also
--------

- :doc:`../infrastructure/devcontainers` — devcontainer architecture
- ``.devcontainer/README.md`` — setup guide for local development
