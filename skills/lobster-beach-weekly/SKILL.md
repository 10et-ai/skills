---
name: lobster-beach-weekly
description: Generate the Lobster Beach Weekly team digest for visa-crypto-labs -- extends the weekly-brief skill with org-specific config
disable-model-invocation: true
triggers:
  - /lobster-beach-weekly
  - lobster beach weekly
  - weekly email
  - weekly digest
---

# /lobster-beach-weekly -- Lobster Beach Weekly

This skill is the visa-crypto-labs configuration layer on top of `weekly-brief`. It delegates to that skill -- the workflow, exec-grain filter, and output format live there. What's here is org-specific: recipients, naming map, external contributors.

**Run the generic version first if you haven't:** `weekly-brief` in the skills registry.

---

## What makes this org-specific

1. **Tanvi's products** are not in TENET journals -- they're in her own repos. The skill asks for her manual input before finalizing.
2. **Naming map** maps git handles to real names for this team.
3. **Security section** is always present and always led by Nishant.
4. **Recipients**: Cuy Sheffield, Rubail Birwadker, Jack Forestell, Tyler Cheung, Tanvi, Nishant, Michael, Dom, Hath.

---

## Required `.tenet/config.json` block

Add this to the parent workspace's `.tenet/config.json`. Once set, `/lobster-beach-weekly` and `/weekly-brief` both read from it -- no other changes needed.

```json
{
  "weekly_brief": {
    "sender": "Taggart",
    "product_name": "lobster-beach",
    "audience": "executive",
    "output_dir": "content/emails/drafts",
    "naming_map": {
      "402goose": "Taggart",
      "goose": "Taggart",
      "chipagosfinest": "Alec",
      "DatBoi": "Hath",
      "hathbanger": "Hath",
      "tanvibajaj": "Tanvi",
      "tylerCheung": "Tyler"
    },
    "external_contributors": [
      {
        "name": "Tanvi",
        "handle": "tanvibajaj",
        "products": [
          "Agent Card Tracker",
          "Pulse Dashboard",
          "MPP",
          "Visa Hosted Merchant Endpoints",
          "Talaria"
        ],
        "note": "Tanvi's work is not in TENET journals -- ask for her input before finalizing. Apply exec-grain filter to her raw content."
      }
    ],
    "security_owner": "Nishant",
    "security_quote": "Cuy: \"We all work for you, Nishant.\"",
    "skip_commit_prefixes": ["auto:", "session:", "emergency:", "cleanup:", "chore:"],
    "days": 7
  }
}
```

---

## Workflow

Follows `weekly-brief` exactly, plus one pre-step:

**0. Tanvi check** -- Before reading any journals, ask: "Do you have Tanvi's section for this week?" Her five products (listed above) are not in any TENET workspace -- they need to come in manually. If not available, stub each one as "in progress" and flag before send.

Then follow the standard `weekly-brief` workflow: config check, collect from registered_services, naming map, exec-grain filter, synthesize, write files, journal.

---

## Exec-Grain Additions (org-specific)

On top of the standard filter rules in `weekly-brief`, apply:

- **Micropayment economics**: when Talaria or MPP are mentioned, lead with the dollar number if available ("under $1/week", "4 cents/call") -- that's the proof point Rubail needs
- **GEO benchmark**: always state the Visa citation rate vs. Stripe rate when GEO ships anything -- that gap is the whole story
- **Agent Card Tracker**: always include total product count and update frequency (e.g. "22 products, daily auto-update") -- shows competitive coverage breadth

---

## Output Files

```
content/emails/drafts/NN-lobster-beach-weekly-N.html
docs/WEEKLY_BRIEF_YYYY-MM-DD.md
```

Increment `NN` from the last file in `content/emails/drafts/`.

---

## Reference

- Generic skill: `weekly-brief` in `10et-ai/skills`
- Prior email (Week 2, improved): `content/emails/drafts/07-lobster-beach-weekly-2.html`
