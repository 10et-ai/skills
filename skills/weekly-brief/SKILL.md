---
name: weekly-brief
description: Generate an exec-level weekly summary from a parent TENET workspace -- reads journals and git history from all registered services, applies exec-grain filter, outputs an email-ready HTML brief
triggers:
  - /weekly-brief
  - /weekly
  - weekly brief
  - weekly email
  - weekly summary
  - what did we ship this week
---

# /weekly-brief -- Weekly Brief

Generate a weekly summary for the workspace's configured audience. Reads journals and commit activity across all registered services. Outputs exec-grain HTML.

This skill is **config-driven** -- all paths, recipients, product names, and external contributors come from `.tenet/config.json`. No hardcoded paths. Works for any parent TENET workspace.

---

## Config Schema

The workspace must have a `weekly_brief` block in `.tenet/config.json`. The skill will not run without it. This is also where you set the exec-grain filter rules and external contributor list for your specific org.

```json
{
  "weekly_brief": {
    "sender": "Taggart",
    "product_name": "visa-crypto-labs",
    "audience": "executive",
    "output_dir": "content/emails/drafts",
    "recipients": ["cuy@visa.com", "rubail@visa.com"],
    "naming_map": {
      "402goose": "Taggart",
      "DatBoi": "Hath",
      "hathbanger": "Hath",
      "tanvibajaj": "Tanvi",
      "tylerCheung": "Tyler"
    },
    "external_contributors": [
      {
        "name": "Tanvi",
        "handle": "tanvibajaj",
        "products": ["Agent Card Tracker", "Pulse Dashboard", "MPP", "Visa Hosted Merchant Endpoints", "Talaria"],
        "note": "Tanvi's work is not in TENET journals -- ask for her manual input before finalizing"
      }
    ],
    "security_owner": "Nishant",
    "security_quote": "Cuy: \"We all work for you, Nishant.\"",
    "skip_commit_prefixes": ["auto:", "session:", "emergency:", "cleanup:", "chore:"],
    "days": 7
  }
}
```

`registered_services` is already required by TENET core -- the skill reads it to know which workspaces and repos to pull from. Each service entry should have `path` (local path to the workspace root) and optionally `repo` (GitHub slug for issues):

```json
{
  "registered_services": [
    {
      "name": "visa-cli-gtm",
      "path": "../visa-cli-gtm",
      "repo": "org/visa-cli",
      "type": "gtm"
    }
  ]
}
```

---

## Workflow

1. **Config check** -- Read `.tenet/config.json`. Verify `weekly_brief` block exists. If missing, output the config schema above and stop.

2. **External contributor check** -- If `external_contributors` are listed, ask the user: "Do you have [name]'s section for this week?" If yes, collect it. If no, stub each person's products as "in progress" and note it before sending.

3. **Collect from registered services** -- For each entry in `registered_services`:
   - Read `.tenet/journal/*.jsonl` from `<service.path>/.tenet/journal/` for entries in the last `weekly_brief.days` days
   - Filter for `type` in: `feature`, `milestone`, `fix`, `decision`, `pivot`
   - Run: `git log --oneline --since="Xd" <service.path>` and strip commits matching any `skip_commit_prefixes`
   - If `service.repo` is set: query `gh issue list --repo <repo> --state closed --since Xd` for closed issues this week

4. **Apply naming map** -- Replace all git handles and identifiers using `weekly_brief.naming_map` in the content.

5. **Apply exec-grain filter** -- See rules below. Apply to ALL sources including external contributor content.

6. **Synthesize** -- Group by product/service. Write one `<h2>` section per shipped product. Collapse minor fixes into a parent bullet unless the fix was user-visible.

7. **Write output files**:
   - HTML: `<output_dir>/NN-<product_name>-weekly-N.html` (increment NN from last file in output_dir)
   - MD: `docs/WEEKLY_BRIEF_YYYY-MM-DD.md` (same content, markdown format)

