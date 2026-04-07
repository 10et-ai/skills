---
name: spawn-salon
description: Deploy and manage AI agent fleets on Fly.io via Spawn Salon — multi-agent control planes with SOUL.md personalities
disable-model-invocation: true
---

# Spawn Salon — Agent Fleet Management

Deploy multi-agent fleets that run 24/7 on Fly.io. Each agent gets its own workspace, personality (SOUL.md), heartbeat, and communication channels. Based on the proven Switch architecture running 6 agents in production for the Subway protocol.

## When to Use

- "Deploy a fleet of agents to monitor my services"
- "Set up a multi-agent control plane"
- "Create agents that work together autonomously"
- "I need agents running 24/7 with different roles"

## Architecture

A fleet = openclaw.json config + SOUL.md per agent + Fly.io machine

```
my-fleet/
  openclaw.json          ← agent config, models, tools, channels
  workspace/
    agent-1/SOUL.md      ← personality, mission, decision principles
    agent-2/SOUL.md
    agent-3/SOUL.md
```

Each agent gets:
- Its own workspace directory on the Fly machine
- A SOUL.md that defines its personality and operating loop
- A heartbeat interval (how often it checks in)
- Communication via Telegram topics, Subway P2P, or agent-to-agent messaging

## On Skill Invoke

### Step 1: Design the Fleet

Decide what agents you need. Good fleets have:
- **An operator/coordinator** (default agent, routes work to others)
- **Specialists** (each owns a domain: engineering, growth, support, monitoring)
- **A monitor** (watches for problems, alerts the coordinator)

Example fleet structures:
- **Product ops:** Coordinator + Builder + Reviewer + Monitor
- **Content pipeline:** Editor + Writer + Researcher + Publisher
- **Service ops:** Switch + Incidents + Forge + Ledger (the Switch pattern)
- **DX testing:** First Run + Team Join + Skill Smith + Speed Check + DX Audit

### Step 2: Write openclaw.json

```json
{
  "agents": {
    "defaults": {
      "model": {
        "primary": "anthropic/claude-sonnet-4-5",
        "fallbacks": ["anthropic/claude-3.5-haiku"]
      },
      "workspace": "/data/workspace",
      "compaction": {
        "mode": "safeguard",
        "maxHistoryShare": 0.4,
        "recentTurnsPreserve": 4,
        "qualityGuard": { "enabled": true }
      }
    },
    "list": [
      {
        "id": "coordinator",
        "default": true,
        "workspace": "/data/workspace/coordinator",
        "heartbeat": { "every": "30m" },
        "identity": { "name": "Coordinator", "emoji": "⚡" },
        "groupChat": { "mentionPatterns": ["@coordinator"] }
      },
      {
        "id": "builder",
        "workspace": "/data/workspace/builder",
        "heartbeat": { "every": "1h" },
        "identity": { "name": "Builder", "emoji": "🔨" }
      }
    ]
  },
  "channels": {
    "telegram": { "enabled": true },
    "subway": { "enabled": true }
  },
  "tools": {
    "agentToAgent": { "enabled": true, "allow": ["*"] },
    "exec": { "security": "full" }
  }
}
```

### Step 3: Write SOUL.md for Each Agent

Follow the proven Switch pattern — 7 sections:

```markdown
# SOUL

## Core Mission
One sentence — why this agent exists.

## Why This Role Exists
What breaks without it. Why can't another agent do this?

## What Must Be Protected
Non-negotiable invariants. Things this agent must never compromise.

## Decision Principles
Ranked priority stack. When two priorities conflict, which wins?

## Failure Modes To Avoid
What NOT to do — as important as what to do.

## Escalation Philosophy
When to ask for help. What severity levels exist. Who has authority.

## Relationship To Humans
Who is the final authority? When does this agent need human approval?
```

### Step 4: Deploy via Spawn Salon

```bash
# Option A: Spawn Salon dashboard
# Upload openclaw.json → provision new fleet → Fly machine created

# Option B: Spawn Salon API
curl -X POST https://your-spawn-salon.fly.dev/api/v1/fleet/create \
  -H "Authorization: Bearer $SALON_API_KEY" \
  -d '{"appName": "my-fleet", "region": "sjc"}'

# Option C: Local Docker (development)
# Spawn Salon auto-detects local Docker and provisions locally
```

### Step 5: Write SOUL.md Files via Control Plane

After the machine is up, write each agent's SOUL.md:

```bash
# Via Spawn Salon control plane API
curl -X PUT "https://my-fleet.fly.dev/__spawn/agents/coordinator/workspace/SOUL.md" \
  -H "Content-Type: text/markdown" \
  -d @workspace/coordinator/SOUL.md
```

### Step 6: Verify and Monitor

- Check heartbeats in Telegram/Subway
- Monitor agent-to-agent communication
- Review workspace files for state

## Key Config Options

| Field | What it does |
|-------|-------------|
| `heartbeat.every` | How often agent checks in (5m for monitoring, 24h for reporting) |
| `compaction.mode` | "safeguard" preserves context quality during compaction |
| `agentToAgent` | Lets agents message each other directly |
| `groupChat.mentionPatterns` | How to address this agent in group chat |
| `identity.emoji` | Visual identifier in messages |
| `elevatedDefault` | "full" gives agent exec access |

## Production Examples

**Switch (Subway control plane):** 6 agents managing the Subway P2P protocol
- Switch (coordinator, 30m) — executive decisions, agent routing
- Incidents (monitor, 5m) — anomaly detection, severity classification
- Forge (engineering, 1h) — CI health, dependency updates, releases
- Beacon (support, 30m) — user feedback, issue taxonomy
- Ledger (finance, 24h) — cost tracking, burn rate, anomaly detection
- Signal (growth, 30m) — docs, tutorials, adoption narratives

**Jill (Visa CLI feedback agent):** 1 agent on Telegram
- Collects user feedback from Telegram + MCP tool
- Classifies: bug / feature request / praise / noise
- Clusters similar items, proposes features at threshold

## Anti-Patterns

- Don't give every agent the same heartbeat — tune to the role
- Don't skip SOUL.md — agents without personality drift and produce generic output
- Don't skip "Failure Modes To Avoid" — it's the most important section
- Don't make agents that overlap — clear ownership prevents conflict
- Don't forget escalation — every agent needs to know when to ask for help
