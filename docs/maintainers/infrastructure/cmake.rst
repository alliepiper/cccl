.. _infrastructure-cmake:

CMake Build System
==================

This guide provides a high-level overview of the CMake infrastructure that
drives CCCL's developer builds, CI pipelines, and installation packaging.  It
covers the root ``CMakeLists.txt``, preset system, shared modules, build
options, architecture handling, and install rules.

For day-to-day build commands see :ref:`build-and-bisect-tools`.


Project Structure & Root CMakeLists.txt
---------------------------------------

The root ``CMakeLists.txt`` is the entry point for every CCCL build.  It is
designed to serve two audiences: downstream consumers who pull CCCL via
``add_subdirectory()`` or CPM, and developers who build CCCL tests, examples,
and benchmarks directly.

Key details:

- **Minimum CMake version** -- 3.18 for ``add_subdirectory()`` consumption,
  3.21 for developer builds (enforced when ``CCCL_TOPLEVEL_PROJECT`` is true).
- **CMP0141 policy** -- Set to ``NEW`` so that MSVC embeds debug info instead
  of generating ``.pdb`` files, which is required for ``sccache``
  compatibility.
- **Top-level detection** -- ``CCCL_TOPLEVEL_PROJECT`` is ``ON`` when
  ``CMAKE_SOURCE_DIR`` equals the CCCL root.  This flag gates all
  developer-only logic (architecture validation, build checks, compiler
  interface targets, test infrastructure).
- **Project declaration** -- ``project(CCCL LANGUAGES CXX)``.  CUDA is
  enabled lazily by subprojects so that header-only consumption does not
  require a CUDA toolkit.
- **Subdirectory inclusion** -- ``libcudacxx``, ``cub``, and ``thrust`` are
  always added.  ``cudax``, ``c/``, ``test/``, ``examples/``, and
  ``nvbench_helper`` are gated behind ``CCCL_ENABLE_*`` options (see
  `Build Options & Configuration`_).

.. code-block:: cmake

   # Abbreviated flow of the root CMakeLists.txt:
   cmake_minimum_required(VERSION 3.18)

   # sccache compat
   if (POLICY CMP0141)
     cmake_policy(SET CMP0141 NEW)
   endif()

   # Top-level detection
   if ("${CMAKE_SOURCE_DIR}" STREQUAL "${CMAKE_CURRENT_LIST_DIR}")
     set(CCCL_TOPLEVEL_PROJECT ON)
   endif()

   project(CCCL LANGUAGES CXX)
   include(cmake/CCCLInstallRules.cmake)

   # add_subdirectory() fast-path for consumers
   if (NOT CCCL_TOPLEVEL_PROJECT)
     include(cmake/CCCLAddSubdir.cmake)
   endif()

   # Developer build setup (arch checks, dialect checks, modules)
   if (CCCL_TOPLEVEL_PROJECT)
     cmake_minimum_required(VERSION 3.21)
     include(cmake/CCCLCheckCudaArchitectures.cmake)
     include(cmake/CCCLDevBuildChecks.cmake)
     # ... remaining module includes ...
   endif()

   add_subdirectory(libcudacxx)
   add_subdirectory(cub)
   add_subdirectory(thrust)
   # Conditional subdirectories follow ...

.. warning::

   When CCCL is consumed via ``add_subdirectory()``, most developer modules
   are **not** loaded.  Only ``CCCLInstallRules``, ``CCCLAddSubdirHelper``,
   and ``CCCLAddSubdir`` are active in that path.  Do not assume that
   functions like ``cccl_configure_target`` are available outside a top-level
   build.


CMake Presets (CMakePresets.json)
---------------------------------

CCCL uses `CMake presets <https://cmake.org/cmake/help/latest/manual/cmake-presets.7.html>`_
(version 3) as the primary way to configure builds.  All CI jobs and developer
helper scripts reference presets by name.

Key properties of the preset file:

