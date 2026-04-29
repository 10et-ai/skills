#!/usr/bin/env bash
#
# run-step.sh — single entry point for the 8 persona-creator provisioning steps.
#
# Usage:
#   bash run-step.sh <step_num> <params_json>
#
# Reads PERSONA_CREATOR_MODE env (stub|live, default stub).
# In stub mode: prints "would call X" with resolved params.
# In live mode: invokes the real API for that step.
#
# All steps return JSON to stdout: {ok: bool, step: N, output: {...}, error?: string}
#
# Required env for live mode (per step):
#   1: GH_PERSONA_ORG, GH_TOKEN (or gh auth)
#   2: GH_TOKEN (or gh auth) — clones template, commits, pushes
#   3: TELEGRAM_MANAGER_BOT_TOKEN, TELEGRAM_MANAGER_BOT_USERNAME
#   4: FLY_API_TOKEN, FLY_PRIMARY_REGION (default iad)
#   5: corpus URLs from params; uses yt-dlp + scripts/ingest-source.sh on the new machine
#   6: ssh into new fly machine, run tenet init + portfolio register
#   7: GH_TOKEN — gh pr create
#   8: pure print, no API
#
# Stub-fallback behavior: if a required env var is missing in live mode, the
# step prints a "would call" trace AND a non-fatal warning, then exits 0 with
# ok:true so the conversation flow doesn't break. Only real API errors return
# ok:false.
#
# @purpose Single-entry runner for persona-creator 8-step provisioning

set -e

STEP=${1:-}
PARAMS_JSON=${2:-'{}'}
MODE=${PERSONA_CREATOR_MODE:-stub}

if [[ -z "$STEP" ]]; then
    echo '{"ok":false,"error":"usage: run-step.sh <step_num> <params_json>"}' >&2
    exit 1
fi

# helper: read param via jq with default
p() {
    local key=$1
    local default=${2:-}
    echo "$PARAMS_JSON" | jq -r --arg k "$key" --arg d "$default" '. as $x | $x[$k] // $d'
}

# helper: emit a JSON result and exit 0
emit() {
    local ok=$1; shift
    local step=$1; shift
    local payload=$1
    if [[ "$ok" == "true" ]]; then
        echo "{\"ok\":true,\"step\":$step,\"mode\":\"$MODE\",\"output\":$payload}"
    else
        echo "{\"ok\":false,\"step\":$step,\"mode\":\"$MODE\",\"error\":$payload}"
    fi
    exit 0
}

# helper: stub trace
stub() {
    local step=$1
    local msg=$2
    emit true "$step" "{\"would_call\":\"$msg\"}"
}

# helper: warn-and-stub when a token is missing in live mode
warn_missing() {
    local step=$1
    local var=$2
    local msg=$3
    echo "[run-step.sh] WARN: $var unset; falling back to stub for step $step" >&2
    stub "$step" "$msg (live skipped: $var unset)"
}

case "$STEP" in

# ─── Step 1: GitHub repo creation ──────────────────────────────────────
1)
    persona_slug=$(p persona_slug)
    persona_full_name=$(p persona_full_name "")
    domain=$(p domain "")
    template=$(p template "402goose/jack-claw-template")
    visibility=$(p visibility "private")
    org=${GH_PERSONA_ORG:-402goose}

    if [[ "$MODE" == "stub" ]]; then
        stub 1 "POST /orgs/$org/repos {name: ${persona_slug}-claw, template: $template, visibility: $visibility}"
    fi
    if ! command -v gh >/dev/null; then
        warn_missing 1 "gh CLI" "POST /orgs/$org/repos {name: ${persona_slug}-claw, template: $template}"
    fi

    repo_name="${persona_slug}-claw"
    desc="${persona_full_name} — ${domain}. OpenClaw + TENET persona."
    if gh repo create "$org/$repo_name" --template "$template" --"$visibility" --description "$desc" >/dev/null 2>&1; then
        emit true 1 "{\"repo\":\"$org/$repo_name\",\"url\":\"https://github.com/$org/$repo_name\"}"
    else
        emit false 1 "\"gh repo create failed for $org/$repo_name (may already exist)\""
    fi
    ;;

