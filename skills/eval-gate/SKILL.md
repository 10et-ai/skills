---
name: eval-gate
description: Validate evals before agents fire — enforce quality gates, catch anti-patterns, learn which patterns cause stalls
disable-model-invocation: true
triggers:
  - validate evals
  - check evals
  - eval quality
  - pre-flight
  - /eval-gate
---

# /eval-gate — Pre-Flight Eval Validation

Validates evals against proven patterns. Blocks agents that would stall. Learns from outcomes.

> "13/13 converged agents had decomposed checks + stderr. 3/7 stalled were missing stderr."

## On Invoke

Scan every eval in `eval/build/*.ts`. For each, check:

### CRITICAL (agent BLOCKED if missing)

1. **AGENT_WORKTREE** — eval reads the agent's branch, not main
   ```typescript
   const ROOT = process.env.AGENT_WORKTREE || process.cwd()
   ```
   _Without this, eval scores main → good code gets reverted._

2. **stderr output** — supervisor needs failing check names
   ```typescript
   console.error(`[eval] ${passed}/${total}: ${failed.length ? 'failed: ' + failed.join(', ') : 'all passing'}`)
   ```
   _Without this, supervisor says "STALLED" but can't say WHICH check._

3. **JSON failed_checks** — structured output for supervisor parsing
   ```typescript
   process.stdout.write(JSON.stringify({ failed_checks: failed, score }) + '\n')
   ```

4. **Minimum 8 binary checks** — decomposed, not monolithic
   _1 compile check = zero gradient. Agent stuck at 0% or 100%._

5. **Regression guards** (for improve agents modifying existing files):
   ```typescript
   { name: "no-destructive-rewrite", pass: file.split('\n').length > BASELINE * 0.5 },
   { name: "existing-exports-preserved", pass: EXPORTS.every(e => file.includes(e)) },
   ```
   _Wave 0: agent scored 1.0 while deleting 600 lines. Regression guard catches this._

### WARNING (fix before firing, don't block)

6. TypeScript compile check included
7. `@purpose` header check included
8. Eval hierarchy L1→L6 (existence before behavior)

### Auto-Fix

For each CRITICAL violation, fix it:
- Missing AGENT_WORKTREE → add the pattern
- Missing stderr → add console.error line
- Missing JSON output → add process.stdout.write line
- Missing regression guards → read current file, count lines/exports, add checks
- Too few checks → read spec, add behavioral checks per spec line

### Output

Write `.tenet/eval-quality-report.json`:
```json
{
  "timestamp": "ISO",
  "evals_scanned": 9,
  "critical_violations": 2,
  "auto_fixed": 2,
  "blocked_agents": [],
  "dispatch_hint": { "sentinel-fix": "one-shot", "zombie-detection": "eval-loop" }
}
```

This output pipes to the next skill in the build pipe.

## Learnings

### From 50+ agent runs:

1. **Stub eval = guaranteed stall.** 1 compile check gives zero gradient. Min 8 checks.
2. **Missing stderr = blind supervisor.** Supervisor parses `failed: X, Y` from stderr. No stderr = "STALLED" with no actionable hint.
3. **No regression guard = destructive rewrite.** Wave 0 agents deleted 600 lines of index.ts and scored 1.0 because eval only checked new code presence, not old code preservation.
4. **AGENT_WORKTREE missing = eval scores main.** Agent writes good code to worktree, eval reads main, score is 0, good code gets reverted. The #1 cause of 0% keep rate.
5. **Mega-eval covering 6 issues = stall.** FIRE 1 had 20 checks across 6 issues in one eval. Agent couldn't tell which issue to work on first. One eval per issue.

6. **Per-issue baselines reveal "already done" issues.** Build-pipe run #1: 6/10 issues scored 1.0 at baseline — they were already fixed by a prior commit (114b633). The mega-eval hid this because it tested all 6 together. Per-issue baselines saved 6 unnecessary agent dispatches.

7. **Check the RIGHT file.** Eval for #2766 (search counting) checked map-bridge.ts but the fix was in index.ts. The eval was wrong, not the code. Always verify which file the fix actually landed in before writing eval checks.