.. list-table::
   :header-rows: 1
   :widths: 30 70

   * - Property
     - Value / notes
   * - Generator
     - ``Ninja`` (all presets)
   * - Build directory
     - ``build/${CCCL_BUILD_INFIX}/${presetName}``
   * - Default arch
     - ``all-major-cccl`` (see `CUDA Architecture Handling`_)
   * - Default build type
     - ``Release``
   * - Unstable enabled
     - ``CCCL_ENABLE_UNSTABLE=true`` in the base preset

Preset hierarchy
~~~~~~~~~~~~~~~~

All configure presets inherit from a hidden ``base`` preset that establishes
defaults.  Project presets selectively enable one subproject and its tests:

.. list-table::
   :header-rows: 1
   :widths: 30 30 40

   * - Preset
     - Inherits
     - Enables
   * - ``libcudacxx``
     - ``base``
     - libcu++ and lit tests
   * - ``libcudacxx-cpp17``, ``libcudacxx-cpp20``
     - ``libcudacxx``
     - Standard override
   * - ``cub``, ``cub-cpp17``, ``cub-cpp20``
     - ``base`` / ``cub``
     - CUB tests, examples, header tests
   * - ``cub-nolid-*``, ``cub-lid0-*``, ``cub-lid1-*``, ``cub-lid2-*``
     - ``cub``
     - CUB launch-mode variants
   * - ``thrust``, ``thrust-cpp17``, ``thrust-cpp20``
     - ``base`` / ``thrust``
     - Thrust multiconfig (CPP, CUDA, OMP, TBB)
   * - ``cudax``, ``cudax-cpp17``, ``cudax-cpp20``
     - ``base`` / ``cudax``
     - cudax with CUDASTF
   * - ``cccl-c-parallel``
     - ``base``
     - C Parallel Library tests
   * - ``cccl-c-stf``
     - ``base``
     - C CUDASTF tests
   * - ``install``, ``install-unstable``, ``install-unstable-only``
     - ``base`` / ``install``
     - Packaging-only (skip build checks)
   * - ``all-dev``, ``all-dev-debug``
     - ``base`` / ``all-dev``
     - Everything enabled
   * - ``benchmark``, ``cub-benchmark``, ``cub-tune``
     - (standalone)
     - Benchmarking presets

Usage:

.. code-block:: bash

   # List available presets
   cmake --list-presets

   # Configure with a preset
   cmake --preset cub-cpp20

   # Build
   cmake --build --preset cub-cpp20


CMake Modules (cmake/\*.cmake)
-------------------------------

The ``cmake/`` directory contains shared modules that implement CCCL's build
logic.  They are grouped below by purpose.

Core
~~~~

.. list-table::
   :header-rows: 1
   :widths: 35 65

   * - Module
     - Purpose
   * - ``CCCLUtilities.cmake``
     - Helper functions (``cccl_execute_non_fatal_process``, etc.).  Included before all other CCCL modules.
   * - ``CCCLInstallRules.cmake``
     - ``cccl_generate_install_rules()`` -- drives all header and package installation.
   * - ``CCCLAddSubdir.cmake``
     - Lightweight ``find_package``-style inclusion for non-top-level builds.
   * - ``CCCLAddSubdirHelper.cmake``
     - Shared plumbing used by both ``CCCLAddSubdir`` and individual subprojects.
   * - ``CPM.cmake``
     - Vendored copy of `CPM.cmake <https://github.com/cpm-cmake/CPM.cmake>`_ for dependency fetching.
   * - ``AppendOptionIfAvailable.cmake``
     - Utility macro to probe and append compiler flags.

Build
~~~~~

.. list-table::
   :header-rows: 1
   :widths: 35 65

   * - Module
     - Purpose
   * - ``CCCLBuildCompilerTargets.cmake``
     - Creates ``cccl.compiler_interface`` with warning flags, exception/RTTI toggles, and sccache workarounds.
   * - ``CCCLConfigureTarget.cmake``
     - ``cccl_configure_target()`` -- applies standard CXX/CUDA standard, output directories, and extensions settings to a target.
   * - ``CCCLAddExecutable.cmake``
     - ``cccl_add_executable()`` -- wraps ``add_executable`` with CCCL configuration, metatargets, and optional CTest registration.
   * - ``CCCLEnsureMetaTargets.cmake``
     - ``cccl_ensure_metatargets()`` -- creates hierarchical Ninja build targets (e.g. ``ninja cudax`` builds all ``cudax.*`` targets).

