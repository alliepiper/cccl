#!/usr/bin/env bash
# Idempotent per-worktree deployer for cccl-ap-skills.
# Run from within a CCCL worktree; called automatically by the post-checkout hook.
set -euo pipefail

SKILLS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ─── Safety guard ──────────────────────────────────────────────────────────────
if [[ "${1:-}" != "--i-know-what-im-doing" ]]; then
    echo "" >&2
    echo "################################################################################" >&2
    echo "##                                                                            ##" >&2
    echo "##  !!! FATAL: DO NOT RUN THIS WITHOUT READING THE README FIRST !!!         ##" >&2
    echo "##                                                                            ##" >&2
    echo "################################################################################" >&2
    echo "" >&2
    echo "  deploy.sh makes HARD-TO-UNDO changes to your CCCL checkout:" >&2
    echo "" >&2
    echo "    - Replaces AGENTS.md, CLAUDE.md, .agent/, .claude/skills/ with symlinks" >&2
    echo "    - Marks those paths --skip-worktree in each worktree's git index" >&2
    echo "    - Edits each worktree's info/exclude" >&2
    echo "    - Cannot be reversed with 'git restore' or a worktree reset" >&2
    echo "" >&2
    echo "  Full notes (read this first):" >&2
    echo "  ${SKILLS_ROOT}/README.md" >&2
    echo "" >&2
    echo "  If you have read the README and accept the consequences, re-run with:" >&2
    echo "    $(basename "$0") --i-know-what-im-doing" >&2
    echo "" >&2
    echo "################################################################################" >&2
    echo "" >&2
    exit 1
fi
shift

WORKTREE_ROOT="$(git rev-parse --show-toplevel)"
GIT_DIR="$(git rev-parse --absolute-git-dir)"

# Skip the cccl-ap-skills orphan-branch worktree itself.
if ! git merge-base main HEAD >/dev/null 2>&1; then
    echo "cccl-ap-skills: orphan branch — skipping deploy." >&2
    exit 0
fi

cd "$WORKTREE_ROOT"

# ─── 1. Committed paths: suppress git visibility, replace with symlinks ────────
#
# --skip-worktree tells git not to check the working-tree for these paths.
# Only applies to paths that are actually indexed on this branch.
for _path in \
    AGENTS.md \
    CLAUDE.md \
    ".agent/skills/libcudacxx-style/SKILL.md" \
    ".agent/skills/libcudacxx-test/SKILL.md" \
    ".claude/skills/libcudacxx-style/SKILL.md" \
    ".claude/skills/libcudacxx-test/SKILL.md"
do
    if git ls-files --error-unmatch "$_path" >/dev/null 2>&1; then
        git update-index --skip-worktree "$_path"
    fi
done

# Replace committed files/dirs with symlinks pointing at the skills repo.
_symlink() {
    local target="$1" path="$2" rm_flag="$3"
    if [ "$(readlink "$path" 2>/dev/null)" = "$target" ]; then
        return  # already correct
    fi
    rm "$rm_flag" "$path" 2>/dev/null || true
    ln -s "$target" "$path"
}

_symlink "${SKILLS_ROOT}/AGENTS.md"     AGENTS.md      -f
_symlink "${SKILLS_ROOT}/AGENTS.md"     CLAUDE.md      -f
_symlink "${SKILLS_ROOT}/.agent"        .agent         -rf
_symlink "${SKILLS_ROOT}/.agent/skills" .claude/skills -rf

# ─── 2. New (untracked) paths: add to info/exclude, then symlink ───────────────
#
# info/exclude is git's per-worktree gitignore that lives outside the tree.
# Symlinks replacing directories (like .agent, .claude/skills) also need
# info/exclude entries — --skip-worktree hides their contents from git's index
# comparison, but not the symlinks themselves from untracked-file scanning.
INFO_EXCLUDE="${GIT_DIR}/info/exclude"
mkdir -p "${GIT_DIR}/info"
touch "$INFO_EXCLUDE"

_new_symlink() {
    local pattern="$1" path="$2" target="$3"
    grep -qxF "$pattern" "$INFO_EXCLUDE" || echo "$pattern" >> "$INFO_EXCLUDE"
    if [ "$(readlink "$path" 2>/dev/null)" = "$target" ]; then
        return  # already correct
    fi
    if [ -f "$path" ] && [ ! -L "$path" ]; then
        echo "cccl-ap-skills: $path is a regular file — not replacing." >&2
        echo "  To use the skills-repo version: rm ${WORKTREE_ROOT}/${path} then re-run deploy.sh" >&2
        return
    fi
    if [ ! -e "$target" ]; then
        echo "cccl-ap-skills: $target not found — skipping $path symlink." >&2
        return
    fi
    rm -f "$path" 2>/dev/null || true
    ln -s "$target" "$path"
}

# Exclude the directory-replacing symlinks from untracked-file scanning.
grep -qxF ".agent" "$INFO_EXCLUDE" || echo ".agent" >> "$INFO_EXCLUDE"
grep -qxF ".claude/skills" "$INFO_EXCLUDE" || echo ".claude/skills" >> "$INFO_EXCLUDE"

_new_symlink ".claude/settings.json"       .claude/settings.json       "${SKILLS_ROOT}/.claude/settings.json"
_new_symlink ".claude/settings.local.json" .claude/settings.local.json "${SKILLS_ROOT}/.claude/settings.local.json"

echo "cccl-ap-skills: deployed to ${WORKTREE_ROOT}"
