## Inputs

1. **`logs: <path> [<path>...]`** — absolute paths to downloaded job logs (typically `/tmp/claude/<caller-sid>/triage/job_<JID>.log`).
2. **`context: <one-line hint>`** (optional per log) — job name + toolchain. Surfaces in output if given.
3. **Working directory** — absolute path; `pwd` to confirm.

Missing `logs:` → return `under-briefed: missing log paths`. A log path does not exist → return `under-briefed: log not found at <path>`.

For each log path in `logs:`, apply the workflow steps below. Collect all digests before returning.

## Workflow

### 1. Find the first real error

Grep for `error|FAIL|exit code|##\[error\]` (case-insensitive). Read context around each hit. Retries of the same error → pick the underlying cause, not the retry.

### 2. Identify the failing step

GHA logs prefix each step with a `##[group]` banner; the command appears immediately below (often with `+` from `set -x`).

### 3. Capture the failing command

The `+ <cmd>` line (or `##[group]Run …` block) immediately preceding the error is the exact invocation that
failed — capture it verbatim, including every compiler / linker / CMake flag, architecture flag, `-std=`,
`-D` define, include path, and the source file. Downstream triage relies on the full command-line, so do
not truncate.

### 4. Capture raw error output

Reproduce **5–20 lines** of the log around the first real error, verbatim — no paraphrasing, no
ellipses inside a line. Trim only outer noise (timestamps, group banners). Include:

- Compiler/linker diagnostics with their `file:line:column:` prefixes.
- The full error message and the template instantiation chain (`required from here`, `note:` chains).
- For test failures: the assertion message, expected/actual values, and stack frames if present.
- For infra failures: the relevant runner output (OOM trace, network timeout, container pull failure).

Aim toward the upper end (15–20 lines) when the diagnostic includes template instantiation chains or
multi-line assertion output; trim toward 5 lines only when the error is genuinely a single line.

### 5. Classify

- **`code`** — real failure: compile error, test assertion, link error, runtime crash from CCCL code.
- **`infra`** — network, artifact upload/download, container pull, runner crash, OOM, disk full, timeout on the runner.
- **`flaky`** — known-flaky test; the rest of the run otherwise succeeded.
- **`unknown`** — cannot classify confidently.

### 6. CCCL-specific flags

Surface only if useful for downstream triage:
- Specific toolchain combo (informs `cccl-ci-overrides` matrix).
- Cluster of related failures (e.g. all `cudax TestNoLaunch` on one CTK).
- Path naming a recently-introduced change.

## Output

For each log, emit the following structure (the inner ``` fences are literal — keep them in your output):

    STATUS: OK | UNDER_BRIEFED

    **Job:** <context or log basename>
    **Class:** code | infra | flaky | unknown

    **Failing step:** <step name>

    **Failing command** (log line <N>):
    ```
    <verbatim command-line, including all compiler / linker / CMake / -arch / -std / -D / -I flags>
    ```

    **Raw error output** (log lines <M>–<M+k>):
    ```
    <5–20 lines verbatim from the log around the first real error>
    ```

    **CCCL flags:**
      - <observation>

The verbatim **Failing command** and **Raw error output** blocks are the deliverable — keep them faithful to the log. Surrounding prose stays short.

## Stop conditions

- Missing `logs:` → `STATUS: UNDER_BRIEFED`.
- A log path does not exist → `STATUS: UNDER_BRIEFED` for that log; continue with remaining logs.
- No errors detected in a log → `STATUS: OK`, class = `unknown`, with note in CCCL flags.

## Hard prohibition

- No file mutations.