Validation
~~~~~~~~~~

.. list-table::
   :header-rows: 1
   :widths: 35 65

   * - Module
     - Purpose
   * - ``CCCLCheckCudaArchitectures.cmake``
     - Resolves CCCL-specific architecture keywords (``all-major-cccl``, ``all-cccl``) by querying ``nvcc``.
   * - ``CCCLDevBuildChecks.cmake``
     - Validates that ``CMAKE_CXX_STANDARD`` and ``CMAKE_CUDA_STANDARD`` match; defaults both to 17 if unset.

Testing
~~~~~~~

.. list-table::
   :header-rows: 1
   :widths: 35 65

   * - Module
     - Purpose
   * - ``CCCLGenerateHeaderTests.cmake``
     - ``cccl_generate_header_tests()`` -- auto-generates a compilation test for every public header, with per-header define support.
   * - ``CCCLTestParams.cmake``
     - ``cccl_parse_variant_params()`` -- reads ``%PARAM%`` comments from test source files and expands them into parameterized test variants.

Dependencies
~~~~~~~~~~~~

.. list-table::
   :header-rows: 1
   :widths: 35 65

   * - Module
     - Purpose
   * - ``CCCLGetDependencies.cmake``
     - Macros for fetching external dependencies via CPM (Catch2, Boost, etc.) and internal helpers (``cccl_get_c2h``, ``cccl_get_cub``, ``cccl_get_thrust``, ...).

Tooling
~~~~~~~

.. list-table::
   :header-rows: 1
   :widths: 35 65

   * - Module
     - Purpose
   * - ``CCCLClangdCompileInfo.cmake``
     - Enables ``CMAKE_EXPORT_COMPILE_COMMANDS`` and symlinks ``compile_commands.json`` to the source root for clangd.
   * - ``PrintCTestRunTimes.cmake``
     - Standalone CMake script that parses CTest output and prints per-test runtimes sorted longest-first.
   * - ``PrintNinjaBuildTimes.cmake``
     - Standalone CMake script that parses ``.ninja_log`` and prints per-file build times sorted longest-first.
   * - ``CCCLHideThirdPartyOptions.cmake``
     - Marks third-party cache variables as ``ADVANCED`` to reduce noise in ``cmake-gui`` / ``ccmake``.


Build Options & Configuration
------------------------------

The root ``CMakeLists.txt`` declares the following cache options.  All default
to ``OFF`` unless a preset or the user sets them.

.. list-table::
   :header-rows: 1
   :widths: 35 15 50

   * - Option
     - Default
     - Effect
   * - ``CCCL_ENABLE_LIBCUDACXX``
     - OFF
     - Enable the libcu++ developer build
   * - ``CCCL_ENABLE_CUB``
     - OFF
     - Enable the CUB developer build
   * - ``CCCL_ENABLE_THRUST``
     - OFF
     - Enable the Thrust developer build
   * - ``CCCL_ENABLE_UNSTABLE``
     - OFF
     - Gate for all experimental/unstable subprojects
   * - ``CCCL_ENABLE_CUDAX``
     - OFF (requires ``UNSTABLE``)
     - Enable the cudax developer build
   * - ``CCCL_ENABLE_C_PARALLEL``
     - OFF
     - Enable the C Parallel Library
   * - ``CCCL_ENABLE_C_EXPERIMENTAL_STF``
     - OFF
     - Enable the C CUDASTF Library
   * - ``CCCL_ENABLE_TESTING``
     - OFF
     - Enable CCCL-level packaging tests
   * - ``CCCL_ENABLE_EXAMPLES``
     - OFF
     - Enable CCCL-level examples
   * - ``CCCL_ENABLE_BENCHMARKS``
     - OFF
     - Enable benchmarks (disabled on NVHPC)
   * - ``CCCL_ENABLE_NVBENCH_HELPER``
     - OFF
     - Enable the NVBench helper dev build
   * - ``CCCL_USE_LIBCXX``
     - OFF
     - Compile and link with libc++

