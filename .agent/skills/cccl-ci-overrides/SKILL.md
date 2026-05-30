---
name: cccl-ci-overrides
description: Generate workflows.override matrix entries and [skip-*] tags from failed-job names or changed paths. Invoked by cccl-triage; full workflow in references/agent-prompt.md.
---

Generate the minimum `workflows.override` entries and `[skip-*]` tag set for a PR's CI scope. Invoked by `cccl-triage`.

**Inputs** (from `cccl-triage` context):

- At least one of: `paths:`, `diff_range: <BASE>..<HEAD>`, `failed_jobs: <path>`.
- Optional `for_workflow:` — `pull_request` (default) | `pull_request_lite` | `nightly` | `weekly`.

Follow `references/agent-prompt.md` for the full workflow.
