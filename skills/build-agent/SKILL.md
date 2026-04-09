---
name: build-agent
description: Create build agents with decomposed evals from specs — the proven pattern for 100% convergence in 1-3 rounds
disable-model-invocation: true
triggers:
  - build agent
  - create agent
  - new agent
  - decompose eval
  - behavioral eval
  - spec to eval
  - eval from spec
  - /build
  - overnight agent
  - make an agent
---

# /build — Create Agents with Decomposed Evals

Build agents that converge in 1-3 rounds. The secret: **decomposed evals give gradient, monolithic evals give noise.**

> "Granularity of feedback determines speed of convergence."
> Monolithic eval → 7% keep rate, agents stall for hours.
> Decomposed eval → 100% in one round. Same agent. Same code. Different gradient.

---

## ⛔ PHASE 0 — BEFORE ANYTHING ELSE (HARD GATE)

**Do this EVERY time. Takes 2 minutes. Saves hours of wrong-spec agent rounds.**

```
1. tenet_context("TOPIC keywords")         — find ALL PRDs, specs, journals in scope
2. READ every file returned                — especially *_PRD.md, *_ARCHITECTURE*.md
3. tenet_memory_search("TOPIC decisions")  — find past decisions about this area
4. gh issue list --search "TOPIC"          — find existing issues, avoid duplicates
5. ls specs/ eval/build/ .tenet/agents/    — inventory what already exists
```

**Real example of why:** COCKPIT_PRD.md (567 lines, fully specced) existed and was missed because Phase 0 was skipped. Agent ran 3 rounds against a wrong spec. ~45 agent minutes, 0 usable output.

**Only AFTER Phase 0 completes:** write specs, file issues, build evals, launch agents.

---

## ⛔ TWO MANDATORY USER CHECKPOINTS

**Checkpoint A — after dep graph (step 5b), before evals (step 6):**
Show user: dep graph + issue list + V×U/C scores + execution order.
Ask: "Here's the plan. Anything to change before I build evals and launch agents?"
**Do NOT proceed until user explicitly says yes.**

**Checkpoint B — after backward arm (step 14b), before PRs (step 15):**
Show user: final scores + red team + QA fleet results.
Ask: "N/N converged. Red team: pass/fail. QA: N/N approve. OK to create PRs?"
**Do NOT create PRs until user explicitly says yes.**

---

## ⛔ PRE-LAUNCH VALIDATION (run before EVERY agent dispatch)

```bash
# 1. Baseline < 1.0 (score > 1.0 = eval checking wrong files, broken AGENT_WORKTREE)
npx tsx eval/build/<name>.ts        # must return value between 0.0 and 0.9

# 2. TOML name matches agent name exactly
tenet build --list                  # "build-X" must appear before running it

# 3. Spec + eval committed (not dirty — agent reads frozen EXPERIMENTS.md)
git status specs/ eval/build/ .tenet/agents/   # must be clean

# 4. Dep graph exists and is approved
cat specs/dependency-graph-v2.md    # must exist before dispatch
```

---

## CHECKPOINT: Which Mode Are You In?

**Answer this before doing anything else.**

```
Are you running more than 3 agents, or will this run overnight?
  YES → use: tenet recipe run overnight-pipeline.yaml
  NO  → use: tenet build --run <name> (single agent, ad-hoc)

Are you creating a new agent from an issue?
  YES → read the issue scope: label → resolve target_repo from .tenet/config.json registered_services
        NEVER use target_repo = "." if the issue has scope:tenet-platform, scope:tenet-cli, etc.
```

### Service Routing (REQUIRED — not optional)

Every agent MUST target the correct service repo. Issues in GTM have `scope:` labels that tell you where code lives:

| Label | target_repo | Local path |
|-------|-------------|------------|
| `scope:tenet-platform` | `tenet-platform` | `/Users/alectaggart/CascadeProjects/jfl-platform` |
| `scope:tenet-cli` | `tenet-cli` | `/Users/alectaggart/CascadeProjects/jfl-cli` |
| `scope:tenet-template` | `tenet-template` | `/Users/alectaggart/CascadeProjects/jfl-template` |
| `scope:tenet-skills` | `tenet-skills` | `/Users/alectaggart/CascadeProjects/tenet-skills` |
| `scope:tenet-gtm` | `"."` | `/Users/alectaggart/CascadeProjects/jfl-gtm` (GTM itself) |

**No `scope:` label?** Read the issue body for `target_repo:` field. If missing, ask before assuming `"."`.

Spec files can declare target repo directly — the generator reads both:
```markdown
target_repo: tenet-platform
```
or in a `## Target Repo` section.

### Kanban Movement (REQUIRED — track every issue)

Every agent run MUST move the issue through kanban:

```
Before firing agent:  gh issue edit N --add-label "tenet/in-progress" --remove-label "tenet/backlog"
After convergence:    gh issue edit N --add-label "tenet/eval"        --remove-label "tenet/in-progress"
After PR merges:      gh issue close N --comment "Closed by PR #M"
After stall (3 flat): gh issue edit N --add-label "tenet/backlog"     --remove-label "tenet/in-progress"
                      # re-file with updated failing checks in body
```

### Worktree Enforcement

Agents ALWAYS run in isolated git worktrees in `/tmp`. NEVER run an agent with the main working directory as the target — that dirties the repo. The `tenet build --run` command handles this automatically via `agent-session.ts`. If you see an agent committing to `main` or to your active branch, something is wrong with the TOML `target_repo`.

**Verify worktrees are active:**
```bash
git -C <target-repo-path> worktree list
# Should show /tmp/tenet-agent-<name>-<hash> entries during active runs
```

### Overnight Pipeline Checklist

