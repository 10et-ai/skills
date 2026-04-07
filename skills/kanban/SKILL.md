---
name: kanban
description: Manage the project kanban board — view, pick, create, move, complete tasks via GitHub Issues
disable-model-invocation: true
triggers:
  - kanban
  - backlog
  - what should I work on
  - pick a task
  - show the board
  - create a task
---

# Kanban — Task Board Management

The tenet kanban is backed by GitHub Issues. Every issue is a card. Columns are labels.

## View the Board

```bash
tenet kanban                    # full board view
tenet kanban --scope visa-cli   # filter by service scope
```

Or via the API:
```bash
curl http://localhost:$HUB_PORT/api/kanban
```

## Pick Up Work

When you're ready to work on something:

```bash
tenet kanban pick <issue-number>
# Moves card to "in_progress", assigns you
```

**For overnight agents:** Pick from `tenet/backlog` label + `agent-ready` label:
```bash
gh issue list --label "tenet/backlog,agent-ready" --json number,title --jq '.[0]'
```

## Create Tasks

```bash
tenet kanban create --title "Fix auth persistence" --scope visa-cli --priority 1
```

Or directly via GitHub:
```bash
gh issue create --title "..." --label "tenet/backlog,P1,area:auth"
```

### Label Convention

| Label | Meaning |
|-------|---------|
| `tenet/backlog` | Ready to be picked up |
| `tenet/in-progress` | Someone is working on it |
| `tenet/review` | PR created, needs review |
| `tenet/done` | Merged and shipped |
| `P1` / `P2` / `P3` | Priority (1 = critical) |
| `agent-ready` | Has enough context for autonomous agent work |
| `needs-context` | Requires human input before agent can work |
| `area:onboarding` | Onboarding / first-run experience |
| `area:auth` | Authentication / authorization |
| `area:infra` | Infrastructure / CI / deployment |
| `area:dx` | Developer experience |
| `area:agents` | Agent system / orchestration |

## Move Cards

```bash
tenet kanban move <issue-number> in_progress
tenet kanban move <issue-number> review
tenet kanban move <issue-number> done
```

## Complete Work

When done with a task:

1. Create PR referencing the issue: `fixes #<number>` in PR body
2. PR merges → GitHub auto-closes the issue
3. Card moves to `done`

Or manually:
```bash
gh issue close <number> --comment "Fixed in <commit>"
```

## Workflow for Overnight Agents

```
1. Agent starts → reads kanban for agent-ready P1 issues
2. Picks highest priority unassigned issue
3. Creates a branch: session/fix-<issue>-<hash>
4. Works on the fix, runs evals
5. Creates PR with "fixes #<number>" in body
6. Sentinel reviews → eval scores → human merges (or auto-merge if trust ladder allows)
```

## Workflow for Humans

```
1. Check board: tenet kanban
2. Pick task: tenet kanban pick 42
3. Work on it in your session
4. Journal what you did: tenet_journal_write
5. Push PR → card auto-moves to review
6. Merge → card auto-moves to done
```

## Tips

- **Always check the board before starting work** — avoid duplicate effort
- **Label issues as `agent-ready`** when they have clear acceptance criteria
- **Use `needs-context`** for issues that need human decision-making first
- **Scope labels** (`area:*`) help agents and humans filter to their domain
- **The Jill feedback agent** creates issues from user feedback automatically

## Stale Issue Detection

Issues go stale when the codebase moves on. **Every session should check for staleness:**

### When to flag an issue as stale
- The files it references have been deleted or heavily refactored
- A different solution was shipped that makes the issue moot
- The requirement changed (conversation shifted direction)
- The issue has been open >14 days with no activity and no `agent-ready` label

### What to do
```bash
# Flag for review
gh issue edit <number> --add-label "stale"
gh issue comment <number> --body "Flagging as stale — [reason]. Close if no longer relevant."

# Or close directly if clearly superseded
gh issue close <number> --comment "Superseded by [commit/PR/issue]. The approach changed to [what happened instead]."
```

### When NOT to flag
- Issue is `needs-context` or `epistemic-boundary` — these are intentionally waiting
- Issue is a meta-tracker (#30) — stays open by design
- Issue was recently commented on (<7 days)

### Automated check (for overnight agents)
```bash
# Find issues with no activity in 14+ days
gh issue list --state open --json number,title,updatedAt --jq '.[] | select(.updatedAt < (now - 14*86400 | todate))'
```
