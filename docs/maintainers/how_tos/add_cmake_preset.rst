How to Add a CMake Preset
=========================

When to use
-----------

A new CCCL subproject or build configuration needs a standardized CMake preset
for use by developers and CI.

Prerequisites
-------------

- Understanding of `CMake Presets <https://cmake.org/cmake/help/latest/manual/cmake-presets.7.html>`_
  (version 3 format)
- The project's CMakeLists.txt is already set up to be configured from the root

Steps
-----

1. **Open** ``CMakePresets.json`` **in the repository root.**

2. **Add a configure preset.**

   Configure presets inherit from the ``base`` hidden preset. Follow the
   existing naming convention: ``<project>`` or ``<project>-cpp<std>``.

   .. code-block:: json

      {
        "name": "myproject-cpp20",
        "inherits": "base",
        "displayName": "myproject-cpp20",
        "cacheVariables": {
          "CMAKE_CXX_STANDARD": "20",
          "CCCL_ENABLE_MYPROJECT": "ON"
        }
      }

   Key variables to set:

   - ``CCCL_ENABLE_<PROJECT>``: Enable the project's subdirectory
   - ``CCCL_ENABLE_UNSTABLE``: Required for experimental features (cudax)
   - ``CMAKE_CXX_STANDARD``: The C++ standard version
   - Any project-specific options

3. **Add build and test presets (if needed).**

   Build and test presets reference the configure preset by name. See existing
   entries for patterns.

4. **Verify the preset works.**

   .. code-block:: bash

      cmake --preset myproject-cpp20
      cmake --build --preset myproject-cpp20
      ctest --preset myproject-cpp20

5. **Update** ``ci/build_common.sh`` **or project-specific CI scripts if needed.**

   If the preset is used by CI, ensure the CI scripts reference it correctly.
   Presets used by ``build_and_test_targets.sh`` are passed via ``--preset``.

.. note::

   Build directories are placed under ``build/${CCCL_BUILD_INFIX}/${presetName}``.
   ``CCCL_BUILD_INFIX`` is set by devcontainers to isolate builds from
   different toolchains.

See also
--------

- :doc:`../infrastructure/cmake` — CMake build system architecture
- ``CONTRIBUTING.md`` — using presets for local development
