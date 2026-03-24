# benchmarks/ — Performance Benchmarking Framework

This directory contains the benchmark runner scripts, analysis tools, and
CMake integration for CCCL's performance benchmarking system, built on NVBench.

## Key Files

### Scripts (benchmarks/scripts/)

| Path | Purpose |
|------|---------|
| `run.py` | Main benchmark runner |
| `analyze.py` | Results analysis and reporting |
| `compare.py` | Compare results across multiple runs |
| `search.py` | Search through benchmark results |
| `verify.py` | Verify benchmark correctness |
| `sol.py` | Run specific benchmark tests |
| `submit_benchmark_job.sh` | Submit benchmark jobs to remote runners |

### Framework Library (benchmarks/scripts/cccl/bench/)

| Path | Purpose |
|------|---------|
| `cmake.py` | CMake integration for benchmark builds |
| `build.py` | Build management |
| `config.py` | Configuration handling |
| `storage.py` | Result storage and retrieval |
| `bench.py` | Benchmark execution logic |
| `logger.py` | Logging utilities |
| `score.py` | Result scoring and metrics |

### CMake Integration

| Path | Purpose |
|------|---------|
| `cmake/CCCLBenchmarkRegistry.cmake` | Macros for registering new benchmarks |

## Conventions

- CUB is the primary benchmark consumer — CUB benchmarks live in `cub/benchmarks/`.
- Benchmarks use NVBench as the underlying framework.
- Benchmark targets follow the naming pattern: `cub.bench.<algorithm>.<variant>`.
- Results are stored in a structured format for cross-run comparison.

## Warnings

- **Benchmarks require an NVIDIA GPU.** CPU-only environments cannot run benchmarks.
- **Performance measurements are noisy.** Run multiple iterations and compare
  medians, not single runs.
- **SASS diffs are the first-line check** for performance regressions. Only run
  full benchmarks if SASS has changed.

## Related Documentation

- `docs/maintainers/infrastructure/benchmarking.rst` — benchmarking architecture guide
- `docs/cub/benchmarking.rst` — CUB-specific benchmark details
- `.agents/skills/run-benchmarks.md` — step-by-step benchmark procedure
