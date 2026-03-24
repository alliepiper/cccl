# Override the CI Matrix

**Applicable areas:** `ci/matrix.yaml`

## When to use

You want to limit a PR's CI run to a subset of jobs for faster iteration —
infrastructure changes, specific compiler fixes, or nightly failure debugging.

## Steps

1. **Add entries under `override` in `ci/matrix.yaml`:**

   ```yaml
   workflows:
     override:
       - {jobs: ['test'], project: 'thrust', std: 17, ctk: '12.X', cxx: ['gcc12', 'clang16']}
     pull_request:
       # ... leave unchanged ...
   ```

2. **Combine with skip tags** for further reduction:

   ```bash
   git commit -m "Debug thrust gcc12 [skip-vdc][skip-docs][skip-tpt]"
   ```

3. **For targeted tests, use `project: 'target'`:**

   ```yaml
   override:
     - {jobs: ['run_cpu'], project: 'target', ctk: '13.X', cxx: ['gcc'],
        args: '--preset cub-cpp20 --build-targets "cub.cpp20.test.iterator"'}
     - {jobs: ['run_gpu'], project: 'target', ctk: '13.X', cxx: ['gcc'], gpu: 'rtx2080',
        args: '--preset cub-cpp20 --build-targets "cub.cpp20.test.iterator" --ctest-targets "cub.cpp20.test.iterator"'}
     - {jobs: ['run_cpu'], project: 'target', ctk: '13.X', cxx: ['gcc'],
        args: '--preset libcudacxx --lit-precompile-tests "cuda/utility/basic_any.pass.cpp"'}
     - {jobs: ['run_gpu'], project: 'target', ctk: '13.X', cxx: ['gcc'], gpu: 'rtx2080',
        args: '--preset libcudacxx --lit-tests "cuda/utility/basic_any.pass.cpp"'}
   ```

4. **Before merging, remove the override** (set to empty, don't delete the key):

   ```yaml
   workflows:
     override:

     pull_request:
       # ...
   ```

   > **Warning:** Override blocks merge. `workflow-results` intentionally fails when override is present.

5. **Push final commit** to trigger full CI without override.
