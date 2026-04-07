---
name: linear-setup
description: Set up bidirectional Linear ↔ GitHub sync — issues, projects, webhooks, CI workflow
disable-model-invocation: true
triggers:
  - set up linear
  - linear sync
  - connect linear
  - linear integration
  - link linear
---

# Linear Integration Setup

Bidirectional sync between Linear issues and GitHub Issues. Changes in either direction propagate automatically.

## Quick Start

### 1. Link Linear Project
```bash
tenet linear link
# Interactive: prompts for Linear API key + team/project selection
# Stores config in .tenet/config.json → linear section
```

### 2. Bootstrap CI Workflow
```bash
tenet linear bootstrap
# Deploys: .github/workflows/linear-sync.yml
# Sets up: webhook URL on Linear → your platform endpoint
# Requires: LINEAR_API_KEY secret on the repo
```

### 3. Set Secrets
```bash
gh secret set LINEAR_API_KEY --repo OWNER/REPO
# Get your API key: Linear → Settings → API → Personal API keys
```

### 4. First Sync
```bash
tenet linear sync
# Options:
#   --direction github    # Linear → GitHub only
#   --direction linear    # GitHub → Linear only  
#   --direction both      # Bidirectional (default)
#   --dry-run             # Preview changes
#   --json                # Machine-readable output
```

## How Sync Works

### Linear → GitHub
- New Linear issue → creates GitHub Issue with `source:linear` label
- Linear issue state change → updates GitHub Issue labels
- Linear project created → creates `knowledge/linear-projects/<slug>/` with OVERVIEW.md, STATUS.md

### GitHub → Linear
- New GitHub Issue with `sync:linear` label → creates Linear issue
- GitHub Issue closed → updates Linear issue state
- PR merged referencing issue → marks Linear issue as done

### Label Mapping

| Linear State | GitHub Label |
|-------------|-------------|
| Backlog | `jfl/backlog` |
| Todo | `jfl/backlog` |
| In Progress | `jfl/in-progress` |
| In Review | `jfl/review` |
| Done | `jfl/done` |
| Cancelled | closed |

### Scope Labels
Issues get `scope:<project-slug>` labels automatically. This lets the kanban filter by Linear project.

## Webhook Setup

The platform receives Linear webhooks at:
```
https://jfl-platform.fly.dev/api/webhooks/linear
```

`tenet linear bootstrap` configures this automatically. If running locally:
```
http://localhost:3000/api/webhooks/linear
```

## Checking Status

```bash
tenet linear status
# Shows: linked project, last sync, mapped issues, webhook health
```

## Dashboard Integration

The tenet dashboard kanban board (`/dashboard` → Kanban page) shows Linear-synced issues alongside native GitHub Issues. A "Connect Linear" button on the dashboard triggers the link flow.

## Architecture

```
Linear (source of truth for PMs)
  ↕ webhook + API
Platform (jfl-platform.fly.dev/api/webhooks/linear)
  ↕ Octokit
GitHub Issues (source of truth for agents)
  ↕ kanban.yml workflow
Tenet Kanban (visible to agents + humans)
```

Michael and PMs work in Linear. Agents work from GitHub Issues. Sync keeps them in lock-step.
