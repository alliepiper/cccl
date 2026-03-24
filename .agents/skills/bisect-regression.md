# Bisect a Regression

**Applicable areas:** `ci/util/git_bisect.sh`, `.devcontainer/`

## When to use

A test or build that previously worked is now failing. You need to find the
commit that introduced the regression.

## Prerequisites

- A build/test target that reproduces the failure
- Knowledge of a "good" point (commit, tag, or relative date)

## Steps

1. **Basic bisect** (latest release → origin/main):

   ```bash
   ci/util/git_bisect.sh \
     --preset cub-cpp20 \
     --build-targets "cub.cpp20.test.iterator" \
     --ctest-targets "cub.cpp20.test.iterator"
   ```

2. **Narrow the range** with `--good-ref` / `--bad-ref`:

   ```bash
   ci/util/git_bisect.sh \
     --preset cub-cpp20 \
     --build-targets "cub.cpp20.test.iterator" \
     --ctest-targets "cub.cpp20.test.iterator" \
     --good-ref -7d \
     --bad-ref -1d
   ```

   `-Nd` means "origin/main N days ago."

3. **In a devcontainer** for specific CTK/compiler:

   ```bash
   .devcontainer/launch.sh -d --cuda 12.9 --host gcc13 --gpus all -- \
     ci/util/git_bisect.sh \
       --preset cub-cpp20 \
       --build-targets "cub.cpp20.test.iterator" \
       --ctest-targets "cub.cpp20.test.iterator" \
       --good-ref -14d
   ```

4. **Compute-sanitizer bisect:**

   ```bash
   .devcontainer/launch.sh -d --cuda 12.9 --host gcc13 --gpus all \
     --env CCCL_TEST_MODE=compute-sanitizer-initcheck \
     --env C2H_SEED_COUNT_OVERRIDE=1 \
     -- ci/util/git_bisect.sh \
       --preset cub-cpp20 \
       --build-targets "cub.cpp20.test.iterator" \
       --ctest-targets "cub.cpp20.test.iterator" \
       --good-ref -28d --bad-ref -21d
   ```

5. **Remote bisect** (for long-running bisections): Go to
   **Actions → Git Bisect → Run workflow** on GitHub. Produces a Markdown
   report with culprit commit, PR, and reproduction steps.

## For libcudacxx lit tests

Use `--lit-precompile-tests` and `--lit-tests` instead of `--build-targets` / `--ctest-targets`:

```bash
ci/util/git_bisect.sh \
  --preset libcudacxx \
  --lit-precompile-tests "std/algorithms/alg.nonmodifying/alg.any_of/any_of.pass.cpp" \
  --lit-tests "std/algorithms/alg.nonmodifying/alg.any_of/any_of.pass.cpp"
```

## Troubleshooting

- **Too slow:** Narrow `--good-ref`/`--bad-ref` range and minimize build targets.
- **Skipped commits:** Normal — git bisect marks uncompilable commits as `skip`.
