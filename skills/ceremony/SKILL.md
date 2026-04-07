---
name: ceremony
description: Post-cycle learning — compare predicted vs actual, update ALL skills in the pipe, record training tuples
disable-model-invocation: true
triggers:
  - ceremony
  - post-mortem
  - what did we learn
  - sharpen
  - /ceremony
---

# /ceremony — Post-Cycle Learning Loop

Runs after each wave completes. Compares predicted vs actual outcomes. Updates every skill in the pipe with new learnings. This is what makes the whole system compound.

> "Each cycle ships code (the work), updates skills (the improvement), stores learnings (the knowledge), adds eval checks (the standards)."

## On Invoke

### Input
Results from backward-arm (which branches shipped, which stalled, which were reverted).

### Step 1: What Shipped
List every converged agent with:
- Issue number and title
- Dispatch method used (one-shot vs eval-loop)
- Rounds to convergence
- Files changed
- Lines added/removed

### Step 2: What Stalled
For each stalled/killed agent:
- Why? (too ambitious, eval too hard, supervisor blind, stale timeout)
- Which checks failed?
- What dispatch method was used?
- Should the issue be re-scoped and re-fired?

### Step 3: Predicted vs Actual

| Issue | Predicted Method | Actual Method | Predicted Rounds | Actual Rounds | Match? |
|-------|-----------------|---------------|-----------------|---------------|--------|

Update dispatch skill learnings if predictions were wrong:
- "Predicted one-shot for #2817, took 3 rounds → spec wasn't specific enough for one-shot"
- "Predicted eval-loop for #2820, converged in 1 round → could have been one-shot"

### Step 4: Update Skills

For EACH skill in the pipe, check if learnings apply:

**eval-gate**: New failure patterns discovered? New check types needed?
**dep-graph**: Was the ordering right? Did shipping A actually unblock B?
**dispatch**: Did method predictions hold? Update decision tree data.
**backward-arm**: Any new regression patterns? Any false positives in drift detection?
**build-agent**: Any new convergence patterns? Stall causes?

Append learnings to each skill's `## Learnings` section.

### Step 5: Training Tuples

For each agent that ran:
```
tenet_training_buffer(
  action_type: "feature" | "fix",
  description: "what the agent did",
  outcome: "improved" | "neutral" | "regressed",
  scope: "small" | "medium" | "large",
  files: "file1.ts, file2.ts",
  delta: "0.05"  // eval score improvement
)
```

### Step 6: Journal Entry

Write a ceremony journal entry:
```
tenet_journal_write(
  type: "milestone",
  title: "Ceremony: Wave N — X/Y shipped, Z stalled",
  summary: "...",
  detail: "full ceremony output"
)
```

### Step 7: Plan Next Wave

If more issues remain in the graph:
1. Remove shipped issues from dependency graph
2. Check: did shipping change the graph? (new issues from red team, stalled issues need re-scope)
3. Re-score remaining issues (V×U/C may have changed)
4. Output updated execution plan for next cycle

### Output

Write `.tenet/ceremony-results.json`:
```json
{
  "wave": "A",
  "shipped": 3,
  "stalled": 1,
  "prediction_accuracy": 0.75,
  "skills_updated": ["dispatch", "eval-gate"],
  "new_learnings": 4,
  "training_tuples_recorded": 4,
  "next_wave_ready": true
}
```

## Learnings

### From 4 ceremonies:

1. **One-shot prediction accuracy: 80%.** When spec has exact file paths + signatures, one-shot works 4/5 times. The 1/5 failure is usually a missing dependency or import path that the spec didn't mention.

2. **Improve agent rounds: consistently 2-5.** Never seen an improve agent converge in 1 round. The first round always misses something. Budget 3 rounds minimum.

3. **Stall causes cluster.** 60% of stalls are blind supervisor (no stderr). 25% are impossible tasks (platform doesn't support it). 15% are too-ambitious (>3 issues bundled).

4. **Ceremony itself must be fast.** Don't spend 30 minutes analyzing. The ceremony output should be: what shipped, what stalled, what to update, done. 5-10 minutes max.

5. **Skill updates compound.** After ceremony adds a learning to eval-gate, the NEXT cycle's eval-gate catches things this cycle missed. The improvement is multiplicative, not additive.
