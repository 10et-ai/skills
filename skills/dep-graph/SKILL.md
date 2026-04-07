---
name: dep-graph
description: Build path-dependency execution plans from issues — graph deps + path deps + V×U/C scoring. Learns which orderings actually work.
disable-model-invocation: true
triggers:
  - dependency graph
  - execution order
  - what to build first
  - priority order
  - /dep-graph
---

# /dep-graph — Dependency-Aware Execution Planning

Builds an execution plan from open issues. Two types of dependencies:
- **Graph deps** (structural): A MUST come before B (code dependency)
- **Path deps** (strategic): shipping A first makes B more valuable (compound value)

## On Invoke

### Step 1: Read Issues
```bash
gh issue list --state open --json number,title,body,labels
```

### Step 2: For Each Issue, Determine
- **Files touched** (from body or inference)
- **Graph deps** (which issues MUST come first — code imports, API contracts)
- **Path deps** (which issues SHOULD come first — compound value)
- **V** (value 1-5): how much it moves the product
- **U** (unlocks): how many other issues become possible/easier
- **C** (cost): estimated agent rounds based on scope
- **Score**: V × U / C

### Step 3: Build Waves

Group into waves respecting graph deps (topological sort):
- **Wave A**: No unmet graph deps, highest scores
- **Wave B**: Depends on Wave A completions
- **Wave C**: Depends on Wave B completions

Within each wave:
- **Parallel**: Issues touching DIFFERENT files
- **Serial**: Issues touching SAME files (queued, not bundled)

**CRITICAL RULE: Max 2 issues per agent.** Even if issues touch the same files, they get separate agents that run serially. NEVER bundle >2 issues.

### Step 4: Output

Write execution plan as structured data for the dispatch skill to consume:

```json
{
  "waves": [
    {
      "name": "A",
      "agents": [
        { "issue": 2817, "files": [".github/workflows/"], "parallel_group": 1, "method_hint": "one-shot" },
        { "issue": 2820, "files": ["delegator/index.ts"], "parallel_group": 1, "method_hint": "eval-loop" },
        { "issue": 2782, "files": ["context-filter.ts"], "parallel_group": 1, "method_hint": "one-shot" }
      ]
    },
    {
      "name": "B",
      "depends_on": ["A"],
      "agents": [...]
    }
  ]
}
```

## Learnings

### From 5 waves of execution:

1. **Same-file bundling causes stalls.** FIRE 1 bundled 6 issues touching map-bridge.ts + index.ts into 1 agent. 39 turns, zero writes. Splitting into per-issue agents (serialized on same files) converges in 1-3 rounds each.

2. **Ship instrumentation first.** Dependency graph v5 proved: telemetry → RL pipeline → build pipeline → trust → people → demos. Each layer compounds on the one below. Without telemetry, the RL flywheel is blind.

3. **V×U/C scoring works.** Sentinel fix (#2817, score 35) correctly ranked highest — it unblocks all CI. Tool name fix (#2765, score 40) correctly ranked above search counting (#2766, score 20).

4. **Path deps matter more than graph deps.** Most issues don't have hard structural dependencies. The VALUE changes based on order. Scorecard before demos = demos have real metrics. Onboarding before team = team can actually use it.

5. **3 waves max per cycle.** More than 3 waves and the later waves are based on stale assumptions. Ship 3 waves, ceremony, re-plan.
