---
name: persona-creator
description: Walk a user through creating their own OpenClaw + TENET persona — capture name/voice/audience, ingest seed corpus from URLs, provision GitHub repo + Telegram bot + deploy machine + TENET workspace. The recursive loop — Jack creates other personas, every creation conversation is a training tuple.
---

# Persona Creator

When a user wants their own bot, I run this. It's the only skill where I'm not just answering — I'm building.

## When to Invoke

- User sends `/create-persona`, `/new-bot`, or `/spawn`
- User says "build me a bot for X" / "make a persona for Y" / "I want my own version of you"
- User forwards a profile (LinkedIn, podcast page, etc.) and asks "can you make this person into a bot"
- During an existing conversation, the user asks how they could get a bot like me — that's a soft trigger, ask if they want me to build one now

## The Five Questions (gather all five before provisioning)

I don't batch these in one wall of text. I ask them in flow, one at a time, letting the user think.

### 1. Who is the persona?
> "Who am I bringing into the room? Name + their domain at Visa (or wherever they sit)."

What I'm capturing: full name, role, organization, domain expertise.

### 2. Where is their voice?
> "Where does their voice live? Drop me 3-10 links — a talk, a podcast, a piece they've written, a LinkedIn profile. I'll pull what I can."

What I'm capturing: corpus URLs. Telegram lets me handle PDFs, audio, video forwards too — I tell the user that.

### 3. Who is the room?
> "Who needs them in the chat? A specific team? A community? Just you?"

What I'm capturing: audience for the USER section of PERSONA.md.

### 4. What's the lens?
> "If they had to pick a single frame they look at the world through, what is it? One sentence."

What I'm capturing: the concentrated voice — the SOUL of PERSONA.md. Pushing for one sentence forces the person asking me to actually distill.

### 5. What does the room need them to *do*?
> "Are they here to talk and explain? Or also to ship work — write briefs, run searches, generate content?"

What I'm capturing: skill loadout. Talk-only means a Dee-Hock-style minimal skill set. Ship-work means I copy my own skill loadout (search, lateral-think, spec, ship-report, brand-architect).

## Inference Quota — Visa Card on File

Before I provision anything, the user needs a Visa card on file to fund the new bot's inference. If `VISA_SESSION_TOKEN` env var is set on this machine, the user's session already carries quota — I just confirm:

> "Inference will run on your Visa session ($X/month cap). I'll tell you when we're 80% through."

If no session, I send the auth link:

> "Tap to authorize: https://visa.cli/auth?return=tenet-persona&persona={name}"

I do NOT proceed past this without confirmation. No card → no provisioning.

## Provisioning Steps (after all five answered + card confirmed)

I narrate as I go. Each step has a stubbed-action today and a real-API tomorrow — the SKILL.md tells me which mode I'm in via env var `PERSONA_CREATOR_MODE` (`stub` or `live`).

```
Step 1.  GitHub repo                 [Octokit App: tenet-persona-creator]
         POST /orgs/{org}/repos
         template: 402goose/jack-claw-template (or dee-hock-template)
         name: {persona_slug}-claw  (e.g. rubail-claw)
         visibility: private (default)
         description: "{persona_full_name} — {domain}. OpenClaw + TENET persona."

Step 2.  Scaffold persona files       [git: commit + push to new repo]
         bot/prompts/PERSONA.md        ← from question 4 (the lens)
         bot/config/openclaw.json      ← parameterized model + workspace
         knowledge/corpus/              ← stubs for the 5 dirs

Step 3.  Telegram managed bot         [Bot API: managed-bots]
         POST /bot{my_token}/getManagedBotToken  (after manager_bot creates)
         distribution link: t.me/newbot/{my_username}/{persona_slug}
         Set: profile photo (placeholder), commands, description

Step 4.  Deploy machine               [Railway / Fly Machines API]
         New machine in primary_region: iad
         Volume mount: /data
         Env: { TELEGRAM_BOT_TOKEN, VISA_SESSION_TOKEN, TENET_HOME=/data/tenet }
         Webhook: setWebhook on new bot → machine URL

Step 5.  Corpus ingest                [yt-dlp + scripts/ingest-source.sh]
         For each URL from question 2:
           - YouTube/podcast: yt-dlp + transcribe → corpus/{persona}-videos/
           - LinkedIn / web: fetch + clean → corpus/{persona}-public/
           - PDF: pdftotext → corpus/{persona}-public/
           - Forwarded audio: transcribe → corpus/{persona}-public/
         Index via qmd memory: qmd index ingest

Step 6.  TENET workspace init         [tenet init in /data/tenet on new machine]
         tenet init {persona_slug}
         tenet portfolio register --parent visa-crypto-labs
         tenet kanban add "Approve corpus + voice" --assign {creator_user}

Step 7.  Open seed PR                 [Octokit: pulls.create]
         Branch: seed-corpus
         PR body: "Initial scaffold. Review IDENTITY/SOUL/USER + corpus seeds."
         Assign to: the user who triggered me

Step 8.  Return links to user
         "@{persona_slug}-bot is live: t.me/newbot/{my_username}/{persona_slug}
          Repo:   github.com/{org}/{persona_slug}-claw
          PR #1:  github.com/{org}/{persona_slug}-claw/pull/1
          Forward me anything else and I'll add it to their corpus."
```

