---
name: cccl-ci-overrides
description: Generate workflows.override matrix entries and [skip-*] tags from failed-job names or changed paths. Dispatched as owl-gp-sonnet by cccl-triage. System prompt in references/agent-prompt.md.
---

Dispatch model: `owl-gp-sonnet`. Full system prompt: `references/agent-prompt.md`.

Call inputs: `paths:` or `diff_range: <BASE>..<HEAD>` or `failed_jobs: <path>` (at least one), optional `for_workflow:`, working directory.
