# cccl-ap-skills

Collection of agent skills for cccl that I found useful.
Feel free to pick and harvest for your own nest.

Warnings:

- These are agent written with light human review for accuracy.
- They may be outdated, as they live separately from the repo.
- I tried to avoid this as much as possible, but they undoubtedly encode some of my opinions and preferences.
- The setup / deploy scripts are NOT polished for general use. Read and understand carefully before using. Notably:
  - These modify all cccl worktrees and edit config under .git (to hide the symlink shims from git's index).
  - These do *not* clean up after themselves, and cannot be undone with a basic git worktree reset.
  - I suggest installing these to a user-scope skillset, or setting up similar shims that match your workflow.

AI wrote the rest of this, treat it as such.

---

## What this provides

- **35 `cccl-*` and `cccl_detail-*` skills** covering CI, build, test, infra, triage, and more
  - Includes `cccl-ci-fetch-failures`, `cccl-ci-overrides`, `cccl-ci-summarize-job-log` —
    skills that store agent system prompts in `references/agent-prompt.md` for dispatch
    by `cccl-triage` via `owl-gp-haiku` / `owl-gp-sonnet`.
- **`AGENTS.md`** — the skill-aware project instructions that Claude Code loads at session start
- **`settings.json`** — project-scope Claude Code permission allow-list (gh, git, grep, etc.)
- **`settings.local.json`** — per-machine allow-list for skill invocations (not committed; see below)

When deployed, a `post-checkout` hook replaces the CCCL repo's committed skill stubs and
config files with symlinks into this directory. All CCCL worktrees get the same skills
automatically on `git worktree add` or `git checkout`.

## First-time setup

**Prerequisites:** git ≥ 2.37 (for `--orphan` worktree support). Check: `git version`.

Create the worktree as a sibling of the CCCL checkout:

```bash
# From the CCCL main checkout:
git fetch origin cccl-ap-skills
git worktree add ../cccl-ap-skills cccl-ap-skills
```

> **`settings.local.json` is not committed** — excluded by the global gitignore
> (`**/.claude/settings.local.json`). Copy or create it manually on each machine.
> If absent, `deploy.sh` skips that symlink and logs a warning; `settings.json` is still deployed.

**Install the hook and deploy:**

```bash
cd ../cccl-ap-skills
./setup.sh
```

`setup.sh` does two things:
1. Installs a `post-checkout` hook at `<cccl>/.git/hooks/post-checkout`. This hook runs
   `deploy.sh` automatically on `git checkout` or `git worktree add` in any CCCL worktree.
2. Runs `deploy.sh` in the main CCCL checkout immediately so you don't have to re-checkout.

If a `post-checkout` hook already exists, the old file is backed up to `post-checkout.bak`.

## What `deploy.sh` does

`deploy.sh` is idempotent and safe to run multiple times.

For each CCCL worktree it is run in:

1. Marks the following committed paths `--skip-worktree` so git ignores working-tree
   divergence:
   - `AGENTS.md`, `CLAUDE.md`
   - `.agent/skills/libcudacxx-style/SKILL.md`, `.agent/skills/libcudacxx-test/SKILL.md`
   - `.claude/skills/libcudacxx-style/SKILL.md`, `.claude/skills/libcudacxx-test/SKILL.md`

2. Replaces those files/directories with symlinks into `cccl-ap-skills/`:
   - `AGENTS.md` → `../cccl-ap-skills/AGENTS.md`
   - `CLAUDE.md` → `../cccl-ap-skills/AGENTS.md`
   - `.agent/` → `../cccl-ap-skills/.agent/` (entire tree)
   - `.claude/skills/` → `../cccl-ap-skills/.agent/skills/`

3. Adds `.claude/settings.json` and `.claude/settings.local.json` to the worktree's
   `info/exclude` (so git never sees them), then symlinks them:
   - `.claude/settings.json` → `../cccl-ap-skills/.claude/settings.json`
   - `.claude/settings.local.json` → `../cccl-ap-skills/.claude/settings.local.json`
     (skipped with a warning if it already exists as a regular file)

## Updating skills

Edit files directly in `cccl-ap-skills/`. Changes are visible immediately in all deployed
worktrees via symlinks — no re-deploy needed for content changes.

**Committing changes to `.agent/` requires `git add -f`** — the repo-wide `info/exclude`
(written by `deploy.sh` for CCCL worktrees) lists `.agent` as an ignore pattern, which
affects this orphan-branch worktree too:

```bash
git add -f .agent/skills/my-skill/
git add README.md deploy.sh   # other paths commit normally
git commit -m "..."
```

If you add new top-level files to `.claude/` that need symlinking, run `deploy.sh` manually
in each worktree (or re-checkout the branch to trigger the hook).

## Manual re-deploy

To deploy to an existing worktree without re-checking out:

```bash
../cccl-ap-skills/deploy.sh
```

Run from within the CCCL worktree you want to deploy into.

## Undo (per worktree)

To restore a worktree to its committed state:

```bash
# From inside the CCCL worktree to restore:

# 1. Clear --skip-worktree flags
git update-index --no-skip-worktree \
    AGENTS.md CLAUDE.md \
    .agent/skills/libcudacxx-style/SKILL.md \
    .agent/skills/libcudacxx-test/SKILL.md \
    .claude/skills/libcudacxx-style/SKILL.md \
    .claude/skills/libcudacxx-test/SKILL.md

# 2. Remove symlinks
rm -f AGENTS.md CLAUDE.md .claude/settings.json .claude/settings.local.json
rm -rf .agent .claude/skills

# 3. Restore committed files from git
git checkout -- \
    AGENTS.md CLAUDE.md \
    .agent/skills/libcudacxx-style/SKILL.md \
    .agent/skills/libcudacxx-test/SKILL.md \
    .claude/skills/libcudacxx-style/SKILL.md \
    .claude/skills/libcudacxx-test/SKILL.md
```

## Undo (remove the hook)

```bash
rm /path/to/cccl/.git/hooks/post-checkout
```

New worktrees created after removing the hook will not be auto-deployed.

## Notes

- The hook scope-guards against the `cccl-ap-skills` orphan branch (detected via
  `git merge-base main HEAD` failing), so `git worktree add --orphan` operations are unaffected.
- `--skip-worktree` flags live in each worktree's index and do not propagate to other worktrees.
- Per-worktree `info/exclude` entries live under `<cccl>/.git/worktrees/<name>/info/exclude` and
  are cleaned up by `git worktree prune` when a worktree is removed.
- If `.claude/settings.local.json` was not symlinked (pre-existing regular file warning), the
  deployed worktree uses only the project-scope `settings.json`. Merge or replace manually.
- `deploy.sh` also adds `.agent` and `.claude/skills` to the main checkout's `info/exclude`
  (the common git dir, so it applies repo-wide). This is what requires `git add -f` here.
</thinking>