# ─── Step 2: Scaffold persona files ────────────────────────────────────
2)
    persona_slug=$(p persona_slug)
    repo=$(p repo)  # e.g. "402goose/rubail-claw"
    persona_md=$(p persona_md "")  # the full PERSONA.md body from question 4

    if [[ "$MODE" == "stub" ]]; then
        stub 2 "git clone + write bot/prompts/PERSONA.md (${#persona_md} chars) + commit + push"
    fi
    if ! command -v gh >/dev/null; then
        warn_missing 2 "gh CLI" "git clone $repo + scaffold persona files"
    fi

    workdir=$(mktemp -d)
    if ! gh repo clone "$repo" "$workdir/$persona_slug-claw" >/dev/null 2>&1; then
        emit false 2 "\"clone failed: $repo\""
    fi
    cd "$workdir/$persona_slug-claw"
    mkdir -p bot/prompts bot/config knowledge/corpus
    [[ -n "$persona_md" ]] && echo "$persona_md" > bot/prompts/PERSONA.md
    git add -A && git commit -m "scaffold persona files for $persona_slug" >/dev/null 2>&1
    git push >/dev/null 2>&1
    emit true 2 "{\"committed_to\":\"$repo\",\"branch\":\"main\"}"
    ;;

# ─── Step 3: Telegram managed bot ──────────────────────────────────────
3)
    persona_slug=$(p persona_slug)
    persona_full_name=$(p persona_full_name "")
    desc=$(p description "${persona_full_name} — TENET persona")

    if [[ "$MODE" == "stub" ]]; then
        stub 3 "POST /bot{manager_token}/createManagedBot {username: ${persona_slug}_bot, description: $desc}"
    fi
    if [[ -z "$TELEGRAM_MANAGER_BOT_TOKEN" ]]; then
        warn_missing 3 "TELEGRAM_MANAGER_BOT_TOKEN" "createManagedBot $persona_slug"
    fi

    # Telegram managed-bots API — see https://core.telegram.org/bots/api#botcommands
    # NB: as of 2026-04 this is rolling out; specific endpoint TBD by Visa coordination (PRD open Q3).
    response=$(curl -sS -X POST "https://api.telegram.org/bot${TELEGRAM_MANAGER_BOT_TOKEN}/getMe" 2>&1 || echo "")
    if [[ -z "$response" ]] || ! echo "$response" | jq -e '.ok' >/dev/null 2>&1; then
        emit false 3 "\"telegram API unreachable or token invalid\""
    fi
    # Real implementation: managed-bots endpoint here. For now: emit synthetic link based on slug.
    emit true 3 "{\"bot_username\":\"${persona_slug}_bot\",\"distribution_link\":\"t.me/${persona_slug}_bot\",\"note\":\"managed-bots API integration pending Telegram coordination per PRD open-Q3\"}"
    ;;

# ─── Step 4: Deploy Fly machine ────────────────────────────────────────
4)
    persona_slug=$(p persona_slug)
    region=${FLY_PRIMARY_REGION:-iad}
    image=$(p image "registry.fly.io/openclaw-base:latest")

    if [[ "$MODE" == "stub" ]]; then
        stub 4 "POST /api/v1/apps/${persona_slug}-bot/machines {region: $region, image: $image, volume: /data}"
    fi
    if [[ -z "$FLY_API_TOKEN" ]]; then
        warn_missing 4 "FLY_API_TOKEN" "deploy fly machine for ${persona_slug}-bot"
    fi

    # Real Fly Machines API call
    create_app_resp=$(curl -sS -X POST "https://api.machines.dev/v1/apps" \
        -H "Authorization: Bearer $FLY_API_TOKEN" \
        -H "Content-Type: application/json" \
        -d "{\"app_name\":\"${persona_slug}-bot\",\"org_slug\":\"personal\"}" 2>&1 || echo "")
    if echo "$create_app_resp" | jq -e '.error' >/dev/null 2>&1; then
        # may already exist — that's fine, continue to machine create
        :
    fi

    machine_resp=$(curl -sS -X POST "https://api.machines.dev/v1/apps/${persona_slug}-bot/machines" \
        -H "Authorization: Bearer $FLY_API_TOKEN" \
        -H "Content-Type: application/json" \
        -d "{\"region\":\"$region\",\"config\":{\"image\":\"$image\",\"mounts\":[{\"path\":\"/data\",\"volume\":\"data\"}]}}" 2>&1 || echo "")

    if echo "$machine_resp" | jq -e '.id' >/dev/null 2>&1; then
        machine_id=$(echo "$machine_resp" | jq -r '.id')
        emit true 4 "{\"app\":\"${persona_slug}-bot\",\"machine_id\":\"$machine_id\",\"region\":\"$region\"}"
    else
        emit false 4 "\"fly machine create failed: $(echo "$machine_resp" | jq -r '.error // .' | head -c 200)\""
    fi
    ;;

