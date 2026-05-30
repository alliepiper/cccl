---
name: cccl-ci-fetch-failures
description: Fetch failed CI jobs from a CCCL PR or run ID. Returns TSV of job-id/name/grouping-hint. Invoked by cccl-triage; full workflow in references/agent-prompt.md.
---

Fetch failed jobs for a PR or run; write a TSV for downstream clustering. Invoked by `cccl-triage`.

**Inputs** (from `cccl-triage` context):

- `pr: <PR#>` or `run: <RUN_ID>` — selects the workflow run.
- `output: <tsv-path>` — TSV destination.
- `scratch: <dir>` — for raw API responses (nest under caller's sessionid).

Follow `references/agent-prompt.md` for the full workflow.
