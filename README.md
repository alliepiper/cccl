# cccl-ap-skills

Local-only agent skills and Claude Code configuration for the CCCL repository.
Lives on an orphan branch of the CCCL repo — shares git infrastructure but no history with `main`.

## What this provides

- **32 `cccl-*` and `cccl_detail-*` skills** covering CI, build, test, infra, triage, and more
- **3 `cccl-ci-*` agents** for CI job analysis and overrides
- **`AGENTS.md`** — the skill-aware project instructions that Claude Code loads at session start
- **`settings.json`** — project-scope Claude Code permission allow-list (gh, git, grep, etc.)
- **`settings.local.json`** — per-machine allow-list for skill and agent invocations

When deployed, a `post-checkout` hook replaces the CCCL repo's committed skill stubs and
config files with symlinks into this directory. All CCCL worktrees get the same skills
automatically on `git worktree add` or `git checkout`.

## First-time setup

**Prerequisites:** git ≥ 2.37 (for `--orphan` worktree support). Check: `git --version`.

The `cccl-ap-skills` worktree was already created as a sibling of the CCCL checkout at
`../cccl-ap-skills`. If you are setting up on a new machine, first create it:

```bash
# From the CCCL main checkout:
git worktree add --orphan -b cccl-ap-skills ../cccl-ap-skills

# Populate from ci_skills (adjust source path if different):
CI_SKILLS=/path/to/cccl/.claude/worktrees/ci_skills
cp -r "${CI_SKILLS}/.agent" ../cccl-ap-skills/.agent
cp "${CI_SKILLS}/AGENTS.md" ../cccl-ap-skills/AGENTS.md
mkdir -p ../cccl-ap-skills/.claude
cp "${CI_SKILLS}/.claude/settings.json" ../cccl-ap-skills/.claude/settings.json
cp "${CI_SKILLS}/.claude/settings.local.json" ../cccl-ap-skills/.claude/settings.local.json
```

> **Note:** `settings.local.json` is excluded from git by the global gitignore
> (`**/.claude/settings.local.json`). Copy or create it manually on each machine.
> If it is absent, `deploy.sh` skips the symlink and logs a warning — the project-scope
> `settings.json` is still deployed.

**Install the hook and deploy:**

```bash
cd ../cccl-ap-skills
./setup.sh
```

`setup.sh` does two things:
1. Installs a `post-checkout` hook at `<cccl>/.git/hooks/post-checkout`. This hook runs
   `deploy.sh` automatically whenever you do `git checkout` or `git worktree add` in any
   CCCL worktree.
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
     (skipped with a warning if the file already exists as a regular non-symlink file)

## Updating skills

Edit files directly in `cccl-ap-skills/`. Changes are visible immediately in all deployed
worktrees via symlinks — no re-deploy needed for content changes.

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
rm "$(git rev-parse --git-common-dir)/../.git/hooks/post-checkout"
# or:
rm /path/to/cccl/.git/hooks/post-checkout
```

New worktrees created after removing the hook will not be auto-deployed.

## Notes

- The hook scope-guards against the `cccl-ap-skills` orphan branch itself (detected via
  `git merge-base main HEAD` failing), so `git worktree add --orphan` operations are unaffected.
- `--skip-worktree` flags live in each worktree's index and do not propagate to other worktrees.
- Per-worktree `info/exclude` entries live under `<cccl>/.git/worktrees/<name>/info/exclude` and
  are cleaned up by `git worktree prune` when a worktree is removed.
- If `.claude/settings.local.json` was not symlinked (pre-existing regular file warning), the
  deployed worktree uses only the project-scope `settings.json`. Merge or replace manually.