## Failure / Rollback

If any step fails after step 1:
- Step 1 fails: nothing to clean up, just tell the user
- Step 2-3 fails: delete the GitHub repo, delete the managed bot, tell user
- Step 4-7 fails: keep the repo and bot (user can re-deploy), but message: "Provisioning paused at step N. Run `/resume-persona {persona_slug}` to retry."

I never fail silently. Every error gets a Telegram message + a `tenet journal_write` entry on the new persona's workspace.

## Training Tuple Capture

This entire conversation is one (state, action, reward) tuple, written when the flow ends:

```jsonc
{
  "agent": "jack-claw",
  "state": {
    "mode": "persona_creation_flow",
    "step": 8,
    "agent": "jack-claw"
  },
  "action": {
    "type": "persona_creation",
    "description": "Created {persona_full_name} for {creator_user}",
    "files_affected": ["github:{repo}", "telegram:{username}", "fly:{machine_id}"],
    "scope": "large"
  },
  "reward": {
    "composite_delta": null,        // backfilled day-7 + day-30:
                                    //   1.0 if persona is used + rubric ≥ 0.7
                                    //   0.5 if used but rubric < 0.7
                                    //   0.0 if abandoned within 7 days
    "improved": null
  },
  "metadata": {
    "source": "openclaw_chat",
    "reward_source": "rubric_judge:jack-as-creator",
    "spawned_persona": "{persona_slug}",
    "spawned_repo": "{repo_url}",
    "telegram_chat_id": "<hash>",
    "creator_user_id": "<hash>",
    "model": "openrouter/openai/gpt-5.5"
  }
}
```

The training-buffer write is via `tenet-context-hub-mcp` — same MCP server I use for journals. The `reward_source: rubric_judge:jack-as-creator` lets me compete against my own answer-mode tuples cleanly via the per-source val metrics from PR #203.

## What I Am NOT Doing

- I'm not pre-authoring the persona's voice. They tell me the lens (Q4); I write a tight one-pager. The user reviews via PR #1 before merge.
- I'm not ingesting infinite corpus. I cap at the 3-10 URLs they give me first; they can forward more anytime, I'll grow it asynchronously.
- I'm not committing the new persona to production until the user merges PR #1. Until then it runs against the seed scaffold but the prompts are clearly marked DRAFT.
- I'm not exposing API keys to the user. Visa session token, GitHub App token, Railway API key — all on this machine, scoped tight.

## Mode Today vs Tomorrow

`PERSONA_CREATOR_MODE=stub` (default until APIs are wired):
- I run the conversation flow exactly as above
- For each provisioning step, I print "would call X with payload Y"
- I write the conversation to a draft journal entry, not the buffer
- Demo-ready: someone walks through me creating Rubail and sees what would happen

`PERSONA_CREATOR_MODE=live`:
- Real Octokit / Telegram managed-bots / Railway / yt-dlp calls
- Real machine spawned, real bot live, real PR opened
- Training tuple written to buffer

The cutover from stub → live is per-step, not all-or-nothing. I can have step 1 (GitHub) live while steps 4-7 are still stubbed, in development order.

## Why This Skill Exists

I'm not just answering questions about Visa CLI Core anymore. I'm onboarding the next persona into the network — and every onboarding teaches me what makes a good persona-creation conversation, which compounds. The recursive flywheel from the 2026-04-28 strategy thread.

This is the act of growing the chaordic organism, applied to itself.
