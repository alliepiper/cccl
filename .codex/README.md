Add this to your Codex environment script:

```bash
# Optional: override the installed CTK. Use 'latest' to use newest available (default).
# export CTK_DEFAULT_VERSION=12.9

mkdir .codex || :
readonly url_base="https://raw.githubusercontent.com/alliepiper/cccl/codex_util"
curl -L -o .codex/env.sh "${url_base}/.codex/env.sh"
curl -L -o AGENTS.md "${url_base}/.codex/AGENTS.md"

echo AGENTS.md >> .git/info/exclude
echo .codex >> .git/info/exclude

bash .codex/env.sh
```
