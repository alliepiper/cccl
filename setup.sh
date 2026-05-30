#!/usr/bin/env bash
# One-time machine setup: installs the post-checkout hook and deploys to the main checkout.
# Run from inside the cccl-ap-skills worktree.
set -euo pipefail

SKILLS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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
exec "${_SKILLS_ROOT}/deploy.sh"
HOOK_EOF

chmod +x "$HOOK_PATH"
echo "Installed hook: ${HOOK_PATH}"

# ─── 2. Deploy to the main CCCL worktree ──────────────────────────────────────

cd "$MAIN_WORKTREE"
"${SKILLS_ROOT}/deploy.sh"
