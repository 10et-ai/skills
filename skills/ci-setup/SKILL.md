---
name: ci-setup
description: Set up CI/CD workflows for a tenet project — trust ladder from AI review to auto-publish
disable-model-invocation: true
triggers:
  - set up ci
  - add ci
  - ci pipeline
  - trust ladder
  - add sentinel
  - add eval
  - deploy workflows
---

# CI Setup — Trust Ladder

Set up CI/CD automations incrementally. Each level adds more automation, requiring more trust in the agent system.

## Trust Ladder Levels

### Level 1: AI Code Review (read-only, comments on PRs)
```bash
tenet ci setup --sentinel
# Deploys: tenet-sentinel.yml
# Requires: ANTHROPIC_API_KEY, OPENAI_API_KEY secrets
# What it does: 3 models review every PR, post findings as comments
```

### Level 2: Eval Scoring (scores PRs, doesn't merge)
```bash
tenet ci setup --eval
# Deploys: tenet-eval.yml, eval-on-pr.yml
# Requires: eval scripts in eval/ directory
# What it does: runs eval suite on PR branches, posts score
```

### Level 3: Auto-merge on passing eval
```bash
# Requires: branch protection on main + eval-on-pr.yml
# Enable in repo settings:
gh api repos/OWNER/REPO -X PATCH -f allow_auto_merge=true
# Add branch protection rule requiring eval to pass
```

### Level 4: Auto-publish on merge
```bash
tenet ci enable release
# Deploys: release.yml
# Requires: NPM_TOKEN secret
# What it does: version bump + npm publish on merge to main
```

## Quick Setup (all at once)

```bash
tenet ci setup --all          # install all workflows
tenet ci status               # audit what's installed + missing
tenet ci configure             # interactive setup wizard
```

## Setting Secrets

```bash
# Required for Sentinel (Level 1):
gh secret set ANTHROPIC_API_KEY --repo OWNER/REPO
gh secret set OPENAI_API_KEY --repo OWNER/REPO
gh secret set OPENROUTER_API_KEY --repo OWNER/REPO    # optional, improves agreement scoring

# Required for Release (Level 4):
gh secret set NPM_TOKEN --repo OWNER/REPO

# Required for docs auto-update:
gh secret set DOCS_DISPATCH_TOKEN --repo OWNER/REPO
```

## Repo Settings (need admin)

```bash
# Enable auto-merge (Level 3):
gh api repos/OWNER/REPO -X PATCH -f allow_auto_merge=true

# Clean up agent branches after merge:
gh api repos/OWNER/REPO -X PATCH -f delete_branch_on_merge=true

# Branch protection (Level 3):
# GitHub → Settings → Branches → Add rule → main
# Require: status checks (CI, eval), PR reviews
```

## Checking Status

```bash
tenet ci status     # shows workflows, secrets, settings, score
tenet ci list       # list all automations and their state
```

## Kanban Automation

The `kanban.yml` workflow auto-manages issue labels when PRs reference issues:
- PR opened → issue moves to `jfl/in-progress`
- PR merged → issue moves to `jfl/done`

Deployed automatically with `tenet ci setup`.