``CCCL_ENABLE_CUDAX`` is special: when ``CCCL_ENABLE_UNSTABLE`` is ``OFF``,
``CCCL_ENABLE_CUDAX`` is forced to ``OFF`` regardless of the cache value via a
directory-scoped shadow variable.

The ``CCCLDevBuildChecks`` module additionally enforces that
``CMAKE_CXX_STANDARD`` and ``CMAKE_CUDA_STANDARD`` match in developer builds,
defaulting both to **17** when neither is set.

.. warning::

   Setting ``CMAKE_CXX_STANDARD`` without ``CMAKE_CUDA_STANDARD`` (or vice
   versa) in a developer build is a fatal configuration error.  Always set
   both, or let the defaults apply.


CUDA Architecture Handling
--------------------------

CCCL extends CMake's ``CMAKE_CUDA_ARCHITECTURES`` with two custom keywords
processed by ``CCCLCheckCudaArchitectures.cmake``:

- ``all-major-cccl`` -- All major architectures supported by the detected
  ``nvcc`` that are at or above the CCCL minimum (currently SM 75 / Turing).
  This is the default for preset builds and CI.
- ``all-cccl`` -- All architectures (major and minor) at or above the CCCL
  minimum.

The module queries ``nvcc --list-gpu-arch`` at configure time, filters the
results, and replaces the cache variable with an explicit semicolon-separated
list of ``XX-real`` entries plus a trailing ``XX-virtual`` entry for the
highest architecture.

Standard CMake values are also supported:

.. list-table::
   :header-rows: 1
   :widths: 20 80

   * - Syntax
     - Meaning
   * - ``XX``
     - Generate both PTX and SASS for SM ``XX``
   * - ``XX-real``
     - Generate only SASS
   * - ``XX-virtual``
     - Generate only PTX
   * - ``native``
     - Detect host GPU at configure time (CMake 3.24+)

.. warning::

   ``all-major-cccl`` and ``all-cccl`` are CCCL-specific extensions.  They
   will not work in projects that do not include
   ``CCCLCheckCudaArchitectures.cmake``.  When consuming CCCL as a
   dependency, set ``CMAKE_CUDA_ARCHITECTURES`` to a standard value.


Installation & Packaging
------------------------

CCCL installs as a single umbrella package (``find_package(CCCL)``), with
individual component packages for each library (``find_package(CUB)``,
``find_package(Thrust)``, etc.).

Install rules are driven by ``cmake/CCCLInstallRules.cmake``, which provides
the ``cccl_generate_install_rules()`` function.  Per-project install
declarations live in ``cmake/install/``:

.. list-table::
   :header-rows: 1
   :widths: 30 70

   * - File
     - What it installs
   * - ``cmake/install/cccl.cmake``
     - CCCL umbrella CMake package (no headers)
   * - ``cmake/install/libcudacxx.cmake``
     - ``cuda/`` and ``nv/`` include trees + CMake package
   * - ``cmake/install/cub.cmake``
     - ``*.cuh`` headers + CMake package
   * - ``cmake/install/thrust.cmake``
     - ``*.h`` and ``*.inl`` headers + CMake package
   * - ``cmake/install/cudax.cmake``
     - ``cuda/`` include tree (``*.cuh``) + CMake package

Each call to ``cccl_generate_install_rules()`` creates a cache option named
``<PROJECT>_ENABLE_INSTALL_RULES`` that defaults to ``ON`` for top-level
builds.  The ``install`` and ``install-unstable`` presets configure CCCL
specifically for packaging, skipping build checks and optionally excluding
unstable libraries.

.. code-block:: bash

   # Install stable libraries only
   cmake --preset install
   cmake --build --preset install --target install

   # Install including experimental libraries
   cmake --preset install-unstable
   cmake --build --preset install-unstable --target install

``CMAKE_SKIP_INSTALL_ALL_DEPENDENCY`` is set to ``TRUE`` because CCCL is
header-only and has no compiled artifacts.  Running ``cmake --install`` does
not require a preceding build step.
