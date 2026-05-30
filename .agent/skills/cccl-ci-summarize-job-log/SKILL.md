---
name: cccl-ci-summarize-job-log
description: Summarize one downloaded CCCL CI job log — first error, failing step, exact command-line, 5–20 lines raw output, code/infra/flaky classification. Dispatched as owl-gp-haiku by cccl-triage. System prompt in references/agent-prompt.md.
---

Dispatch model: `owl-gp-haiku`. Full system prompt: `references/agent-prompt.md`.

Call inputs: `log: <path>`, optional `context: <one-line hint>`, working directory.