Before firing a batch overnight, confirm ALL of these:
- [ ] `specs/dependency-graph-v2.md` exists and is current
- [ ] All agent TOMLs have correct `target_repo` (NOT `"."` unless intentionally GTM)
- [ ] All agent TOMLs have `"AGENT.md"` and `"AGENTS.md"` in `files_readonly`
- [ ] Issues are labeled `agent-ready` and in `tenet/backlog`
- [ ] GitHub Actions billing is current (CI gates won't fire otherwise)
- [ ] Then run: `tenet recipe run overnight-pipeline.yaml`

**Never run `tenet build --run` in a loop manually for batch work.** That skips the dependency graph, epistemic injection, and kanban movement. Use the recipe.

---

## Quick Start

**From a spec file:**
```bash
tenet build --spec specs/my-feature.md --name my-feature
```

**From inline description:**
```bash
tenet build --name auth-module \
  --files src/lib/auth.ts \
  --desc "Create auth module with login(), logout(), session management"
```

**List agents + scores:**
```bash
tenet build --list
```

**Run agent:**
```bash
tenet build --run my-feature
```

---

## The Core Pattern

### Step 1: Write the Spec

A spec is a markdown file describing what to build. Every line becomes an eval assertion.

```markdown
# Auth Module Spec

Create `src/lib/auth.ts` with:
- Export `login(email: string, password: string): Promise<Session>`
- Export `logout(sessionId: string): Promise<void>`
- Define `interface Session { id: string; userId: string; expiresAt: Date }`
- Use bcrypt for password hashing
- JWT token generation with 24h expiry

Create `src/lib/auth.test.ts` with:
- Test login with valid credentials
- Test login with invalid credentials
- Test logout invalidates session
```

### Step 2: Decompose into Binary Checks

**This is the critical step.** Each spec line becomes one binary check in the eval. The eval returns `passed / total` — a score from 0.0 to 1.0 with maximum gradient.

```typescript
const checks = [
  // Level 1: Existence
  { name: "auth-file-exists", pass: existsSync("src/lib/auth.ts") },

  { name: "test-file-exists", pass: existsSync("src/lib/auth.test.ts") },

  // Level 2: Structure
  { name: "exports-login", pass: auth.includes("export") && auth.includes("login") },
  { name: "exports-logout", pass: auth.includes("export") && auth.includes("logout") },
  { name: "session-interface", pass: auth.includes("interface Session") },
  { name: "uses-bcrypt", pass: auth.includes("bcrypt") },
  { name: "uses-jwt", pass: auth.includes("jwt") || auth.includes("jsonwebtoken") },

  // Level 3: Compiles
  { name: "typescript-compiles", pass: tscExitCode === 0 },

  // Level 4: Behavioral
  { name: "login-test-exists", pass: test.includes("login") && test.includes("valid") },
  { name: "logout-test-exists", pass: test.includes("logout") },
]

return checks.filter(c => c.pass).length / checks.length
```

### Step 3: Create Agent TOML

```toml
[agent]
name = "build-auth-module"
scope = "build"
metric = "spec_compliance"
direction = "maximize"
time_budget_seconds = 600
rounds = 10
target_repo = "my-project"

[eval]
script = "eval/build/auth-module.ts"

[task]
spec = "specs/auth-module.md"
description = "Create auth module with login/logout, Session interface, bcrypt, JWT"

[constraints]
scope_files = ["src/lib/auth.ts", "src/lib/auth.test.ts"]
max_file_changes = 4
```

### Step 4: Run

The agent runs in the Karpathy loop: try → eval → keep/revert → repeat.
With decomposed evals, it typically converges in 1-3 rounds.

---

## Eval Hierarchy (Concrete → Abstract)

Build your checks in this order. Each level gives richer gradient:

| Level | What | Example | When |
|-------|------|---------|------|
| 1. Existence | File exists? | `existsSync("src/lib/auth.ts")` | Always |
| 2. Structure | Right exports/types? | `file.includes("export function login")` | Always |
| 3. Compiles | TypeScript passes? | `npx tsc --noEmit` exit code 0 | Always |
| 4. Behavioral | Code patterns correct? | `file.includes("bcrypt.hash")` | When behavior matters |
| 5. Integration | Works with other code? | Import succeeds, no runtime errors | After dependencies built |
| 6. Tests | Tests exist and logical? | Test file has describe/it blocks | When tests are in spec |

**Anti-pattern:** Jumping to Level 5/6 before Level 1-3 are solid. The agent needs to see files exist and compile before checking behavior.

---

## Eval Template

Every eval follows this exact structure:

```typescript
/**
 * [Feature Name] Build Eval
 * @purpose [What this eval verifies]
 */
import { existsSync, readFileSync } from "fs"
import { join } from "path"

// CRITICAL: Use AGENT_WORKTREE — eval must test the agent's branch, not main
const ROOT = process.env.AGENT_WORKTREE || process.cwd()
function resolve(p: string): string { return join(ROOT, p) }
function fileContent(p: string): string {
  const full = resolve(p)
  return existsSync(full) ? readFileSync(full, "utf-8") : ""
}

export async function evaluate(_dataPath: string): Promise<number> {
  const mainFile = fileContent("src/lib/my-module.ts")

  const checks = [
    // Level 1: Existence
    { name: "file-exists", pass: mainFile.length > 0 },

    // Level 2: Structure
    { name: "has-export", pass: mainFile.includes("export") },
    { name: "has-purpose-header", pass: mainFile.includes("@purpose") },

    // Level 3: Compiles (optional — add if TypeScript project)
    // { name: "compiles", pass: compileCheck() },

    // Level 4+: Behavioral checks from spec
    // ...
  ]

  const passed = checks.filter(c => c.pass).length
  const total = checks.length
  const failed = checks.filter(c => !c.pass).map(c => c.name)

  // CRITICAL: Write to stderr so the build supervisor can parse failing check names
  // and inject them into the hint. Format must match: "failed: check1, check2"
  console.error(`[eval] ${passed}/${total}: ${failed.length ? 'failed: ' + failed.join(', ') : 'all passing'}`)

  // ALSO write structured JSON to stdout for supervisor parsing
  // peter.ts reads lastEvalOutput and JSON.parses it for failed_checks
  if (failed.length > 0) {
    process.stdout.write(JSON.stringify({ failed_checks: failed, score: passed / total }) + '\n')
  }

  return passed / total
}
```

---

## Creating "Improve" Agents (not just "Build")

Build agents create new code (0% → 100%). **Improve agents** make existing code better:

```typescript
// Improve agent eval — checks patterns in existing code
const checks = [
  // Does the code have the correct pattern?
  { name: "tool-name-captured",
    pass: evalFile.includes("toolName") || evalFile.includes("tool.name") },

  // Does the error handling exist?
  { name: "hub-crash-event",
    pass: hubFile.includes("hub_crash") },

  // Is telemetry structured?
  { name: "memory-pressure-data",
    pass: telemetryFile.includes("mem_mb") },
]
```

Improve agents search existing files for correct patterns rather than checking file existence. Same eval structure, different assertion types.

---

## Decomposing a Spec into Checks

### Method: One assertion per spec sentence

Read the spec line by line. Each concrete claim becomes a check:

| Spec says | Check |
|-----------|-------|
| "Create `src/foo.ts`" | `existsSync("src/foo.ts")` |
| "Export `bar` function" | `file.includes("export") && file.includes("bar")` |
| "Define `Baz` interface" | `file.includes("interface Baz")` |
| "Use `bcrypt` for hashing" | `file.includes("bcrypt")` |
| "Handle errors with try/catch" | `file.includes("try") && file.includes("catch")` |
| "Must compile" | `execSync("npx tsc --noEmit")` exits 0 |
| "100ms response time" | Runtime benchmark (Level 5) |

### Method: Category-based checks

Group assertions by what they verify:

```typescript
const checks = [
  // Existence (does it exist?)
  ...files.map(f => ({ name: `${f}-exists`, pass: existsSync(resolve(f)) })),

  // Structure (right shape?)
  ...exports.map(e => ({ name: `exports-${e}`, pass: mainFile.includes(e) })),

  // Quality (good code?)
  { name: "has-purpose", pass: mainFile.includes("@purpose") },
  { name: "no-any-types", pass: !mainFile.includes(": any") },

  // Compiles
  { name: "tsc-passes", pass: compiles },
]
```

---

## CRITICAL: Never Write Stub Evals

`tenet build --spec X.md --name Y` auto-generates an eval skeleton with just a compile check. **This is a STUB — you MUST decompose it into behavioral checks before running.**

A stub eval (1 compile check) gives the agent ZERO gradient. It passes or fails as a block. The agent can't tell which part of the spec it's missing.

**Data proves this:** 13/13 converged agents had decomposed behavioral checks + failed_checks output. 3/7 stalled agents were missing failed_checks output — supervisor was blind.

| Pattern | Converged? | Why |
|---------|-----------|-----|
| 28 behavioral checks + stderr + failed_checks JSON | ✅ YES | Agent sees exactly which checks fail, targets them |
| 2 behavioral checks + stderr + failed_checks JSON | ✅ YES | Even 2 checks converge IF supervisor can read them |
| 15 checks but NO failed_checks JSON output | ❌ STALLED | Supervisor says "STALLED" but can't say which checks |
| 1 compile check (stub) | ❌ STALLED | Zero gradient — pass or fail as a block |

**After generating, ALWAYS:**
1. Open `eval/build/<name>.ts`
2. Replace the single compile check with Level 1-4 behavioral checks from the spec
3. Ensure `console.error('[eval] failed: ' + failed.join(', '))` exists
4. Ensure `process.stdout.write(JSON.stringify({ failed_checks: failed, score }) + '\n')` exists
5. THEN run the agent

## Common Failures & Fixes

| Failure | Root Cause | Fix |
|---------|-----------|-----|
| 0% keep rate | Eval tests main, not worktree | Use `AGENT_WORKTREE` env var |
| Agent stalls at 0.3 | Monolithic eval, no gradient | Decompose into binary checks |
| Score drops to 0 | Agent broke compilation | Always include compile check |
| Eval not found | Eval in wrong repo | Evals live IN the target repo |
| 70% timeout | Task prompt too long | Slim task to 1-2 sentences |
| CJS in ESM | Agent used `require()` | Add ESM pattern checks |
| Stalls at 0.91-0.92, never hits 1.0 | Supervisor hint says "STALLED" but doesn't say WHICH check failed | Log failing check names to stderr in eval: `console.error('[eval] failed: ' + failed.join(', '))` — supervisor parses this |
| Agent writes files, eval scores 0.0 | Spec or eval changed after agent launched (agent reads frozen EXPERIMENTS.md) | **Freeze the spec before launching.** `git commit` the spec + eval before `tenet peter agent run`. If spec changes mid-run, the agent has wrong target. |
| `target_repo = "jfl-cli"` fails | Name not in registered_services — it looks up by service name | When running agents **inside** the target repo, use `target_repo = "."` (relative path, not name) |
| Agent says "all files created" but score is 0.0 | Agent wrote to worktree but eval ran in wrong dir | Check `eval-debug` line in logs: cwd should be the worktree path. Always set `AGENT_WORKTREE` in eval and use `const ROOT = process.env.AGENT_WORKTREE \|\| process.cwd()` |
| OpenRouter 402 mid-run | Out of credits | Agent falls back to `claude CLI` automatically — this works, just slower. Top up OpenRouter or set `ANTHROPIC_API_KEY` directly |
| Agent writes to worktree, eval reads main | `AGENT_WORKTREE` env var not passed to eval subprocess | Check `eval-debug` log line — `cwd` should be the worktree path, not the main repo. If cwd is wrong, fix peter.ts eval spawning to set `AGENT_WORKTREE` |
| Clean build takes 5 rounds when 1 would do | Using PP eval loop for straightforward new-file builds | For clean builds with clear specs, use `pi -p` one-shot instead of eval loop. Reserve PP loop for improve agents or ambiguous specs |
| Pi workers can't run evals mid-build | One-shot workers don't have the keep/revert loop | Run eval AFTER pi worker finishes: `npx tsx eval/build/<name>.ts` to score. If <1.0, run another pi worker with failing checks as context |
| Claude CLI fallback exits without post-round eval | When OpenRouter 402 triggers Claude CLI spawn, agent output appears but eval never runs | The Claude CLI fallback may not signal completion back to peter.ts. Workaround: top up OpenRouter credits so API runtime is used instead. Or manually run eval: `AGENT_WORKTREE=/tmp/tenet-agent-<name> npx tsx eval/build/<name>.ts` |

---

## Spec Freeze — Do This Before Launching

**The agent reads EXPERIMENTS.md at the start of each round.** If the spec changes after launch, the agent has a stale target and will stall indefinitely.

```bash
# RIGHT: spec + eval committed before launch
git add specs/my-feature.md eval/build/my-feature.ts .tenet/agents/build-my-feature.toml
git commit -m "spec: my-feature ready to build"
tenet peter agent build-my-feature --rounds 10

# WRONG: launching with uncommitted changes
# The guard will warn: "Uncommitted changes in working directory"
# This is the #1 cause of 0% first-round scores
```

---

## Running Multiple Agents (Sequential or Parallel)

Build agents run as a **single process each** via `tenet build --run <name>` or `tenet peter agent <name>`. The delegator/parallel router was removed (as of 1.11.1) because it was the source of orphan process leaks. The new model is simpler: one process per task, one log, one PID, killable.

**For one agent:**
```bash
cd <target-repo>
tenet build --run my-agent
# or: tenet peter agent my-agent --rounds 10
```

**For multiple agents — sequential (the default, safe):**
```bash
cd <target-repo>
for agent in build-A build-B build-C; do
  tenet build --run $agent || echo "FAIL: $agent"
done
```

**For multiple agents — parallel (rare, explicit bash):**
```bash
cd <target-repo>
for agent in build-A build-B build-C; do
  ( setsid bash -c "tenet build --run $agent" >> log.$agent 2>&1 & )
done
wait  # or: trap 'pkill -g $PGID' EXIT for cleanup
```

**When to use which:**
- **Sequential** is the default — simpler, deterministic, easy to debug, no orphan risk
- **Parallel** only when wall-clock matters AND you own the process group cleanup
- **Overnight push**: `scripts/overnight-build.sh` runs the sequential loop for you

**Why sequential over parallel:**
- Single PID = clean cost attribution for spend tracking
- Single log = fast failure debugging
- Single branch = no merge conflicts between workers
- Deterministic = reproducible (replay by running same spec + baseline)
- No process group complexity = no orphan leaks on termination

---

## Real Results

### Session 2026-04-05: 7 agents, 3 repos, 143 checks
- **6/7 converged to 1.0** (86% success rate)
- Mean rounds to convergence: **2.5** (PP agents), **1.0** (pi one-shot workers)
- Pi workers hit 100% on first attempt — no eval loop needed when spec is clear
- 1 failure: AGENT_WORKTREE not set → eval scored main instead of worktree → reverted good code

| Agent | Checks | Rounds | Trajectory | Method |
|-------|--------|--------|------------|--------|
| scout-agent (31 checks) | 31 | 2 | 0→97→100 | PP eval loop |
| mesh-dashboard (14) | 14 | 3 | 0→?→100 | PP eval loop |
| qa-agent (19) | 19 | 5 | 0→6→10→15→17→19 | PP eval loop |
| pp-cross-model (14) | 14 | ~3 | 9→12→14 | PP eval loop |
| recipe-bundle (14) | 14 | 1 | 0→14 | pi one-shot |
| linear-dashboard (17) | 17 | 1 | 0→17 | pi one-shot |
| synth-subway (14) | — | FAIL | 3→3 (worktree bug) | PP eval loop |

### Key Finding: One-Shot vs Eval Loop

**If spec is clear + all new files → pi one-shot is faster and equally reliable.**
The eval loop matters most for **improve agents** modifying existing code.

Decision tree:
```
Is this a clean build (all new files)?
  YES → Is the spec specific (file paths, function signatures)?
    YES → pi -p "Read spec, build it" --no-session  (one-shot, ~2min)
    NO  → PP eval loop (needs gradient to converge)
  NO → PP eval loop (improve agent, needs iterative refinement)
```

### Previous results (overnight batch):
- **12/12 build agents hit 1.0** in the first batch
- **Keep rate: 14-22%** — stalls caused by missing check names in supervisor hints. Fix: always log failing checks to stderr.

---

## The Pipeline: Issue → Spec → Eval → Run

Evidence from build-journal data across all agent runs shows the optimal ordering:

```
Issue (what + why + acceptance criteria)     ← for HUMANS/KANBAN
  → Spec (how + which files + impl detail)   ← for AGENT
    → Eval (binary checks from spec)          ← for GRADIENT
      → TOML (agent config)                   ← for RUNNER
        → Freeze (git commit all)             ← CRITICAL
          → Run                               ← one-shot or eval loop
```

**Issues come first** because: they're the kanban item, `--from-issue` uses them, multiple specs can resolve one issue.

**Specs come from issues** because: they TRANSLATE intent into agent-readable instructions. They ADD file paths, function signatures, constraints that the issue doesn't have.

**But issues are optional for convergence.** The pincer session proved 16/16 agents converge with just specs, no issues. Issues are for the SYSTEM (kanban, tracking, team visibility), not for the AGENT (it reads the spec).

**What determines convergence** (ranked by impact):
1. Eval gradient quality (decomposed binary checks)
2. Supervisor hint specificity (failing check names in stderr)
3. Spec freeze (commit before launch)
4. Spec clarity (specific file paths + function signatures)

**What does NOT determine convergence:**
- Whether a GitHub Issue existed before the spec
- Issue body length or detail level
- Number of eval checks (31-check agent converged in 2 rounds)

---

## On Skill Invoke

When the user asks to create an agent or eval:

### Step 0: Verify Infrastructure (BEFORE creating agent)

Check that the repo has the pipeline to support autonomous agents:

```bash
# CI — agent PRs need automated checks
ls .github/workflows/ci.yml           # build + test
ls .github/workflows/tenet-eval.yml   # eval on PR
ls .github/workflows/tenet-review.yml # Sentinel bot review
ls .github/workflows/kanban.yml       # auto-move cards on PR events
```

If any are missing, offer to run:
```bash
tenet ci setup        # creates CI + eval + review workflows
# OR use the ci-setup skill for guided walkthrough
```

Also verify:
- **Kanban labels exist**: `agent-ready`, `tenet/backlog`, `tenet/in-progress`, `tenet/eval`, `tenet/done`
- **Sentinel bot active**: GitHub App installed on repo
- **Overnight schedule**: agent added to `scripts/overnight-build.sh`

Without these, the agent can build code but PRs won't get reviewed, issues won't move, and nothing runs overnight.

### Step 1: Understand What They Want

Ask:
1. **What are you building/improving?** (new feature vs existing code)
2. **What repo/files?** (where does the code live)
3. **Do you have a spec?** (markdown file describing the feature)

### Step 2: Choose Build vs Improve

- **Build agent** (`scope = "build"`): Creating new files from scratch. Score goes 0% → 100%.
- **Improve agent** (`scope = "improve"`): Making existing code better. Score tracks pattern presence.

Note: The supervisor (stall detection + hint injection), epistemic context, presence tracking, and early termination at 1.0 work for ALL scopes — not just build. Every agent gets the full loop.

### Step 3: Write the Spec (if none exists)

Use the `/spec` skill to generate a reviewed spec, OR write one directly:

```markdown
# [Feature Name] Spec

## What to create
- `path/to/file.ts` — description of what it does

## Requirements
- Export `functionName(params): ReturnType`
- Define `InterfaceName { field1, field2 }`
- Use library X for Y
- Handle error case Z

## Constraints
- Must compile with TypeScript
- Max N files changed
```

### Step 4: Generate the Eval

Run `tenet build --spec <path> --name <name>` OR manually create:

1. **`eval/build/<name>.ts`** — decomposed eval script following the template above
2. **`.tenet/agents/build-<name>.toml`** — agent config

If generating manually, follow the eval template exactly. Every spec line = one binary check.

### Step 5: Run Baseline

```bash
# Test the eval against current code
npx tsx eval/build/<name>.ts
```

The baseline should be < 1.0 (otherwise nothing to build). Typically 0% for new builds, 50-90% for improve agents.

### Step 6: Run the Agent

```bash
tenet build --run <name>
# OR
tenet peter agent build-<name> --rounds 5
# OR (overnight)
tenet flow run overnight
```

---

## Priority Scoring (Overnight Flow)

When the overnight flow picks agents, it uses priority scoring:

| Category | Priority Boost |
|----------|---------------|
| reliability / telemetry / session | +100 |
| infrastructure (docker, storage, secrets) | +50 |
| quality metrics (coverage, speed) | +30 |
| never-run (needs baseline) | +20 |
| room to improve (1 - score) × 10 | variable |

Name your agents well — `session-reliability`, `telemetry-capture`, etc. — so the overnight flow prioritizes them correctly.

---

## Running via `delegate` tool (from pi sessions)

Build agents can be invoked from a pi session via the `delegate` tool:

```
delegate(build_agent: "marketplace-page")
```

With an issue:
```
delegate(build_agent: "marketplace-page", from_issue: 55)
```

As of 1.11.1, this is a **thin shellout to `tenet build --run`** — no parallel router, no file-exclusive buckets, no worker subprocesses. It runs:

```bash
tenet build --run marketplace-page [--from-issue 55]
```

in the current working directory, inheriting stdio. Single process, single log, one PID. The convergence loop, supervisor, epistemic context, and journal all still fire from inside `tenet build --run`.

### What you get
- Full supervisor (stall detection + hints)
- Epistemic context (blind spot warnings) injected into EXPERIMENTS.md at round 0
- Issue linking (PR gets `Closes #55`) via `--from-issue` flag
- Journal entry on completion (written by peter.ts runner)
- Deterministic reproduction (same spec + baseline = same trajectory)

### What you don't get (intentionally)
- Parallel worker spawning (if you need it, use the bash parallel pattern above)
- File-exclusive bucket routing (resolve at spec time, not runtime)
- Cross-worker presence awareness (never actually consulted in production)

### Build Agent Flow (single-process)
```
delegate(build_agent: "marketplace-page", from_issue: 55)
  → tenet build --run marketplace-page --from-issue 55
  → baseline eval runs
  → build loop: branch → change → eval → keep/revert → supervisor
  → epistemic context injected before first round
  → on convergence: git commit with Agent-Id trailer
  → push branch + open PR with Closes #55
  → journal entry written
```

---

## Full Pipeline Orchestration (Issue → Graph → Run → Review → Sharpen)

The build-agent skill isn't just for one agent. When invoked with a backlog of issues, follow this pipeline.

**CRITICAL: Load the build-cycle bundle first:**
```
tenet recipe run build-cycle.yaml
```
This loads ALL required skills and follows The Sequence automatically.
If running manually, load each skill as you reach its step.

### Bundle: build-cycle

```
BUNDLE: build-cycle
├── RECIPE: build-cycle.yaml (The Sequence as executable YAML — PP follows this)
├── SKILL: build-agent     (The Sequence as LLM instructions)
├── SKILL: spec            (Step 2-3: adversarial multi-model review)
├── SKILL: eval            (Step 6: decompose specs into binary checks)
├── SKILL: kanban          (Step 1,5,15: scan backlog, re-roll issues, create PRs)
├── SKILL: context         (Step 9: epistemic boundaries, blind spots, coverage map)
├── SKILL: orchestrate     (Step 10-11: direct dispatch, convergence monitoring)
├── SKILL: pi-agents       (Step 10: single-process agent spawning)
├── SKILL: debug           (Step 13: red team vulnerability scanning)
├── SKILL: spawn-salon     (Step 13: deploy red team fleet personas)
├── SKILL: ci-setup        (Step 16-18: sentinel, eval-on-PR, qa-fleet CI workflows)
├── SKILL: search          (Step 19: ceremony, memory-powered diagnosis)
├── SKILL: viz             (Step 19: convergence visualization)
├── RECIPE: epistemic-audit.yaml   (Step 9: blind spot detection)
├── RECIPE: ai-redteam.yaml        (Step 13: 4-agent red team + CSO director)
├── RECIPE: security-audit.yaml    (Step 13: security scanning)
├── RECIPE: daily-release-check.yaml (Step 15: pre-release verification)
├── RECIPE: analyze-pr.yaml        (Step 16: PR analysis)
├── LIB: src/lib/epistemic-boundaries.ts  (blind spot map)
├── LIB: src/lib/qa-fleet.ts              (5-persona QA review)
├── LIB: src/lib/qa-runner.ts             (QA check runner)
├── LIB: src/lib/skill-learner.ts         (backward arm: harvest learnings)
├── LIB: src/lib/meta-orchestrator.ts     (parallel groups, convergence)
├── LIB: src/lib/eval-snapshot.ts         (frozen evals, AGENT_WORKTREE)
├── LIB: src/lib/build-eval-generator.ts  (spec → eval decomposition)
├── LIB: src/lib/training-buffer.ts       (RL training tuples)
├── LIB: src/lib/policy-head.ts           (action scoring)
├── EXT: packages/pi/extensions/delegate-tool.ts (thin shellout to tenet build --run)
├── EXT: packages/pi/extensions/swarm-runner.ts (background swarm + TUI widget)
├── EVAL: eval/qa-fleet/fixtures/*.diff   (planted defect benchmarks)
└── AGENTS: agents/qa-fleet/*.md          (5 persona SOUL files)
```

### The Sequence — Step-by-Step with Exact Tools

**Do NOT skip steps. Do NOT do things manually with bash. Each step has a tool — USE IT.**

### The Sequence (this is the order — don't skip steps)

```
── PLANNING ──────────────────────────────────────────
1. SCAN       — read all issues, find what's missing (spec/eval/TOML)
2. SPEC       — generate specs via /spec skill for each issue
3. REVIEW     — adversarial multi-model review (skeptic, implementer, security)
4. GRAPH      — dependency graph (graph deps + path deps + value scores)
5. RE-ROLL    — update issues/specs from review + graph analysis
6. EVAL       — decompose reviewed specs into binary eval checks
7. TOML       — create agent configs
8. BASELINE   — run every eval to confirm starting scores

── FORWARD ARM (build) ───────────────────────────────
9. EPISTEMIC  — run `tenet epistemics` on target files: where are the blind spots?
               Inject into agent context: "these areas have never been tested/reviewed"
               Delegator uses this to assign EXTRA eval checks for blind spot areas
               Presence: write what files each agent is touching to .tenet/presence/
               Other agents see this → avoid conflicts, coordinate
10. DISPATCH  — fire agents via tenet build --run, graph order, highest value first
               Delegator reads epistemic map → routes agents to blind spots first
               Delegator reads presence → parallel on disjoint files, queue on shared
               Each agent gets: spec + eval + epistemic context + presence awareness
11. CONVERGE  — agents iterate: build → eval → keep/revert → repeat until 1.0

── BACKWARD ARM (validate) ───────────────────────────
12. SCORE     — final eval on each branch, memory search on failures
13. RED TEAM  — run cyber/redteam recipe against new code BEFORE PR
14. QA        — run DX test agents: does it start clean? skill matching work? UX smooth?

── LEGS (review + ship) ──────────────────────────────
15. PR        — create PRs only for code that survived red team + QA
16. SENTINEL  — multi-model code review on PR
17. CODEX     — docs review on PR (if docs changed)
18. MERGE     — auto-merge if sentinel + codex approve at trust tier 3+

── BRAIN (learn + plan) ──────────────────────────────
19. CEREMONY  — Stratus brain: what shipped, predicted vs actual, learnings
20. SHARPEN   — update skills/recipes/evals from learnings
21. DOGFOOD   — use what just shipped to improve the NEXT cycle
22. REPEAT    — loop with updated graph, better tools, smarter routing
```

### Tool Map — What to call at each step

| Step | Name | Skill to Load | Tool / Command | Lib |
|------|------|---------------|----------------|-----|
| 1 | SCAN | `kanban` | `gh issue list --label agent-ready` + cross-ref `specs/` `eval/build/` `.tenet/agents/` | — |
| 2 | SPEC | `spec` | `tenet_skill_load("spec")` → feed issue body → adversarial review | — |
| 3 | REVIEW | `spec` | spec skill spawns 3 personas (skeptic/implementer/security) automatically | — |
| 4 | GRAPH | — | Two types: **graph deps** (structural must-before: #67→#75) + **path deps** (strategic: shipping scorecard first makes everything measurable). Compute V×U/C per issue. `tenet_memory_search("dependency")` → `tenet_policy_rank` for Stratus path optimization → write `specs/dependency-graph-v2.md` | `policy-head.ts` |
| 5 | RE-ROLL | `kanban` | `gh issue edit N --body` for split/kill/expand from review | — |
| 6 | EVAL | `eval` | `tenet build --spec specs/X.md --name X --dry-run` → generates `eval/build/X.ts` | `build-eval-generator.ts` |
| 7 | TOML | — | `tenet build --spec specs/X.md --name X` → generates `.tenet/agents/build-X.toml` | `agent-config.ts` |
| 8 | BASELINE | — | `npx tsx eval/build/X.ts` for each → `git commit -m "spec freeze"` | `eval-snapshot.ts` |
| 9 | EPISTEMIC | `context` | `tenet epistemics audit` → `.tenet/epistemic-map.json`. Inject blind spots into each agent's EXPERIMENTS.md via `injectEpistemicContext()`. This runs BEFORE dispatch — agents start smart, not blind. Sequential order priorities blind-spot agents first. | `epistemic-boundaries.ts` |
| 10 | DISPATCH | `orchestrate` + `pi-agents` | **Sequential single-process dispatch**: `tenet build --run <agent> [--from-issue N]`. Each agent = one process, one log, one PID, one branch. No router, no buckets, no worker spawning. If you need parallelism (rare), use explicit bash: `( setsid bash -c "tenet build --run $a" & )` with process-group cleanup. Fire in graph order — highest V×U/C first, respecting graph deps. | `src/commands/peter.ts` |
| 11 | CONVERGE | — | Each agent loops: build → eval → keep/revert → repeat. Early stop at 1.0. Stall detection: 3 flat rounds = stop. **Supervisor** (`build-supervisor.ts`): after EVERY round, `checkRound(history)` parses `failed_checks` from eval stderr, detects stall patterns (STALLED, regression, filename mismatch), injects hint into EXPERIMENTS.md. `logLearning()` writes to `.tenet/build-learnings.jsonl` — the supervisor's teacup memory. `start_swarm` tool runs this as background task with TUI widget — no sleep polling. | `meta-orchestrator.ts`, `build-supervisor.ts`, `swarm-runner.ts` |
| 12 | SCORE | `eval` | Run eval on EACH agent's worktree: `AGENT_WORKTREE=/path npx tsx eval/build/X.ts`. For failures: `tenet_memory_search("failure pattern X")` → diagnose why. Record training tuple: `tenet_training_buffer(action_type, description, outcome, delta)`. Update `build-journal.jsonl` with per-agent trajectory. | `eval-snapshot.ts`, `training-buffer.ts` |
| 13 | RED TEAM | `debug` + `spawn-salon` | Run BEFORE PR, on branch code: `AGENT_WORKTREE=/path tenet recipe run ai-redteam.yaml --param phase=1`. 4 agents (injector, extractor, escape, supply-chain) + CSO director. If vulns found → file sub-issues → agent gets another round to fix → only hardened code becomes PR. Nishant reviews findings for cyber screening. | `ai-redteam.yaml`, `security-audit.yaml` |
| 14 | QA | — | Run BEFORE PR: `tenet qa fleet --diff <branch>`. 5 personas (security, integration, startup, performance, brand) each review the diff. Planted defect benchmarks verify detection accuracy. Clean PRs must NOT trigger false positives. Fleet consensus: all approve → proceed, any critical → block, warnings → proceed with note. | `qa-fleet.ts`, `qa-runner.ts`, `agents/qa-fleet/*.md`, `eval/qa-fleet/fixtures/` |
| 15 | PR | `kanban` | **Only for code that survived red team + QA.** `gh pr create --title "agent(X): ..." --body "Closes #N\n\nEval: score\nRed team: pass\nQA fleet: N/N approve"`. Sentinel reviews ALREADY-HARDENED code → fewer comments. | — |
| 16 | SENTINEL | `ci-setup` | Auto-triggers via `.github/workflows/tenet-sentinel.yml`. Multi-model code review (hathbanger/pr-sentinel). Posts findings as PR comment. Install with `tenet ci setup --all` on target repo. | `tenet-sentinel.yml` |
| 17 | CODEX | — | Auto-triggers via `.github/workflows/tenet-review.yml`. Checks: README updated? llms.txt current? knowledge/ docs reflect changes? Eval checks docs if any `.md` files changed. | `tenet-review.yml` |
| 18 | MERGE | `ci-setup` | At trust tier 3+: `gh pr merge --auto --squash`. At tier 2: human reviews fleet + sentinel findings, approves. At tier 1: human reviews everything. Trust tier from `.tenet/config.json` trust_level per agent. | — |
| 19 | CEREMONY | `search` | **Stratus brain recipe**: `tenet_synopsis` → what shipped. `tenet_policy_rank` → predicted vs actual value. `tenet epistemics audit` → blind spot changes. Writes digest with: shipped items, path optimality %, new blind spots, next cycle plan. If Stratus unavailable, fall back to synopsis + memory search. | `policy-head.ts` |
| 20 | SHARPEN | — | `harvestLearnings()` for each skill used this cycle. `propagateToPortfolio()` for cross-GTM sync. Update eval checks if new failure patterns found. Update recipes if orchestration could be better. | `skill-learner.ts` |
| 21 | DOGFOOD | — | If this cycle shipped a tool (scorecard, new skill, CI workflow), USE IT in step 22's planning. Flag in `.tenet/dogfood-queue.json`. The system tests its own output. | — |
| 22 | REPEAT | — | Back to step 1. Graph is now better (shipped items removed, new issues from red team/QA added). Stratus predictions are better (predicted vs actual from step 19). Skills are better (sharpened in step 20). The loop compounds. | — |

### The Pincer Pattern (body analogy)

**Forward arm**: build agents write code (Step 10-11)
**Backward arm**: eval + red team + QA validate it (Step 12-14)
**Left leg**: sentinel + codex review and approve (Step 15-18)
**Right leg**: merge + deploy + ship (Step 18)
**Brain**: Stratus ceremony plans next cycle (Step 19-22)

Both arms must complete before the legs move. The brain runs last and makes everything smarter for next time.

### Critical: Red Team BEFORE PR (not after)

The red team and cyber recipe run AGAINST the branch code BEFORE a PR is created:
```bash
# On the agent's branch, not main
AGENT_WORKTREE=/path/to/worktree tenet recipe run ai-redteam.yaml
```

If red team finds vulnerabilities:
- File them as sub-issues linked to the parent
- Agent gets another round to fix them
- Only AFTER red team passes → create PR
- This means sentinel reviews ALREADY-HARDENED code

### Critical: Dogfood Step (use what you just shipped)

Step 20 is the meta-loop. When the pipeline ships a tool, USE that tool in the next cycle:
- Shipped scorecard? → Next cycle's ceremony uses the real scorecard
- Shipped a faster eval harness? → Next cycle uses it
- Shipped multi-model? → Next cycle's spec review uses multiple models
- Shipped mailman? → Next cycle's ceremony sends the digest email

This is how the system TESTS its own output. If the scorecard breaks when you use it, you find out immediately — not in 3 weeks.

### Why this order:
- SPEC before GRAPH: can't compute deps without knowing what each issue builds
- REVIEW before GRAPH: adversarial review might CHANGE the spec (split, kill, expand)
- GRAPH before EVAL: graph might de-prioritize some issues entirely
- RE-ROLL before EVAL: review feedback changes spec → changes eval checks
- RED TEAM before PR: harden code BEFORE review, not after
- QA before PR: catch DX issues before they reach sentinel
- SENTINEL after red team: reviews already-hardened code = fewer comments
- DOGFOOD before REPEAT: use new tools to improve the pipeline itself
- SHARPEN before REPEAT: next cycle uses improved recipes

### Step A: Scan the Backlog

```bash
gh issue list --state open --label agent-ready --json number,title,body,labels
```

For each issue:
1. Does it have a spec? Check `specs/` directory
2. Does it have an eval? Check `eval/build/`
3. Does it have a TOML? Check `.tenet/agents/`
4. If ANY are missing → create them (Steps 1-4 from the single-agent flow)

### Step B: Spec Generation via /spec Skill

For each issue missing a spec, invoke the spec skill:
```
tenet_skill_load("spec")
```

Feed it the issue body + any linked memories. The spec skill runs adversarial review:
- **Skeptic** (different model): "This spec is missing error handling for X"
- **Implementer** (different model): "This can't be built as described because Y"
- **Security** (different model): "This introduces risk Z"

After review, the spec is updated with all feedback addressed.

If the review suggests splitting an issue → create new issues, link them.
If the review kills an issue (not worth building) → close it with rationale.

### Step B2: Re-Roll Issues Based on Review

Adversarial review may change the landscape:
- Spec A got split into A1 + A2 → two new issues, two new specs
- Spec B got killed → issue closed, remove from graph
- Spec C got new requirements → update issue body to match

This is the RE-ROLL step. The issues themselves may change before we build the graph.

### Step C: Build the Dependency Graph (Two Types of Dependencies)

**Graph dependencies** (structural — hard constraints):
- #67 trust ladder MUST come before #75 agent wallets (wallets need trust tiers)
- #69 mailman changelog MUST come after mailman-subway is merged
- These are topological — can't reorder. Traditional DAG.

**Path dependencies** (strategic — order changes VALUE):
- If scorecard ships first → everything else is measurable → improvements compound (Pearson's Law)
- If eval infra ships first → all other work is measurable → improvements compound
- If onboarding ships first → demos can be LIVE because people are using it
- Same issues, different order → different total value
- This is what Stratus optimizes — not just "what's valid" but "what's OPTIMAL"

**Value score**: V (impact 1-5) × U (unlocks count) / C (cost in rounds)

For each issue, determine:
```
tenet_memory_search("dependency graph priority order")
tenet_policy_rank([
  { type: "feature", description: "Ship scorecard first", scope: "medium" },
  { type: "feature", description: "Ship onboarding first", scope: "medium" },
  { type: "feature", description: "Ship trust ladder first", scope: "medium" }
])
```

Write to `specs/dependency-graph-v2.md` with execution plan showing both types.

### Step C2: Pick Execution Order

Topological sort respecting graph deps, then optimize by path deps:
1. No unmet graph dependencies (hard constraint)
2. Highest path dependency value first (strategic)
3. Highest Value Score (V×U/C) as tiebreaker
4. Issues that UNLOCK the most others get priority
5. If Stratus predictions available (.tenet/predictions.jsonl), use predicted deltas

### Step D: Dispatch Agents (Forward Arm)

Fire each build agent in dependency graph order, highest value score first:

```bash
# From a pi session (LLM-callable)
delegate(build_agent: "marketplace-page", from_issue: 55)
delegate(build_agent: "trust-ladder", from_issue: 67)
delegate(build_agent: "scorecard", from_issue: 74)

# OR from shell (equivalent — the tool is a thin shellout)
cd <target-repo>
tenet build --run marketplace-page --from-issue 55
tenet build --run trust-ladder --from-issue 67
tenet build --run scorecard --from-issue 74
```

What you get:
- Issue linking (PR gets `Closes #N` via `--from-issue`)
- Journal entry on completion (peter.ts writes to build-journal.jsonl)
- Kanban board updates (via the `kanban` skill after PR opens)
- Single process per agent — clean PID attribution, easy to debug, killable
- Sequential execution by default (loop through the list)

For parallel dispatch (rare, requires explicit bash setsid + process group cleanup), see "Running Multiple Agents" section above.

### Step E: Score Results (Backward Arm)

When agents finish:
1. Check final scores from build logs
2. For converged (1.0): create PR, add eval results
3. For stalled (<1.0): search memory for WHY, update eval with new checks
4. Record: (agent, model, task_type, score, rounds, cost) for LLMRouter training

### Step F: Review + Learn

For each PR:
1. Sentinel reviews code
2. Codex reviews docs (if any docs changed)
3. Memory search: "has this pattern failed before?"
4. Extract learnings → write to journal
5. If PR is good → merge
6. If PR needs work → file new issue with specific failing checks

### Step G: Ceremony (Stratus Brain)

After each batch:
1. What shipped? Total value delivered
2. Predicted vs actual value for each issue
3. Epistemic scan: `tenet epistemics` — find blind spots
4. Recipe sharpening: update skills/recipes/evals based on learnings
5. Update dependency graph with new priorities
6. Plan next batch
7. Write comprehensive journal entry

### Step H: Repeat or Stop

If:
- More issues in backlog with ready agents → loop to Step D
- Budget remaining → continue
- Quality improved this cycle → continue
Otherwise: final summary, push, stop.

### The Full Loop

```
Scan backlog → Build graph → Pick order → Fire batch (forward arm)
→ Score results (backward arm) → Review + learn → Ceremony
→ Sharpen recipes → Update graph → Fire next batch → ...
```

Each cycle:
1. Ships code (the work)
2. Updates recipes (the improvement)  
3. Stores learnings in memory (the knowledge)
4. Adds new eval checks (the standards)
5. Trains model routing (the optimization)

The system doesn't just ship — it gets BETTER at shipping every cycle.
