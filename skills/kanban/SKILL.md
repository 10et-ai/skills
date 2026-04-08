---
name: kanban
description: TENET kanban workflow — pick issues, work them, ship PRs using tenet_kanban tool
disable-model-invocation: true
triggers:
  - pick up an issue
  - start working on
  - claim a ticket
  - what should I work on
  - file an issue
  - add to backlog
  - create a PR
  - submit work
  - kanban
  - backlog
---

# Kanban Skill — TENET Work Loop

Use `tenet_kanban` tool for ALL kanban operations. Never use `gh issue` directly or shell scripts.

## The Loop

```
tenet_kanban(ls)           → see the board
tenet_kanban(pick)         → claim top priority issue → sets current issue
tenet_kanban(add, "...")   → file a new issue with labels
tenet_kanban(move, "N done") → move issue to done
```

## Service Routing — Issues go to the RIGHT repo

The kanban tool reads `registered_services` from `.tenet/config.json` to know which repo an issue belongs to. When filing or picking up issues:

- Issues about **tenet-cli / Pi extensions / npm package** → target `tenet-cli` service → `10et-ai/cli`
- Issues about **platform / cloud / API** → target `tenet-platform` service → `10et-ai/platform`
- Issues about **this workspace** → current repo (default)

Specify the service when filing:
```
tenet_kanban(add, "fix zombie spawns in peter-parker --service tenet-cli --priority P0")
tenet_kanban(add, "add stripe webhook --service tenet-platform --priority P1")
```

## Labels

| Label | Meaning |
|-------|---------|
| `tenet/backlog` | Not started |
| `tenet/in-progress` | Being worked on |
| `tenet/review` | PR open, awaiting review |
| `tenet/done` | Merged |
| `P0` | Critical — blocks users NOW |
| `P1` | High — ship this sprint |
| `P2` | Medium — next sprint |
| `P3` | Low — someday |
| `agent-ready` | Build agent can pick this up |
| `epistemic-boundary` | Blocked — need human input |
| `needs-context` | Missing info to proceed |
| `area:extensions` | Pi extension code |
| `area:platform` | Platform/API code |

## Filing Issues — When and How

File an issue when:
- You discover a bug while working → file immediately, don't lose it
- User describes something they want → translate to a filed issue
- A fix reveals a follow-up problem → file it before moving on

Do NOT file an issue for:
- Work you're doing right now inline (just do it + journal)
- Tiny 1-line fixes that take less time to file than to do

## Epistemic Honesty

When blocked or uncertain:
```
tenet_kanban(add, "clarify X before building Y --label epistemic-boundary")
```

When missing context:
```
tenet_kanban(add, "need decision on Z --label needs-context")
```

Do NOT fake certainty. Do NOT guess at requirements. Surface the unknown.

## When to Use Kanban Ceremony vs Just Do It

| Situation | Action |
|-----------|--------|
| User says "fix this now" | Fix it → journal it. No ceremony. |
| Autonomous multi-step work | Full loop: pick → branch → work → PR |
| Discovery during work | File issue → keep working on current |
| Build agent target | File issue with `agent-ready` → dispatch |
| Blocked on a decision | File with `epistemic-boundary` → surface it |

## After Picking an Issue

1. Journal it: `tenet_journal_write(type=feature, title="Starting #N: ...")`
2. Work it using the right service path
3. Commit with `Closes #N` in message
4. Journal completion: `tenet_journal_write(type=feature, title="Completed #N")`
5. `tenet_kanban(move, "N done")`

## Build Agent Dispatch

For issues tagged `agent-ready`, use the build-cycle recipe:
```
tenet_skill_load("build-agent")
```

The build-agent skill handles: spec → eval → TOML → dispatch → PR. Issues become specs, specs become evals, evals drive convergence.