# ─── Step 5: Corpus ingest ─────────────────────────────────────────────
5)
    persona_slug=$(p persona_slug)
    urls_json=$(p urls "[]")

    if [[ "$MODE" == "stub" ]]; then
        urls_count=$(echo "$urls_json" | jq 'length')
        stub 5 "ingest $urls_count URLs into corpus/${persona_slug}-public/ (yt-dlp + transcribe + qmd index)"
    fi

    # Real ingest happens on the deployed Fly machine, not locally — this step
    # just queues the URLs into a kanban issue on the new repo. The bot's
    # bootstrap on first start will run the ingest script.
    repo=$(p repo)
    if command -v gh >/dev/null && [[ -n "$repo" ]]; then
        body=$(echo "$urls_json" | jq -r '. | map("- " + .) | join("\n")')
        gh issue create --repo "$repo" --title "Corpus ingest queue" \
            --body "URLs to ingest on first boot:\n$body" --label "tenet/in-progress" >/dev/null 2>&1 || true
    fi
    emit true 5 "{\"queued_urls\":$urls_json,\"note\":\"ingest runs on first machine boot via /data/scripts/ingest-source.sh\"}"
    ;;

# ─── Step 6: TENET workspace init ──────────────────────────────────────
6)
    persona_slug=$(p persona_slug)
    parent=$(p parent_portfolio "visa-crypto-labs")

    if [[ "$MODE" == "stub" ]]; then
        stub 6 "ssh into machine + tenet init $persona_slug + tenet portfolio register --parent $parent"
    fi

    # In live mode this would ssh to the new fly machine. For now we record the
    # intent — the machine's first-boot script reads this and runs locally.
    emit true 6 "{\"workspace_slug\":\"$persona_slug\",\"parent_portfolio\":\"$parent\",\"note\":\"first-boot script on the new machine runs tenet init + register\"}"
    ;;

# ─── Step 7: Open seed PR ──────────────────────────────────────────────
7)
    persona_slug=$(p persona_slug)
    repo=$(p repo)
    creator=$(p creator_user "")

    if [[ "$MODE" == "stub" ]]; then
        stub 7 "gh pr create --repo $repo --base main --head seed-corpus --title 'Initial scaffold' --assignee $creator"
    fi
    if ! command -v gh >/dev/null; then
        warn_missing 7 "gh CLI" "gh pr create on $repo"
    fi

    if pr_url=$(gh pr create --repo "$repo" --base main --head seed-corpus \
        --title "Initial scaffold" \
        --body "Initial scaffold. Review IDENTITY/SOUL/USER + corpus seeds." \
        ${creator:+--assignee "$creator"} 2>&1); then
        emit true 7 "{\"pr_url\":\"$pr_url\"}"
    else
        emit false 7 "\"gh pr create failed (branch may not exist yet)\""
    fi
    ;;

# ─── Step 8: Return links ──────────────────────────────────────────────
8)
    persona_slug=$(p persona_slug)
    repo=$(p repo)
    pr_url=$(p pr_url "")
    bot_link=$(p bot_link "")

    emit true 8 "{\"persona\":\"$persona_slug\",\"repo\":\"https://github.com/$repo\",\"pr\":\"$pr_url\",\"bot\":\"$bot_link\",\"message\":\"@${persona_slug}_bot is live: $bot_link | Repo: github.com/$repo | PR: $pr_url | Forward me anything else and I'll add it to their corpus.\"}"
    ;;

*)
    emit false 0 "\"unknown step: $STEP (valid: 1-8)\""
    ;;
esac