8. **Journal** -- Write a journal entry: `type: "feature"`, `title: "Weekly Brief YYYY-MM-DD"`.

---

## Exec-Grain Filter (apply to every source)

### Include
- Deployed products, live URLs, and first-time capabilities
- Concrete numbers: user counts, transaction volumes, costs, benchmark rates
- Named owners for blockers and in-progress work
- Security items (always in the Nishant table or equivalent security section)
- Decisions that close options for the team

### Strip
- Version strings and release numbers (unless v1.0 stable or equivalent milestone)
- Internal tool names and orchestrator names (e.g. agent framework internals)
- Line-of-code counts and file counts
- Infra plumbing: process management, cron scheduling, session cleanup, memory management
- Architecture decision details (result only, not mechanism)
- Budget numbers and cost estimates unless they prove economics (e.g. "under $1/week")
- Strategy and roadmap unless it was *locked* this week
- Internal bug IDs -- summarize the class of fix instead

**Test each sentence:** if a Visa exec reading this in 60 seconds would not know why it matters, rewrite or cut it.

---

## Output Format

Follow this HTML structure exactly:

```html
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>[Product Name] Weekly -- [Date Range]</title>
<style>
body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
       color: #1a1a1a; max-width: 680px; margin: 0 auto; padding: 20px;
       line-height: 1.6; font-size: 14px; }
h2   { font-size: 16px; margin-top: 28px; margin-bottom: 8px;
       border-bottom: 1px solid #e0e0e0; padding-bottom: 4px; font-weight: 600; }
hr   { border: none; border-top: 1px solid #e0e0e0; margin: 20px 0; }
p    { margin: 10px 0; }
ul   { margin: 8px 0; padding-left: 20px; }
li   { margin: 4px 0; }
table { border-collapse: collapse; width: 100%; margin: 12px 0; font-size: 13px; }
th, td { border: 1px solid #ddd; padding: 8px 10px; text-align: left; vertical-align: top; }
th   { background: #f5f5f5; font-weight: 600; }
code { background: #f4f4f4; padding: 2px 5px; border-radius: 3px;
       font-family: 'SF Mono', Menlo, monospace; font-size: 12px; }
</style>
</head>
<body>

<p>Team,</p>
<p>[1-2 sentence framing. Lead with the most important thing that shipped.]</p>

<hr>
<h2>Shipped This Week</h2>
[Per product: <p><strong>Product Name -- Subtitle.</strong> 1-2 sentence summary, number first if available.</p><ul>...</ul>]

<hr>
<h2>Week in Numbers</h2>
<p>[metric] -- [metric] -- [metric] -- [metric]</p>

<hr>
<h2>Security ([security_owner]) -- Top Priority</h2>
<p>[security_quote]</p>
<table>...</table>

<hr>
<h2>In Progress</h2>
<ul>...</ul>

<hr>
<h2>Blockers</h2>
<ul>...</ul>

<hr>
<h2>Next Week</h2>
<ul>...</ul>

<p>[sender]</p>
</body>
</html>
```

### Writing rules
1. **Lead with the number** -- metrics first, not buried
2. **One line per thing** -- each bullet is one update
3. **Context in the same breath** -- name it, say what it is, give the update
4. **No filler** -- no transitions, no "as discussed"
5. **Em-dash (`--`) not `--`** -- straight dashes, straight quotes, no emoji

---

## Keeping It Current

The skill lives in the TENET skills registry (`10et-ai/skills`). Run `tenet update` in any workspace to pull the latest version. Changes to the exec-grain filter, output format, or workflow are pushed to the registry and distributed automatically.

To tune the filter for your org, update `weekly_brief` in your `.tenet/config.json` -- the skill reads that on every run, so changes take effect immediately without a registry update.

---

## Examples

- `visa-crypto-labs`: `content/emails/drafts/07-lobster-beach-weekly-2.html`
