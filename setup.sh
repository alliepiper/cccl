#!/usr/bin/env bash
# One-time machine setup: installs the post-checkout hook and deploys to the main checkout.
# Run from inside the cccl-ap-skills worktree.
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
    echo "  setup.sh installs a post-checkout hook into your CCCL repo's .git and then" >&2
    echo "  runs deploy.sh, which makes HARD-TO-UNDO changes to your CCCL checkout:" >&2
    echo "" >&2
    echo "    - Installs a post-checkout hook that auto-deploys to every worktree" >&2
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

# The cccl-ap-skills worktree is a linked worktree of the main CCCL repo.
# --git-common-dir points at the main .git directory regardless of which worktree we are in.
GIT_COMMON_DIR="$(cd "$(git rev-parse --git-common-dir)" && pwd)"
MAIN_WORKTREE="$(dirname "$GIT_COMMON_DIR")"
HOOKS_DIR="${GIT_COMMON_DIR}/hooks"

# ─── 1. Install post-checkout hook ────────────────────────────────────────────

HOOK_PATH="${HOOKS_DIR}/post-checkout"
mkdir -p "$HOOKS_DIR"

if [ -f "$HOOK_PATH" ]; then
    echo "cccl-ap-skills: existing hook found at ${HOOK_PATH}" >&2
    echo "  Backing up to ${HOOK_PATH}.bak" >&2
    cp "$HOOK_PATH" "${HOOK_PATH}.bak"
fi

cat > "$HOOK_PATH" << 'HOOK_EOF'
#!/usr/bin/env bash
# cccl-ap-skills: deploy skills into each CCCL worktree on branch-switch.
[ "$3" = "1" ] || exit 0
_GIT_COMMON="$(git rev-parse --git-common-dir)"
_SKILLS_ROOT="$(cd "${_GIT_COMMON}/.." && pwd)/../cccl-ap-skills"
[ -d "$_SKILLS_ROOT" ] || exit 0
git merge-base main HEAD >/dev/null 2>&1 || exit 0
exec "${_SKILLS_ROOT}/deploy.sh" --i-know-what-im-doing
HOOK_EOF

chmod +x "$HOOK_PATH"
echo "Installed hook: ${HOOK_PATH}"

# ─── 2. Deploy to the main CCCL worktree ──────────────────────────────────────

cd "$MAIN_WORKTREE"
"${SKILLS_ROOT}/deploy.sh" --i-know-what-im-doing
