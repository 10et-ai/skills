---
name: regression-run
description: Run the regression fleet — parallel agents validate Pi startup, delegator lifecycle, sentinel, eval gate, and E2E build-pipe. Green = actually shippable.
triggers:
  - run regression
  - regression check
  - regression suite
  - validate build pipe
  - check for regressions
  - is it safe to ship
  - pre-ship check
---

# Regression Run — `/regression-run`

5 parallel agents each own one critical coverage area. A gate agent computes a weighted score and blocks the merge if anything critical breaks. Zero known flaky tests — green means shippable.

## When to Use

- Before shipping a release: "run regression check"
- After a major change: "is it safe to ship?"
- In CI on every PR (auto-triggered)
- "validate the build pipe"

## On Skill Invoke

```bash
tenet recipe run recipes/regression-run.yaml
```

With options:
```bash
tenet recipe run recipes/regression-run.yaml --param baseline_score=0.80
tenet recipe run recipes/regression-run.yaml --param branch=my-feature-branch
```

## Coverage Areas

| Agent | Weight | What It Checks |
|-------|--------|----------------|
| `pi-smoke` | 25% | Pi starts and responds in <12s, no extension hang |
| `delegator-lifecycle` | 25% | Closed-issue guard, garbage path filter, no turn theft, idle widget |
| `doctor-check` | 15% | No crash, no `require is not defined`, Node 25 compat |
| `sentinel-check` | 20% | Sentinel outputs populated, training tuples written (warn if not pinned) |
| `e2e-pipe` | 15% | All 7 pipeline stages present and wired |

## Scoring

```
score = Σ(agent_weight × agent_pass)
```
Default gate: score ≥ 0.75 = PASS. Configurable via `baseline_score` param.

## Output

```
┌──────────────────────┬────────┬────────┐
│ Agent                │ Score  │ Status │
├──────────────────────┼────────┼────────┤
│ pi-smoke             │ 1.00   │ ✓ pass │
│ delegator-lifecycle  │ 1.00   │ ✓ pass │
│ doctor-check         │ 1.00   │ ✓ pass │
│ sentinel-check       │ 0.50   │ ⚠ warn │
│ e2e-pipe             │ 0.71   │ ✓ pass │
├──────────────────────┼────────┼────────┤
│ Weighted score       │ 0.875  │ ✓ PASS │
└──────────────────────┴────────┴────────┘

All regression checks passed (score=0.875)
```

## CI Integration

```yaml
# .github/workflows/regression-run.yml
on:
  pull_request:
    branches: [main]
jobs:
  regression:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: npm install -g @10et/cli
      - run: tenet recipe run recipes/regression-run.yaml --param branch=${{ github.head_ref }}
```

## Results

Written to `.tenet/regression-results.json` after each run. Gate exits 1 if score below baseline — blocks merge.
