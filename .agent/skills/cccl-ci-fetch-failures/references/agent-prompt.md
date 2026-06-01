## Inputs

1. **One of `pr: <PR#>` or `run: <RUN_ID>`** — selects the workflow run.
2. **`output: <path>`** — TSV destination.
3. **`scratch: <dir>`** — for raw API responses (nests under caller's sessionid: `/tmp/claude/<caller-sid>/<subtask>/`).
4. **Working directory** — absolute path; `pwd` to confirm.

Missing any → return `under-briefed: <what's missing>`.

## Workflow

### 1. Resolve run ID

**PR mode (`pr:` given):**

CCCL PRs run CI on the copy-pr-bot shadow branch `pull-request/<PR#>`, not on the feature
branch. `gh run list --branch <feature-branch>` returns only metadata workflows — do not use
it to find the CI run.

Step 1: Get HEAD SHA.
```
gh pr view <PR#> --repo NVIDIA/cccl --json headRefOid
```
Extract `headRefOid` as `HEAD_SHA`.

Step 2: Find the CI check run.
```
gh api "repos/NVIDIA/cccl/commits/<HEAD_SHA>/check-runs?per_page=100" > <scratch>/check_runs.json
```
Probe structure: `jq 'keys' <scratch>/check_runs.json` (expect `check_runs` array + `total_count`).

Step 3: Extract the run ID. Find the check run with `name == "CI"`. Prefer by conclusion:
`failure` > `action_required` > `in_progress` (null) > `success`. Among ties, take latest
`started_at`. The run ID is in `html_url` (format `.../runs/<RUN_ID>/jobs/<JOB_ID>`):
```
jq -r '
  .check_runs
  | map(select(.name == "CI"))
  | sort_by(.started_at) | reverse
  | sort_by(
      if   .conclusion == "failure"         then 0
      elif .conclusion == "action_required" then 1
      elif .conclusion == null              then 2
      elif .conclusion == "success"         then 3
      else 4 end)
  | .[0].html_url
' <scratch>/check_runs.json
```
Split on `/runs/`, take index 1, split on `/`, take index 0 → `RUN_ID`.

**Fallback** (no "CI" check found, or API failure):
```
gh run list --repo NVIDIA/cccl --branch pull-request/<PR_NUMBER> --json databaseId,conclusion --limit 5
```
Pick latest `conclusion == "failure"`, or latest overall. `RUN_ID = databaseId`.

**Run mode (`run:` given):** `RUN_ID = <run>` directly — skip to step 2.

Avoid `gh pr view --json statusCheckRollup` — returns 100k+ tokens on CCCL PRs.

### 2. Fetch jobs

```
gh api repos/NVIDIA/cccl/actions/runs/<RUN_ID>/jobs?per_page=100 --paginate > <scratch>/jobs_raw.json
```

`--paginate` concatenates objects; subsequent `jq` needs `-s`.

### 3. Extract failures and append grouping hints

Use a single `jq` query that extracts failures and synthesizes the
`<toolchain>|<project>|<variant>` grouping hint from the name field.
First probe structure: `Read` the first few lines of `jobs_raw.json`
(or `jq 'keys' <scratch>/jobs_raw.json`) to confirm the schema before
writing the extraction. If the file is very large, dispatch a subagent.

```
jq -s -r '
  [.[].jobs[] | select(.conclusion == "failure")] | .[] |
  [
    (.id | tostring),
    .name,
    (
      (.name |
        if test("\\[CTK")
        then capture("\\[(?<ctk>CTK[\\d.]+)\\s+(?<comp>[^C][^\\]]*?)\\s+C\\+\\+(?<std>\\d+)\\]") |
             "\(.ctk) \(.comp) C++\(.std)"
        else "unknown"
        end
      ) + "|" +
      (if   (.name | test("libcu\\+\\+|libcudacxx")) then "libcudacxx"
       elif (.name | test("[Tt]hrust"))              then "Thrust"
       elif (.name | test("[Cc][Uu][Bb]"))           then "CUB"
       elif (.name | test("[Cc]udax"))               then "cudax"
       elif (.name | test("[Pp]ython"))              then "Python"
       else "unknown" end) + "|" +
      (if   (.name | test("[Bb]uild"))              then "Build"
       elif (.name | test("[Tt]est"))               then "Test"
       elif (.name | test("HostLaunch"))            then "HostLaunch"
       elif (.name | test("DeviceLaunch"))          then "DeviceLaunch"
       elif (.name | test("TestNoLaunch"))          then "TestNoLaunch"
       else "unknown" end)
    )
  ] | @tsv
' <scratch>/jobs_raw.json > <output>
```

Empty `<output>` → `STATUS: NO_FAILURES`.

**Never write a Python script or bash helper script to parse or
transform data.** Use `jq` for JSON and `awk`/`sed -n` for
structured text — both are allow-listed. Process data directly
with these tools, not through opaque generated scripts.

Example output row:

```
74849038365	[CTK13.2 GCC15 C++20] cudax TestNoLaunch(amd64)	CTK13.2 GCC15 C++20|cudax|TestNoLaunch
```

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
