## Inputs

1. **One of `pr: <PR#>` or `run: <RUN_ID>`** — selects the workflow run.
2. **`output: <path>`** — TSV destination.
3. **`scratch: <dir>`** — for raw API responses (nests under caller's sessionid: `/tmp/claude/<caller-sid>/<subtask>/`).
4. **Working directory** — absolute path; `pwd` to confirm.

Missing any → return `under-briefed: <what's missing>`.

## Workflow

### 1. Resolve run ID

If `pr:` given:
- `gh pr view <PR#> --repo NVIDIA/cccl --json headRefName,headRefOid` → `BRANCH`, `HEAD_SHA`.
- `gh run list --repo NVIDIA/cccl --branch <BRANCH> --limit 5 --json databaseId,headSha,conclusion` → pick the latest entry where `headSha == HEAD_SHA`. No match → `STATUS: UNDER_BRIEFED, reason: no_run_for_head`.
- `RUN_ID = databaseId`.

Avoid `gh pr view --json statusCheckRollup` — returns 100k+ tokens on CCCL PRs.

### 2. Fetch jobs

```
gh api repos/NVIDIA/cccl/actions/runs/<RUN_ID>/jobs?per_page=100 --paginate > <scratch>/jobs_raw.json
```

`--paginate` concatenates objects; subsequent `jq` needs `-s`.

### 3. Extract failures

```
jq -s -r '[.[].jobs[] | select(.conclusion == "failure")] | .[] | [.id, .name] | @tsv' \
   <scratch>/jobs_raw.json > <scratch>/failed_jobs_raw.tsv
```

Empty → `STATUS: NO_FAILURES`. Write an empty file at `<output>`.

### 4. Append grouping hints

Per row, parse the name and append a tab-separated `<toolchain>|<project>|<variant>`:
- Toolchain: `[CTK<X> <COMPILER><VER> C++<STD>]` substring.
- Project: CUB / libcudacxx / Thrust / cudax / Python.
- Variant: Build / Test / HostLaunch / DeviceLaunch / TestNoLaunch / etc.

Example row:

```
74849038365	[CTK13.2 GCC15 C++20] cudax TestNoLaunch(amd64)	CTK13.2 GCC15 C++20|cudax|TestNoLaunch
```

Write to `<output>`.

## Output

```
STATUS: OK | NO_FAILURES | UNDER_BRIEFED

run_id: <RUN_ID>
total_failures: <N>

tally:
  <toolchain>|<project>|<variant>: <count>
  ...

output_path: <output>
```

## Stop conditions

- Missing `pr:` and `run:` → `STATUS: UNDER_BRIEFED`.
- No failed jobs → `STATUS: NO_FAILURES`.
- `gh api` non-zero exit → return raw stderr, `STATUS: UNDER_BRIEFED`.

## Hard prohibition

- No file mutations beyond the named output paths.
