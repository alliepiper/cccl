# Run Benchmarks

**Applicable areas:** `benchmarks/`, `cub/benchmarks/`, `docs/cub/benchmarking.rst`

## When to use

You need to measure performance, compare results, or check for regressions.

## Prerequisites

- NVIDIA GPU
- CCCL dev environment (devcontainer recommended)

## Steps

### Quick SASS check (do this first)

If SASS is unchanged, performance is unaffected — no need for full benchmarks.

1. **Build the benchmark on your branch:**

   ```bash
   cmake --preset cub-cpp20
   ninja -C build/<infix>/cub-cpp20 cub.bench.radix_sort.keys.base
   cuobjdump -sass build/<infix>/cub-cpp20/bin/cub.bench.radix_sort.keys.base | c++filt > after.sass
   ```

2. **Build baseline (main merge-base):**

   ```bash
   git stash && git checkout $(git merge-base HEAD upstream/main)
   ninja -C build/<infix>/cub-cpp20 cub.bench.radix_sort.keys.base
   cuobjdump -sass build/<infix>/cub-cpp20/bin/cub.bench.radix_sort.keys.base | c++filt > before.sass
   git checkout - && git stash pop
   ```

3. **Compare:** `diff before.sass after.sass`

   If no differences → no performance impact. Done.

### Full benchmark run

1. **Build:**

   ```bash
   cmake --preset cub-cpp20
   cmake --build --preset cub-cpp20 --target cub.bench.radix_sort.keys.base
   ```

2. **Run:**

   ```bash
   python benchmarks/scripts/run.py --benchmark cub.bench.radix_sort.keys
   ```

3. **Analyze:**

   ```bash
   python benchmarks/scripts/analyze.py --results <result_file>
   ```

4. **Compare across branches:**

   ```bash
   python benchmarks/scripts/compare.py --baseline <baseline> --candidate <candidate>
   ```

## Troubleshooting

- **Noisy results:** Run multiple iterations, compare medians.
- **Different GPU:** Results are not comparable across GPU architectures.
