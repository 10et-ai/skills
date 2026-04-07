---
name: dispatch
description: Classify issues into dispatch methods, fire agents, enforce limits. Learns which methods work for which task types.
disable-model-invocation: true
triggers:
  - fire agents
  - dispatch
  - launch agents
  - run the build
  - /dispatch
---

# /dispatch — Smart Agent Dispatch

Classifies each issue into the right dispatch method, then fires. Enforces hard limits from failure data.

## Hard Limits

| Limit | Value | Source |
|-------|-------|--------|
| Max issues per agent | 2 | FIRE 1: 6 issues → 39 turns → stall |
| Max concurrent workers | 4 | Resource constraint |
| Stale timeout | 15 min wall clock | #2820: turn-based detection broken |
| Max turns per agent | 30 | FIRE 1: 39 turns was waste |
| Branch required | always | Wave 0: committed to main accidentally |
| Spec freeze required | always | Agents read stale specs without freeze |

## Dispatch Decision Tree

```
Is this a NEW file build (all files created from scratch)?
  YES → Is the spec specific (file paths, function names, types)?
    YES → pi one-shot (~2 min, 1 round)
         Evidence: recipe-bundle 14/14 R1, linear-dashboard 17/17 R1
    NO  → PP eval loop (3-5 rounds)
         Evidence: scout-agent 31 checks R2
  NO → Is this modifying existing code?
    YES → PP eval loop (2-5 rounds, needs regression guards)
         Evidence: pp-cross-model 14 checks R3, qa-agent 19 checks R5
    NO → Is this research/analysis?
      YES → delegate with output path (1 round)
           Evidence: PI-UX-PATTERNS 495 lines R1
      NO → delegate as freeform task
```

## On Invoke

### Input
Reads execution plan from dep-graph skill (or takes issue list directly).

### Step 1: Classify Each Issue
For each issue, determine:
- **Type**: new-build | improve | research | ci-config
- **Method**: one-shot | eval-loop | delegate-only
- **Files**: which files will be touched
- **Repo**: which repo (jfl-cli, jfl-gtm, jfl-platform)
- **Estimated rounds**: 1 | 2-3 | 3-5

### Step 2: Build the Delegate Calls

For each issue, construct the task description:
```
Fix <title> (#<number>).

Target: <repo path>
Files: <file list>
Spec: <spec path or inline from issue body>

What to do:
<concrete implementation steps from issue body>

Eval: <eval path>
Run eval with: AGENT_WORKTREE=$(pwd) npx tsx <eval path>
Commit with: Closes #<number>
```

### Step 3: Fire Per Wave

Wave A (no deps) — fire all parallel agents:
```
delegate(task: "...", from_issue: N)  # parallel group 1
delegate(task: "...", from_issue: M)  # parallel group 1 (different files)
delegate(task: "...", from_issue: K)  # parallel group 1 (different files)
```

Wait for Wave A completion, then fire Wave B, etc.

### Step 4: Monitor

Check `delegator_status` periodically.
- Converged → mark for backward-arm
- Stalled 15+ min without file change → kill
- Over 30 turns → kill, record as too-ambitious

### Output

Write `.tenet/dispatch-results.json`:
```json
{
  "dispatched": [
    { "issue": 2817, "method": "one-shot", "worker_id": "abc", "status": "running" }
  ],
  "killed": [],
  "converged": []
}
```

## Learnings

### From 50+ dispatches:

1. **Pi one-shot is 100% for clear specs.** When spec has exact file paths + function signatures + types, one-shot hits 100% in 1 round. Don't waste eval loop overhead.

2. **Improve agents NEED the eval loop.** Modifying existing code is ambiguous — agent needs feedback on what worked and what didn't. Loop converges in 2-5 rounds.

3. **Kill at 15 min wall clock, not turn count.** Turn-based stale detection in delegator/index.ts has a parsing bug (#2820). Wall clock is reliable.

4. **Research tasks don't need evals.** Delegate with output path: "Write to knowledge/REPORT.md". Score by report quality after, not during.

5. **Same-file agents: serial, not bundled.** If #2766 and #2767 both touch map-bridge.ts, fire #2766 first. When it finishes, fire #2767. Agent #2767 sees #2766's changes and builds on them. Better than one agent trying to do both.

6. **Workers don't reliably self-commit.** Build-pipe run #1: only 1/4 workers committed. The other 3 wrote correct code but exited without committing. The backward-arm must be ready to commit orphaned changes from the working tree. Always check `git diff --stat` after worker exits.

7. **File contention kills workers silently.** #2819 and #2782 both touched index.ts. #2819 exited with zero output — its changes were overwritten by #2782. Never dispatch two workers that touch the SAME file in parallel, even if they're in different buckets. The analyzer failed to detect the overlap because it timed out.

8. **"Already done" is the best outcome.** 6/10 issues were already fixed by a prior commit. Running per-issue eval baselines FIRST saved 6 agent dispatches. Always baseline before firing.

9. **Workers commit to their own branches, not main.** Build-pipe run #2: when worker finishes and commits, the repo is on the worker's branch (`issue/N-slug`). If you commit from main without switching, you end up on the worker branch. Always `git checkout main` before committing backward-arm changes. Cherry-pick from worker branch to main if needed.

10. **8 parallel workers is sustainable.** Run #2 fired 8 workers across 2 waves of 4. All converged or near-converged. No file contention because the dispatch plan carefully checked file overlap. Max concurrent = 4 is the sweet spot.

11. **Self-committing workers are a good signal.** Only 2/8 workers self-committed cleanly (#2822 epistemic, #2820 previous run). The ones that self-commit tend to have cleaner, more focused changes. The ones that don't are often over-ambitious and leave mess for backward-arm.
