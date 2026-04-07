---
name: recipe
description: Create, run, and compose tenet recipes — self-contained YAML task definitions compatible with Goose format but with eval, maturity, and learning
disable-model-invocation: true
triggers:
  - create a recipe
  - run recipe
  - recipe for
  - build a recipe
  - make a reusable task
  - import goose recipe
---

# Tenet Recipes — Self-Contained Runnable Tasks

Recipes are the product layer over tenet's plumbing. A recipe is a single YAML file that contains everything needed to run a task: parameters, tools, eval criteria, and a prompt. Share one file and anyone can run it.

## Core Commands

```bash
tenet recipe list                          # see available recipes
tenet recipe list --goose                  # see Goose community recipes too
tenet recipe show <file.yaml>              # inspect a recipe
tenet recipe run <file.yaml>               # run it (outputs prompt)
tenet recipe run <file.yaml> --dry-run     # preview without running
tenet recipe run <file.yaml> --param k=v  # pass parameters
tenet recipe run <file.yaml> --eval        # run + check eval criteria
tenet recipe init "My Task"               # create new recipe from template
tenet recipe import analyze-pr --source goose  # import from Goose
```

## Recipe Format

```yaml
version: 1.0.0
title: "My Task"
description: "What this recipe does"
disable-model-invocation: true
author: your-name
maturity: stable  # stable | beta | experimental

parameters:
  - key: target
    type: string
    required: true
    description: "What to operate on"
  - key: mode
    type: string
    required: false
    default: standard

# Tenet tools this recipe needs
tools:
  - tenet_context
  - tenet_journal_write

# Eval criteria — what makes this pass
eval:
  - check: "target exists"
    command: "test -e {{ target }}"
    expect_exit: 0

# Main prompt — use {{ param_key }} for substitution
prompt: |
  Do something with {{ target }} in {{ mode }} mode.
  
  Steps:
  1. First step
  2. Second step
  3. Journal the result: tenet_journal_write(...)
```

## Starter Recipes (in .tenet/recipes/)

| Recipe | When to use |
|--------|-------------|
| `daily-release-check.yaml` | Before each release — CI, P1s, changelog |
| `analyze-pr.yaml` | Deep PR review with memory context |
| `security-audit.yaml` | Nishant's red team, vulnerability scan |
| `onboard-new-user.yaml` | Walk Michael/Dom/Hath through setup |
| `content-pipeline.yaml` | Tyler's AEO content machine |

## vs Goose Recipes

Tenet recipes are **compatible with Goose format** plus:
- `maturity` field (stable/beta/experimental)
- `trust_level` (what CI ladder level is needed)
- `eval` section (quantitative pass/fail — Goose has none)
- `tools` (tenet tools like tenet_context, tenet_journal_write)
- **Learning** — eval results feed into training buffer, recipes improve

Import any Goose recipe: `tenet recipe import <name> --source goose`
The imported recipe works immediately AND gets eval + learning capabilities.

## Creating Good Recipes

1. **One clear goal** — recipes should do one thing well
2. **Specific prompts** — no vague instructions, clear numbered steps
3. **Eval criteria** — add at least one check so you know if it worked
4. **Journal step** — always end with tenet_journal_write
5. **Start experimental** — promote to beta/stable as you use it
6. **Subrecipes** — break complex tasks into smaller pieces in `subrecipes/` dir

## Subrecipes (parallel agents)

For complex tasks, break into subrecipes that run in parallel:

```yaml
# In your main recipe prompt:
"Run these checks in parallel:
- Check CI: `tenet recipe run .tenet/recipes/subrecipes/check-ci.yaml --param repo={{ repo }}`
- Check Issues: `tenet recipe run .tenet/recipes/subrecipes/check-issues.yaml --param repo={{ repo }}`
Compile all results before reporting."
```

## Recipe Registry

Recipes live in:
- `.tenet/recipes/` — project-specific
- `~/.config/tenet/recipes/` — global (works in any project)
- `.tenet/recipes/community/` — imported from Goose or other sources
