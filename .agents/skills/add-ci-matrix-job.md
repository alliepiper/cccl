# Add a CI Matrix Job

**Applicable areas:** `ci/matrix.yaml`, `.github/actions/workflow-build/`

## When to use

You need to add a new build or test job to the CI matrix — a new compiler,
GPU, CUDA toolkit, or project coverage.

## Prerequisites

- Understanding of `ci/matrix.yaml` format

## Steps

1. **Open `ci/matrix.yaml`** and find the target workflow (`pull_request`, `nightly`, or `weekly`).

2. **Add a job entry.** Fields:

   ```yaml
   - jobs: ['build']           # build, test, test_gpu, test_nolid, test_lid0, test_lid1, test_lid2, run_cpu, run_gpu, nvrtc, verify_codegen, install
     project: 'cub'            # cub, thrust, libcudacxx, cudax, cccl_c_parallel, cccl_c_stf, python, packaging, nvbench_helper, target
     ctk: '13.X'               # CUDA toolkit: '12.0', '12.X', '13.0', '13.X' (optional, defaults to current)
     std: 'max'                 # 'all', 'minmax', 'max', or specific: 17, 20
     cxx: ['gcc14', 'clang20'] # Compilers. Unversioned = latest (gcc, clang, msvc)
     gpu: 'rtxa6000'           # For test jobs: rtx2080, rtx4090, rtxa6000, h100, l4, rtxpro6000
     cpu: 'amd64'              # Optional: amd64, arm64
     sm: '90'                  # SM override (optional)
     cmake_options: '-DFOO=ON' # Extra CMake options (optional)
     args: '--preset ...'      # For project: 'target' only — passed to build_and_test_targets.sh
   ```

3. **Follow existing patterns.** Match the style of nearby entries for the same project.

4. **Test with an override matrix first:**

   ```yaml
   workflows:
     override:
       - {jobs: ['build'], project: 'cub', ctk: '13.X', std: 'max', cxx: ['gcc14']}
   ```

   > **Warning:** Override blocks merge. Set back to empty before final CI run.

5. **Push and verify** the job appears in the CI matrix summary.

## Troubleshooting

- **Job doesn't appear:** `inspect_changes.py` may prune it if only infra files changed.
- **Invalid entry:** `build-workflow.py` fails with an error — check the `build-workflow` job log.
