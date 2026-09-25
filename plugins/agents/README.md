# agents

A five-agent complexity ladder for Claude Code and Codex — generic, no project-specific content.
Source of truth: `agents/*.md` (Claude Code) and `codex/*.toml` (Codex, hand-written, same roles
and contract, worded for that host).

## The ladder

| Agent | Use when | Claude pin | Codex pin |
|---|---|---|---|
| Operator | Change is fully decided to the exact detail | ![haiku](https://img.shields.io/badge/haiku-2ea44f) | ![gpt-6-luna / low](https://img.shields.io/badge/gpt--6--luna-low-2ea44f) |
| Researcher | Read-only investigation of any source | ![sonnet / medium](https://img.shields.io/badge/sonnet-medium-1f6feb) | ![gpt-6-sol / medium](https://img.shields.io/badge/gpt--6--sol-medium-1f6feb) ![read-only](https://img.shields.io/badge/read--only-6e7681) |
| Builder | Scoped implementation, small judgment calls, no new pattern | ![sonnet / medium](https://img.shields.io/badge/sonnet-medium-1f6feb) | ![gpt-6-sol / medium](https://img.shields.io/badge/gpt--6--sol-medium-1f6feb) |
| Specialist | Cross-cutting, no existing pattern, real correctness risk | ![opus / high](https://img.shields.io/badge/opus-high-8250df) | ![gpt-6-astra / high](https://img.shields.io/badge/gpt--6--astra-high-8250df) |
| Reviewer | Validate a plan/diff/text/decision before committing to it | ![opus / high](https://img.shields.io/badge/opus-high-8250df) | ![gpt-6-astra / medium](https://img.shields.io/badge/gpt--6--astra-medium-8250df) ![read-only](https://img.shields.io/badge/read--only-6e7681) |

Badge color = tier (green light, blue mid, purple top); left = model alias, right = reasoning effort.

Escalation: Operator → Builder → Specialist → caller; only the caller starts Builder or
Specialist. Full rules — handoff format, consultation cap, user-decision boundary, tool-denial
handling — are in each agent file's Contract section, identical across the ladder.

## Install

**Claude Code**

```
/plugin marketplace add k8adev/aiwkf
/plugin install agents@aiwkf
```

Install at **user** scope (pick it in `/plugin`): the Delegation block below is global, so a
project or local install leaves other repos without the agents and delegation falls back to
`general-purpose`. Restart open sessions after installing or updating.

**Codex**

```
codex plugin marketplace add k8adev/aiwkf
codex plugin add agents@aiwkf
mkdir -p "${CODEX_HOME:-$HOME/.codex}/agents"
ln -s "${CODEX_HOME:-$HOME/.codex}"/.tmp/marketplaces/aiwkf/plugins/agents/codex/*.toml "${CODEX_HOME:-$HOME/.codex}/agents/"
```

`codex plugin add` delivers the `orchestrate` skill (`skills/orchestrate/SKILL.md`) but not the
agents themselves — that skill loading is a separate mechanism from the symlinks above, and
confirming the skill works does not confirm the agents do. Codex reads agent profiles only from
`~/.codex/agents/` or a project's `.codex/agents/`, never from a plugin directory, so the symlink
step is still required. `ln -s` fails if a same-named file already exists there — check or rename
it first, never `-f` blindly. To remove:
`find "${CODEX_HOME:-$HOME/.codex}/agents" -type l -lname '*marketplaces/aiwkf/plugins/agents/codex/*' -delete`.
For development, point the symlinks at your own checkout instead.

## Recommended

The `orchestrate` skill triggers from its description, but not every time. To make the main
session route work through the ladder, add this to your global instructions
(`~/.claude/CLAUDE.md` on Claude Code, `~/.codex/AGENTS.md` on Codex):

```
## Delegation

The session orchestrates: it decides, sequences and talks to me; subagents do the work.
Before any search, change, research, review or external write (MCP/API) that needs an agent, invoke the `orchestrate` skill first
(`agents:orchestrate` on Claude Code).
```

## Limits

- Read-only (Researcher, Reviewer) is enforced by contract, not fully by tooling — Bash/MCP
  writes aren't blocked by the tool list on Claude, nor by Codex's read-only sandbox.
- Nested delegation on Codex (`spawn_agent` reaching another profile) is undocumented — verify
  before relying on it.
- Codex's `.tmp/marketplaces/` path is internal and undocumented; it may change and break the
  symlinks (visible, not harmful — re-point them).
- It is not yet verified that Codex follows symlinked agent files — confirm in a new session.
- The Claude Code `opus` alias's current resolved model is not documented.
- Claude Haiku 4.5 has no `effort` parameter, so Operator's Claude frontmatter omits it.

## Tests

```
bash plugins/agents/scripts/test.sh
```
