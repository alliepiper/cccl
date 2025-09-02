Add this to your Codex environment script:

```bash
# Optional: override the installed CTK. Use 'latest' to use newest available (default).
# export CTK_DEFAULT_VERSION=12.9

readonly url_base="https://raw.githubusercontent.com/alliepiper/cccl/codex_util"

mkdir -p .codex
if [[ ! -f .codex/env.sh ]]; then
  curl -L -o .codex/env.sh "${url_base}/.codex/env.sh"
  echo .codex >> .git/info/exclude
fi
if [[ ! -f AGENTS.md ]]; then
  curl -L -o AGENTS.md "${url_base}/.codex/AGENTS.md"
  echo AGENTS.md >> .git/info/exclude
fi

bash .codex/env.sh
```
