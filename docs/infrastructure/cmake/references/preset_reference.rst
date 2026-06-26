.. _infra-cmake-preset-reference:

Preset reference
================

CCCL ships its CMake configurations as presets in ``CMakePresets.json``, using CMake's
`preset format <https://cmake.org/cmake/help/latest/manual/cmake-presets.7.html>`_. The file
defines 40+ presets covering each library, multiple C++ standards, special build
modes, and benchmarking. ``CMakePresets.json`` is the authoritative list.

Preset structure
----------------

Each preset belongs to one of three sections:

- ``configurePresets`` set the configuration: enabled libraries, build type, CUDA
  architectures, C++ standard, and per-library options. Every configure preset
  inherits from the hidden ``base`` preset, which selects the Ninja generator,
  Release mode, ``all-major-cccl`` architectures, and disables all libraries by
  default. A named preset enables the libraries and options it needs.
- ``buildPresets`` reference a configure preset by name. Some pin an explicit
  target list; most build everything the configuration enables.
- ``testPresets`` reference a configure preset and add CTest filters. Filters
  select a subset of tests by name regex. CUB launcher-mode presets and Thrust
  GPU/CPU splits are examples of this pattern.

A configure preset, its build preset, and its test preset share a name. Run all
three with the same ``<name>``.

Naming patterns
---------------

Preset names encode their scope:

- ``<project>`` — base configuration for one library: ``cub``, ``thrust``,
  ``libcudacxx``, ``cudax``.
- ``<project>-cpp<std>`` — a library pinned to a C++ standard: ``cub-cpp17``,
  ``cub-cpp20``, ``libcudacxx-cpp20``, ``thrust-cpp17``, ``cudax-cpp17``.
- ``all-dev`` — full-CCCL development: every library, testing, examples, and
  benchmarks, built for ``native`` architectures.
- ``all-dev-debug`` — ``all-dev`` in Debug mode with CUDA device debugging (``-G``).
- ``all-tidy`` — ``all-dev-debug`` with clang-tidy, pinned to C++17 and clang.
- ``benchmark`` and ``cub-benchmark`` — benchmark builds. ``cub-benchmark`` covers
  CUB only; ``benchmark`` adds Thrust and libcudacxx.
- ``cub-lid0`` / ``cub-lid1`` / ``cub-lid2`` / ``cub-nolid`` — CUB launcher modes
  (host, device, graph, none). Each also has ``-cpp17`` and ``-cpp20`` variants.
- ``install`` and ``install-unstable*`` — packaging configurations.
- ``cccl-c-parallel``, ``cccl-c-stf`` — C Parallel library configurations.

Using a preset
--------------

Configure, then build with the matching preset name::

   cmake --preset cub-cpp17
   cmake --build --preset cub-cpp17

Run the test preset of the same name with ``ctest``::

   ctest --preset cub-cpp17

Build output lands under ``build/<infix>/<presetName>/``, where the infix comes from
the ``CCCL_BUILD_INFIX`` environment variable (used for devcontainer isolation).
Distinct presets use distinct build directories and do not collide.

Listing available presets
-------------------------

``cmake --list-presets`` prints all configure presets::

   cmake --list-presets

List build and test presets separately::

   cmake --list-presets=build
   cmake --build --list-presets
   ctest --list-presets
