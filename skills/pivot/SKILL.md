---
name: pivot
description: Checkpoint current work to journals/memory — use when switching topics, NOT when context is full. Compaction handles context automatically.
disable-model-invocation: true
triggers:
  - /pivot
  - let's switch gears
  - new topic
  - pivot
  - change of plans
  - let's do something else
---

# /pivot - Topic Checkpoint

Save what you're working on (journal, git, memory) before switching to a different topic.

**IMPORTANT: Do NOT use pivot for context management.** When the context window fills, Pi compacts automatically. Just keep working. Never tell the user to "start a new session" — compaction handles it.

---

## When to Use

| Situation | Use /pivot? |
|-----------|------------|
| Switching from feature work to bug fixing | ✅ Yes |
| Context window getting full | ❌ No — compaction handles this automatically |
| Done with topic A, starting topic B | ✅ Yes |
| Done for the day | ❌ Use /end instead |
| Just finished one file, continuing same feature | ❌ No, keep going |

## What It Does

1. **Writes pivot journal entry** — captures what you were working on, files touched
2. **Commits all work** — `git add -A && git commit` on the SAME branch
3. **Indexes to memory** — makes the pivot entry searchable for future context
4. **Emits event** — `session:pivoted` so other systems know
5. **Tracks pivot count** — stored in `.tenet/session-state.json`

## What It Does NOT Do

- ❌ Merge to working branch (stays on session branch)
- ❌ Create a new branch
- ❌ Push to remote (unless `--push` flag)
- ❌ Stop auto-commit or Context Hub
- ❌ Run session-sync or doctor
- ❌ Trigger SessionStart hooks

## How to Invoke

**As a tool** (agent calls it):
```
tenet_pivot({ summary: "Finished agent service type integration" })
```

**As a command** (user types it):
```
/pivot Finished agent service type integration
```

**From CLI**:
```bash
tenet pivot --summary "Finished agent service type integration"
tenet pivot --summary "switching to bug fixes" --push
tenet pivot --json
```

## After Pivot

The agent should:
1. Show the pivot summary to the user
2. Ask "What do you want to work on next?"
3. Use the pivot journal entry as primary context (not full startup reload)
4. Continue on the same branch

## Journal Entry Format

Pivot entries use type `"pivot"`:

```json
{
  "v": 1,
  "ts": "2026-03-17T10:30:00.000Z",
  "session": "session-hath-20260317-1000-abc123",
  "type": "pivot",
  "status": "complete",
  "title": "Pivot #1: Finished agent service type integration",
  "summary": "Finished agent service type integration",
  "files": ["src/lib/service-detector.ts", "src/commands/services-create.ts"],
  "pivot_number": 1
}
```
