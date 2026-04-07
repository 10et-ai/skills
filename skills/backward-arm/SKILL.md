---
name: backward-arm
description: Validate converged branches before PR — catch regressions, revert destructive changes, surgically re-apply correct fixes
disable-model-invocation: true
triggers:
  - validate branch
  - check branch
  - backward arm
  - pre-PR check
  - /backward-arm
---

# /backward-arm — Post-Convergence Branch Validation

Validates branches AFTER agents converge but BEFORE PRs are created. Catches destructive rewrites, regressions, and scope drift.

> "Wave 0: Workers scored 1.0 while deleting 600 lines. Backward arm caught it, reverted, re-applied correct fixes."

## On Invoke

### Input
List of converged branches from dispatch (or specify a branch directly).

### Step 1: Run Final Eval
For each branch:
```bash
AGENT_WORKTREE=<branch_path> npx tsx eval/build/<name>.ts
```
Confirm score is still 1.0 (or the converged score).

### Step 2: Regression Check
```bash
git diff main...<branch> --stat
```
For each modified file:
1. **Line count delta**: Is the file dramatically shorter? (>30% shrinkage = destructive)
2. **Export preservation**: Are all existing exports still present?
3. **Function preservation**: Are key functions still there?
4. **Import preservation**: Were dependencies removed that shouldn't be?

If destructive rewrite detected:
```
1. Save the agent's correct ADDITIONS (new code that passes eval checks)
2. Revert the branch to main state: git checkout main -- <file>
3. Surgically re-apply ONLY the correct additions
4. Re-run eval to confirm still passing
```

This is the Wave 0 pattern — it worked every time.

### Step 3: Scope Drift Check
Compare files the agent actually touched vs files declared in the TOML/task.
- **In-scope changes**: expected, keep
- **Out-of-scope changes**: unexpected, review carefully
  - If harmless (formatting, import reorder): keep
  - If substantive (logic changes to unrelated files): revert
  - Record drift in `.tenet/delegator-hints.json` for future dispatches

### Step 4: Memory Search
For any failing check or suspicious pattern:
```
tenet_memory_search("<failing check name>")
tenet_memory_search("<error pattern>")
```
If a prior fix exists in memory, compare approaches.

### Step 5: Output

Write `.tenet/backward-arm-results.json`:
```json
{
  "branches": [
    {
      "issue": 2817,
      "branch": "issue/2817-sentinel-fix",
      "eval_score": 1.0,
      "regression": "clean",
      "scope_drift": "none",
      "pr_ready": true
    }
  ],
  "reverted": [],
  "blocked": []
}
```

Only `pr_ready: true` branches become PRs.

## Learnings

### From 4 backward arm runs:

1. **Surgical re-apply works.** Wave 0 backward arm successfully: (a) identified 3 files with destructive rewrites, (b) reverted to main, (c) re-applied only the correct ~50 lines, (d) all evals still passed. The pattern is proven.

2. **Eval score alone is insufficient.** Agent can score 1.0 by deleting everything and writing minimal code that passes checks. Regression guards catch this, but backward arm is the safety net.

3. **Scope drift is a signal, not always a bug.** Agent touching files outside scope sometimes means the task naturally required it (e.g., updating an import). Record it for hints learning, don't auto-revert.

4. **Memory search saves time.** If backward arm finds a pattern that failed before, the memory hit tells you WHY and HOW it was fixed. Don't re-diagnose.

5. **Revert-and-reapply is faster than fixing in place.** When an agent made destructive changes, trying to "fix the fix" takes longer than starting from main and applying only the good parts.

6. **Workers leave orphaned changes.** Build-pipe run #1: 2/4 workers wrote correct code but exited without committing. Backward-arm must check `git diff --stat` after every worker exit and commit valid changes. Always compile-check before committing orphaned code.

7. **Compile-check is the gate.** If orphaned changes pass `npx tsc --noEmit`, they're safe to commit. If they fail, the worker hit a conflict or incomplete state — investigate before committing.

8. **WARNING: tsc can lie if directories are excluded.** Build-pipe run #2 discovered #2829 — `packages/pi/tsconfig.json` excludes `extensions/delegator/` from compilation. A worker shipped a broken import (markIssueInProgress that didn't exist) and tsc passed clean. ALWAYS check tsconfig excludes before trusting a compile result. Run `grep -A3 exclude tsconfig.json` as part of validation.

9. **Workers leave partial work in stashes.** Build-pipe run #2: switching branches during backward-arm caused multiple stashes to accumulate (stash@{0} through stash@{8}). When a worker finishes, their changes may be stashed not committed. Check `git stash list` for worker WIP before giving up. Use `git checkout stash@{N} -- <file>` to selectively restore work.

10. **File-level cherry-pick is powerful.** Instead of `git stash pop` (which can conflict), use `git checkout stash@{N} -- path/to/file.ts` to grab just the files you want. Safer, no merge conflicts, no partial state.
