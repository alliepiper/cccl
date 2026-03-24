# Documentation Update Tracker

Issues found in existing documentation that need fixing during Phase 4.

## ci-overview.md

**Action: Merge into CONTRIBUTING.md, then remove.**

Specific content to preserve:
- [ ] CI environment / devcontainer link (already in CONTRIBUTING.md)
- [ ] Matrix testing description → CONTRIBUTING.md CI section
- [ ] Viewing CI workflow results (with screenshot) → CONTRIBUTING.md
- [ ] Special CI commands (`[skip-*]` tags) → CONTRIBUTING.md
- [ ] Override matrix explanation + example → CONTRIBUTING.md
- [ ] sccache section → CONTRIBUTING.md (already partially there via devcontainer link)
- [ ] Build/test script references → already in CONTRIBUTING.md
- [ ] Reproducing CI failures locally (with screenshot) → CONTRIBUTING.md
- [ ] CI workflow details (copy-pr-bot, `/ok to test`, signed commits) → CONTRIBUTING.md
- [ ] Artifact scripts section → new `docs/maintainers/infrastructure/ci_scripts.rst`
- [ ] Workflow job lookup scripts section → new `docs/maintainers/infrastructure/ci_scripts.rst`
- [ ] Troubleshooting section → CONTRIBUTING.md

Issues in ci-overview.md:
- References `<HOST_COMPILER>` in build script example but current scripts use `-cxx` flag syntax
- The `copy-pr-bot` link may be outdated (check `docs.gha-runners.nvidia.com` URL)
- Screenshot references (`docs/images/pr-checks.png`, `docs/images/repro_instructions.png`) need to be moved or updated

## CONTRIBUTING.md

- [ ] "Developer Guides" section lists Thrust and libcudacxx as "Coming soon!" — still true or should link to something?
- [ ] CMake preset architecture default listed as `60;70;80` but CMakePresets.json uses `all-major-cccl` — verify which is correct
- [ ] Missing mention of `cudax`, `cccl_c_parallel`, `cccl_c_stf` in build/test script examples
- [ ] No link to `docs/maintainers/` infrastructure guides (to be added)
- [ ] No mention of `ci/util/build_and_test_targets.sh` (only full build scripts shown)

## .devcontainer/README.md

- [ ] Container variant list may not reflect current set (56+ variants now)
- [ ] No mention of `--cuda-ext` extended CTK images
- [ ] No mention of `make_devcontainers.sh` for generating new variants
- [ ] sccache section mentions "NVIDIA or rapidsai GitHub organizations" — verify still accurate

## AGENTS.md

- [ ] Add cross-links to new subdirectory AGENTS.md files
- [ ] Add cross-links to new `docs/maintainers/` guides
- [ ] Add cross-links to `.agents/skills/` for procedural tasks
- [ ] CI section references `~250 jobs` — verify current count from matrix.yaml

## docs/maintainers/

- [ ] `how_tos/index.rst` — only links backport_process, needs new how-tos added
- [ ] `references/index.rst` — only links branching_strategy, may need expansion
- [ ] `index.rst` — needs infrastructure/ section added to toctree

## docs/cccl/development/build_and_bisect_tools.rst

- [ ] Add cross-link to new CI scripts guide in docs/maintainers/
- [ ] Content is good and current — no fixes needed
