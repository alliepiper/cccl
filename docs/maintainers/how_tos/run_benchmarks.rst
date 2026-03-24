How to Run Benchmarks
=====================

When to use
-----------

You need to measure performance, compare results across branches, or verify
that a change does not introduce a performance regression.

Prerequisites
-------------

- NVIDIA GPU
- CCCL development environment (devcontainer recommended)
- NVBench installed (pulled automatically during build)

Steps
-----

1. **Build the benchmarks.**

   CUB benchmarks are the primary benchmark targets. Build them using a CMake
   preset:

   .. code-block:: bash

      cmake --preset cub-cpp20
      cmake --build --preset cub-cpp20 --target cub.bench.radix_sort.keys.base

   Or build all benchmarks:

   .. code-block:: bash

      cmake --build --preset cub-cpp20 --target cub.all.benches

2. **Run a benchmark.**

   .. code-block:: bash

      ./build/<infix>/cub-cpp20/bin/cub.bench.radix_sort.keys.base

   Or use the benchmark runner script:

   .. code-block:: bash

      python benchmarks/scripts/run.py --benchmark cub.bench.radix_sort.keys

3. **Analyze results.**

   .. code-block:: bash

      python benchmarks/scripts/analyze.py --results <result_file>

4. **Compare results across runs or branches.**

   .. code-block:: bash

      python benchmarks/scripts/compare.py --baseline <baseline_file> --candidate <candidate_file>

Checking for SASS changes
--------------------------

Before running full benchmarks, check whether your changes affect generated
CUDA machine code (SASS). If SASS is unchanged, performance is unaffected.

1. **Build the benchmark binary on your branch:**

   .. code-block:: bash

      ninja cub.bench.radix_sort.keys.base
      cuobjdump -sass ./bin/cub.bench.radix_sort.keys.base | c++filt > after.sass

2. **Check out the baseline (main branch merge-base):**

   .. code-block:: bash

      git checkout $(git merge-base HEAD upstream/main)

3. **Build and dump the baseline SASS:**

   .. code-block:: bash

      ninja cub.bench.radix_sort.keys.base
      cuobjdump -sass ./bin/cub.bench.radix_sort.keys.base | c++filt > before.sass

4. **Compare:**

   .. code-block:: bash

      diff before.sass after.sass

   If there are no differences, the change has no performance impact for that
   algorithm and architecture.

See also
--------

- :doc:`../infrastructure/benchmarking` — benchmark framework architecture
- `docs/cub/benchmarking.rst <../../cub/benchmarking.rst>`_ — CUB-specific benchmark details
