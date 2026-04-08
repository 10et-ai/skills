---
name: kanban
description: Manage the project kanban board — view, pick, create, move, complete tasks
disable-model-invocation: true
triggers:
  - kanban
  - backlog
  - what should I work on
  - pick a task
  - show the board
  - create a task
  - file an issue
  - add to backlog
---

# Kanban Skill

Board is backed by GitHub Issues. Use the `tenet_kanban` Pi tool — not gh CLI, not bash.

## The Loop

```
tenet_kanban ls          → see what's open
tenet_kanban add         → file an issue  
tenet_kanban pick        → claim top issue → tenet_journal_write (type=decision)
[work]                   → tenet_journal_write (type=feature/fix/discovery) as you go
tenet_kanban done        → close issue → tenet_journal_write (type=milestone)
```

## View Board

```
tenet_kanban({ command: "ls" })
tenet_kanban({ command: "ls", args: "--scope tenet-cli" })   // filter by service
```

## Add an Issue

Search memory first — don't duplicate:
```
tenet_memory_search("topic of issue")
tenet_kanban({ command: "add", args: '"Title" --priority 80 --scope tenet-cli --source agent' })
```

`--scope` = service name (`tenet-cli`, `tenet-platform`, `tenet-template`, etc.)  
`--source` = `human` | `agent` | `setup` | `findings`  
`--priority` = 0–100 (higher = first picked up)

## Pick Work

```
tenet_kanban({ command: "pick" })   // picks highest priority backlog item
```

Then immediately:
```
tenet_journal_write({ type: "decision", title: "Picked up #N: <title>", summary: "..." })
```

## Move Cards

```
tenet_kanban({ command: "move", args: "123 in_progress" })
tenet_kanban({ command: "move", args: "123 review" })
tenet_kanban({ command: "move", args: "123 done" })
```

## Complete Work

```
tenet_kanban({ command: "done", args: "123" })
tenet_journal_write({ type: "milestone", title: "Closed #123", summary: "..." })
```

## Labels

| Label | Meaning |
|-------|---------|
| `tenet/backlog` | Ready to pick up |
| `tenet/in-progress` | Active |
| `tenet/review` | PR open |
| `tenet/done` | Shipped |
| `P0`–`P3` | Priority (0 = fire) |
| `agent-ready` | Has acceptance criteria, safe for autonomous work |
| `needs-context` | Blocked on human decision |
| `epistemic-boundary` | Unknown unknowns — needs research first |
| `area:agents` / `area:dx` / `area:infra` / `area:auth` | Domain |

## Bootstrap Labels (first run on a new repo)

```
tenet_kanban({ command: "bootstrap" })
```

## Workflow: Autonomous Multi-Step Work

1. `tenet_kanban({ command: "ls" })` — see the board
2. `tenet_memory_search("area")` — find prior art
3. `tenet_kanban({ command: "pick" })` — claim top issue
4. `tenet_skill_load("build-agent")` — if it needs a build agent
5. Work → `tenet_journal_write` after each significant action
6. PR with `Closes #N` in body
7. `tenet_kanban({ command: "done", args: "N" })`

## When to Use Ceremony vs Just Do It

- **User says "fix this"** → just fix it, journal it, done. No kanban overhead.
- **Multi-step autonomous work** → full kanban flow above.
- **Unknown scope / blockers** → add `epistemic-boundary` label, ask user.
- **Need human decision** → add `needs-context` label, stop.
