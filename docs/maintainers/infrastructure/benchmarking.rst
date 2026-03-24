Benchmarking
============

CCCL uses `NVBench <https://github.com/NVIDIA/nvbench>`_ as its benchmarking
framework.  The ``benchmarks/`` directory at the repository root contains runner
scripts, CMake integration, and a shared Python library that together form the
benchmarking infrastructure.  CUB is the primary consumer of this system today;
for CUB-specific details (building, running, comparing, profiling, and
authoring benchmarks) see :doc:`/cub/benchmarking`.


Runner scripts
--------------

Top-level scripts live in ``benchmarks/scripts/``:

.. list-table::
   :header-rows: 1
   :widths: 25 75

   * - Script
     - Purpose
   * - ``run.py``
     - Main benchmark runner.  Builds and executes benchmarks, stores results
       in an SQLite database (``cccl_meta_bench.db``).
   * - ``analyze.py``
     - Extracts samples from a tuning database into per-variant JSON files.
   * - ``compare.py``
     - Compares two tuning databases and prints a Markdown report of runtime
       differences.
   * - ``search.py``
     - Brute-force search over tuning parameter spaces.
   * - ``verify.py``
     - Verifies a specific tuning variant.
   * - ``sol.py``
     - Plots benchmark results from one or more databases as bar or box charts.

Example usage from a CMake build directory:

.. code-block:: bash

   # Run all benchmarks
   PYTHONPATH=../benchmarks/scripts ../benchmarks/scripts/run.py

   # Run a subset filtered by regex and axis constraints
   PYTHONPATH=../benchmarks/scripts ../benchmarks/scripts/run.py \
       -R '.*scan.exclusive.sum.*' \
       -a 'Elements{io}[pow2]=[24,28]' -a 'T{ct}=I32'

   # Compare two databases
   ../benchmarks/scripts/compare.py -o cccl_meta_bench_base.db cccl_meta_bench_new.db

   # Extract per-variant JSON from a database
   ../benchmarks/scripts/analyze.py -o ./cccl_meta_bench.db

   # Plot results (requires matplotlib, seaborn, tabulate, PyQt5)
   ../benchmarks/scripts/sol.py cccl_meta_bench.db


Framework library
-----------------

The ``benchmarks/scripts/cccl/bench/`` package provides the shared Python
modules used by the runner scripts:

.. list-table::
   :header-rows: 1
   :widths: 20 80

   * - Module
     - Role
   * - ``bench.py``
     - Core benchmark execution logic (build, run, collect results).
   * - ``cmake.py``
     - CMake interaction -- invokes configure/build steps and tracks build
       metadata.
   * - ``build.py``
     - Lightweight data class recording a build's return code and elapsed time.
   * - ``config.py``
     - Defines tuning parameter ranges, workload spaces, and Cartesian-product
       iteration.
   * - ``storage.py``
     - SQLite (and optional PostgreSQL) storage backend for benchmark results.
   * - ``logger.py``
     - Logging utilities for benchmark output.
   * - ``score.py``
     - Computes workload weights and axis identifiers used during scoring and
       comparison.
   * - ``search.py``
     - Search algorithms for tuning parameter exploration.


CMake integration
-----------------

``benchmarks/cmake/CCCLBenchmarkRegistry.cmake`` provides the registration
functions used by CUB (and potentially other subprojects) to declare
benchmarks:

- ``create_benchmark_registry()`` -- initialises the CSV registry with the
  current CTK version and CCCL Git revision.
- ``register_cccl_benchmark(<name>)`` -- registers a benchmark target.
- ``register_cccl_tuning(<name> <ranges>)`` -- registers a tuning benchmark
  with explicit parameter ranges.

CUB benchmarks live under ``cub/benchmarks/`` and use the ``benchmark`` CMake
preset:

.. code-block:: bash

   cmake .. --preset=benchmark
   ninja cub.all.benches          # build every CUB benchmark
   ninja -t targets | grep '\.bench\.'  # list individual targets


Performance regression checking (SASS diffs)
---------------------------------------------

When a change could affect ``Device*`` algorithms in CUB, contributors should
verify that the generated SASS code is unchanged before and after the
modification.  The full process is documented in ``CONTRIBUTING.md`` and
``AGENTS.md``; the condensed steps are:

1. **Identify affected algorithms** -- determine which ``Device*`` algorithm(s)
   depend on the modified code.  Make sure the relevant GPU architectures are
   included at compile time (``-DCMAKE_CUDA_ARCHITECTURES`` or the ``-arch``
   flag).

2. **Build and dump candidate SASS** -- compile the benchmark for the algorithm
   and dump the assembly:

   .. code-block:: bash

      ninja cub.bench.radix_sort.keys.base
      cuobjdump -sass ./bin/cub.bench.radix_sort.keys.base | c++filt > radix_sort.keys_after.sass

3. **Build and dump baseline SASS** -- check out the merge-base with ``main``,
   rebuild, and dump again:

   .. code-block:: bash

      git checkout $(git merge-base HEAD upstream/main)
      ninja cub.bench.radix_sort.keys.base
      cuobjdump -sass ./bin/cub.bench.radix_sort.keys.base | c++filt > radix_sort.keys_before.sass

4. **Diff with noise filtered out** -- compare the two dumps:

   .. code-block:: bash

      git diff --text --no-index --word-diff radix_sort.keys_before.sass radix_sort.keys_after.sass

   Apply normalization before drawing conclusions:

   - Strip addresses, offsets, and hex location prefixes.
   - Remove build IDs, timestamps, absolute paths, and compiler banners.
   - Collapse whitespace to single spaces; drop empty and comment-only lines.

   Ignore trivial differences such as register renaming with an identical
   instruction sequence, label renumbering, and formatting-only changes.

5. **If SASS differs** -- run the benchmarks (see :doc:`/cub/benchmarking`) to
   quantify runtime impact and report the results in your pull request.
