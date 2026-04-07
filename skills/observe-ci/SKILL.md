---
name: observe-ci
description: Run the CI observer fleet — watch all runs, events, and agent activity, surface insights, file issues, inject startup hints
triggers:
  - observe ci
  - watch ci
  - ci health check
  - what's failing in ci
  - ci observer
  - check all runs
  - find ci insights
---

# CI Observer — `/observe-ci`

Runs a fleet of 4 parallel observers across CI runs, event stream, kanban drift, and eval scores. A synthesizer merges findings and acts: files issues, opens mechanical PRs, injects hints into the startup briefing.

## When to Use

- "What's been failing in CI?"
- "Are we generating training signal from PRs?"
- "Have any workers been bypassing the PR pipeline?"
- "Run the CI observer"
- "Observe CI and tell me what's wrong"

## On Skill Invoke

Run the recipe:

```bash
tenet recipe run recipes/observe-ci.yaml
```

Or with options:
```bash
tenet recipe run recipes/observe-ci.yaml --param lookback_hours=48
tenet recipe run recipes/observe-ci.yaml --param dry_run=true   # preview only
```

## What It Watches

| Observer | Data Source | Finds |
|----------|-------------|-------|
| `watch-ci-runs` | GitHub Actions run logs | Recurring failures, flaky tests, slowdowns |
| `watch-events` | `.tenet/service-events.jsonl`, `training-buffer.jsonl` | Signal gaps, blank sentinel outputs, tuple count |
| `watch-kanban` | `.tenet/kanban.jsonl`, GitHub issues | Workflow bypasses (issues closed without PRs) |
| `watch-evals` | `.tenet/eval-history.jsonl`, eval workflows | Score regressions, stale gates |

## What It Does With Findings

1. **Files GitHub issues** for actionable problems above threshold
2. **Opens PRs** for mechanical fixes (<20 lines) — pin broken SHA, add continue-on-error, fix a test mock
3. **Injects hints** into `.tenet/observe-ci-hints.jsonl` → surfaced in Pi startup briefing next session

## Output

```
Pipeline health: 40% (2/5 issues closed via PR)
Training signal: 3 tuples (last 24h), avg quality 0.72
CI: 1 recurring failure (doctor.test.ts), 0 flaky
Actions taken: 2 issues filed, 0 PRs, 1 hint injected

Top findings:
  [P1] doctor.test.ts failing in CI — mock env missing API keys (#93)
  [P1] 3 issues closed directly to main — 0 tuples generated (#94)
  [warn] pr-sentinel@main not pinned to SHA — unstable (#95)
```

## Schedule

Add to `.github/workflows/observe-ci.yml` to run daily:
```yaml
on:
  schedule:
    - cron: '0 9 * * *'  # 9am UTC daily
  workflow_dispatch:       # also runnable manually
```
