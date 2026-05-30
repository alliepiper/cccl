---
name: cccl-ci-summarize-job-log
description: Summarize downloaded CCCL CI job logs — first error, failing step, exact command-line, 5–20 lines raw output, code/infra/flaky classification. Invoked by cccl-triage; full workflow in references/agent-prompt.md.
---

Summarize downloaded CI job logs for `cccl-triage`. Process each log in sequence; return a digest per log.

**Inputs** (from `cccl-triage` context):

- `logs: <path> [<path>...]` — downloaded job log paths.
- Optional per-log `context: <one-line hint>` — job name + toolchain.

For each log, follow `references/agent-prompt.md`. Collect all digests before returning.
