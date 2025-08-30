Add this to your Codex environment script:

```bash
mkdir .codex
readonly url_base="https://raw.githubusercontent.com/alliepiper/cccl/codex_util"
curl -L -o .codex/env.sh "${url_base}/.codex/env.sh"
curl -L -o AGENTS.md "${url_base}/.codex/AGENTS.md"

echo AGENTS.md >> .git/info/exclude
echo .codex >> .git/info/exclude

bash .codex/env.sh
```
