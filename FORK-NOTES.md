# Fork notes — anthropic-skills-trimmed

EdV-owned trimmed fork of [anthropics/skills](https://github.com/anthropics/skills).

## Why this fork exists

Installing upstream directly triggers [issue #189](https://github.com/anthropics/skills/issues/189) + [#206](https://github.com/anthropics/skills/issues/206): the Claude Code plugin loader copies the entire repo (all 17 skills) into the plugin cache regardless of which plugin is selected or what the `skills` array in `marketplace.json` filters. Running `/plugin install document-skills@anthropic-agent-skills` still pulls algorithmic-art, brand-guidelines, canvas-design, doc-coauthoring, frontend-design, internal-comms, mcp-builder, skill-creator, slack-gif-creator, theme-factory, web-artifacts-builder, and webapp-testing along with it — ~50k wasted tokens per session.

Physically removing the unwanted skill directories is the supported workaround (per the thread on #189). This repo is that workaround packaged for EdV-wide reuse.

## Kept

- `skills/docx`
- `skills/pdf`
- `skills/pptx`
- `skills/xlsx`
- `skills/claude-api`

## Pruned (12)

algorithmic-art, brand-guidelines, canvas-design, doc-coauthoring, frontend-design, internal-comms, mcp-builder, skill-creator, slack-gif-creator, theme-factory, web-artifacts-builder, webapp-testing.

## Install (teammates)

```bash
gh repo clone edv-io/anthropic-skills-trimmed ~/Projects/EdV/anthropic-skills-trimmed
# In Claude Code:
/plugin marketplace add ~/Projects/EdV/anthropic-skills-trimmed
/plugin install trimmed-skills@anthropic-skills-trimmed
```

Verify on next session start: `docx`, `pdf`, `pptx`, `xlsx`, `claude-api` appear in available skills; nothing else from upstream does.

## Upstream sync

**Automated.** `scripts/sync-upstream.sh` runs weekly on mac-mini via launchd (`io.edv.anthropic-skills-trimmed-sync`, Monday 06:00 local). It:

1. Resets local `main` to `origin/main`.
2. Fetches `upstream/main` and merges. Our deleted skill dirs stay deleted — `git merge` doesn't resurrect them.
3. Pushes the merge commit to `origin/main`.
4. Sends an ntfy notification on conflict, push failure, or on success.

**Do not merge upstream by hand on sagan** — the launchd job owns the sync. If you need to pull upstream changes manually (e.g., mac-mini offline), do it on mac-mini, not locally.

### Push auth on mac-mini

The edv-io org has deploy keys disabled org-wide, so the sync script uses a scoped fine-grained PAT instead. The token lives at `~/.config/anthropic-skills-trimmed-sync/token` (mode 600) on mac-mini. The script reads it and uses a one-shot `x-access-token:<token>@github.com/...` push URL — the token is never written to git config or the shell history. If the file is absent (e.g., when running the script on sagan during a manual sync test), the script falls back to `git push origin main` using whatever credentials the machine's git has.

The token is GitHub-side scoped to this repo only, Contents: write only, no expiration. Named `mac-mini-anthropic-skills-trimmed-sync` on the PAT list. To rotate: generate a new PAT with the same scope, overwrite the token file on mac-mini, revoke the old PAT.

## Upstream watch

Track these issues — if and when they resolve, revisit whether this fork is still needed:

- https://github.com/anthropics/skills/issues/189
- https://github.com/anthropics/skills/pull/551

## Downstream unblocks

This fork is the prerequisite for these EdV docx-migration tds:

- `td-ebd647` proposal
- `td-2dd47c` review-aesthetics
- `td-c60ff5` review-for-client
- `td-7f4a5a` generate-doc
