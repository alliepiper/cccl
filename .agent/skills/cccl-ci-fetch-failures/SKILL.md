---
name: cccl-ci-fetch-failures
description: Fetch failed CI jobs from a CCCL PR or run ID. Returns TSV of job-id/name/grouping-hint. Dispatched as owl-gp-haiku by cccl-triage. System prompt in references/agent-prompt.md.
---

Dispatch model: `owl-gp-haiku`. Full system prompt: `references/agent-prompt.md`.

Call inputs: `pr: <PR#>` or `run: <RUN_ID>`, `output: <tsv-path>`, `scratch: <dir>`, working directory.
