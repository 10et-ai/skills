---
name: code-quality
description: Run code quality agents across repos — decomposed evals for TypeScript strictness, security, dead code, async patterns, test coverage, and import hygiene. Generates PRs per repo.
disable-model-invocation: true
triggers:
  - code quality
  - quality sweep
  - /quality
  - code review
  - quality agent
  - quality check
  - pre-migration audit
  - clean up repos
  - tech debt
  - security scan
  - type errors
  - dead code
---

# /quality — Code Quality Agents with Decomposed Evals

Runs targeted improvement agents across repos. Each quality dimension is an **improve agent** with decomposed binary checks — same convergence guarantees as build agents.

> "Code quality is an improve problem, not a build problem."
> The eval checks existing code for correct patterns — not whether files exist.
> Binary checks per anti-pattern → agent sees exactly what to fix → PR per repo.

---

## ⛔ PHASE 0 — READ BEFORE ANYTHING (HARD GATE)

```
1. tenet_context("code quality tech debt")          — find prior quality runs
2. tenet_memory_search("quality scan results")      — find known issues
3. gh issue list --label quality,tech-debt          — avoid duplicate issues
4. cat EXPERIMENTS.md                               — read current baseline score
5. ls eval/quality/ .tenet/agents/quality-*         — inventory existing evals
```

Do NOT launch agents if a quality eval already scored > 0.85 on this repo this week.
Check the history first — agents cost real money and time.

---

## ⛔ MANDATORY CHECKPOINT before creating PRs

Show user: per-repo score table + failing checks + severity breakdown.
Ask: "Here are the quality scores and failing checks. OK to create PRs?"
**Do NOT open PRs without explicit yes.**

---

## Quality Dimensions (Each Becomes Its Own Eval Category)

Code quality decomposes into six independently measurable dimensions. Each dimension maps to one eval file and one agent. Run them independently — they don't share scope.

| Dimension | Metric | High-value checks |
|-----------|--------|-------------------|
| **TypeScript Strictness** | % files with zero `any` | no `: any`, no `as any`, return types present |
| **Security** | % files with no OWASP patterns | no `eval()`, no shell injection, no hardcoded secrets |
| **Dead Code** | % exports that are referenced | no unused imports, no unreachable blocks |
| **Async Hygiene** | % async ops that are non-blocking | no `execSync`/`readFileSync` in hot paths |
| **Error Handling** | % catch blocks that handle errors | no empty `catch {}`, no swallowed rejections |
| **Test Coverage** | % source files with co-located tests | test file exists, has describe/it/expect |

---

## The Core Pattern

Quality agents are **improve agents** — they check existing code for correct patterns.
The eval hierarchy is slightly different from build agents:

| Level | What | Example |
|-------|------|---------|
| 1. Count | How many files have the anti-pattern? | `files.filter(f => f.includes(': any')).length` |
| 2. Ratio | What fraction pass the check? | `passing / total` |
| 3. Severity | Are CRITICAL issues present? | `hasEval || hasHardcodedSecret` |
| 4. Trend | Did we improve vs baseline? | `score > baseline` |

**Key difference from build evals:** Quality evals scan multiple files, not one specific file. Use `readdirSync` + `readFileSync` across the scope directory.

---

## Eval Template — Per-Dimension

Every quality eval follows this exact structure:

```typescript
/**
 * [Dimension] Quality Eval — [Repo Name]
 * @purpose Detect [anti-pattern] across src/ and return ratio of passing files
 */
import { existsSync, readFileSync, readdirSync, statSync } from "fs"
import { join, extname } from "path"
import { execSync } from "child_process"

const ROOT = process.env.AGENT_WORKTREE || process.cwd()

function allTsFiles(dir: string): string[] {
  if (!existsSync(dir)) return []
  const results: string[] = []
  for (const f of readdirSync(dir)) {
    const full = join(dir, f)
    if (statSync(full).isDirectory() && !f.includes('node_modules') && !f.includes('dist') && !f.includes('__tests__')) {
      results.push(...allTsFiles(full))
    } else if (['.ts', '.tsx'].includes(extname(f)) && !f.endsWith('.d.ts')) {
      results.push(full)
    }
  }
  return results
}

export async function evaluate(_dataPath: string): Promise<number> {
  const srcDir = join(ROOT, "src")
  const files = allTsFiles(srcDir)

  if (files.length === 0) {
    console.error("[eval] no source files found")
    return 0
  }

  const checks: Array<{ name: string; pass: boolean }> = []

  for (const file of files) {
    const rel = file.replace(ROOT + "/", "")
    const content = readFileSync(file, "utf-8")

    // --- REPLACE WITH YOUR DIMENSION CHECKS ---
    checks.push({ name: `${rel}:no-any`, pass: !content.includes(": any") && !content.includes("as any") })
    checks.push({ name: `${rel}:no-implicit-any`, pass: !content.match(/\(\s*\w+\s*,\s*\w+\s*\)/) || content.includes(": ") })
    // --- END DIMENSION CHECKS ---
  }

  // CRITICAL: always include a compile check
  let compiles = true
  try { execSync("npx tsc --noEmit", { cwd: ROOT, stdio: "ignore" }) }
  catch { compiles = false }
  checks.push({ name: "tsc-passes", pass: compiles })

  const passed = checks.filter(c => c.pass).length
  const total = checks.length
  const failed = checks.filter(c => !c.pass).map(c => c.name)

  console.error(`[eval] ${passed}/${total}: ${failed.length ? 'failed: ' + failed.slice(0, 5).join(', ') + (failed.length > 5 ? ` (+${failed.length - 5} more)` : '') : 'all passing'}`)

  if (failed.length > 0) {
    process.stdout.write(JSON.stringify({ failed_checks: failed.slice(0, 20), score: passed / total }) + '\n')
  }

  return passed / total
}
```

---

## Dimension Evals — Ready to Use

### 1. TypeScript Strictness

```typescript
// Per-file checks
checks.push({ name: `${rel}:no-any`,            pass: !content.includes(": any") && !content.includes("as any") })
checks.push({ name: `${rel}:no-ts-ignore`,       pass: !content.includes("@ts-ignore") && !content.includes("@ts-nocheck") })
checks.push({ name: `${rel}:explicit-return`,    pass: !content.match(/^export (async )?function \w+\([^)]*\)\s*\{/m) || content.match(/\): \w/) !== null })
checks.push({ name: `${rel}:no-bang-assertion`,  pass: (content.match(/!/g) || []).length < 5 }) // few non-null assertions
```

### 2. Security

```typescript
// CRITICAL: any of these make the whole eval score 0
const hasCritical =
  content.includes("eval(")                                    // code eval
  || content.match(/execSync\([^)]*\$\{/) !== null             // shell injection via template literal
  || content.match(/password\s*[:=]\s*["'][^"']{3,}/) !== null // hardcoded credential
  || content.match(/secret\s*[:=]\s*["'][^"']{3,}/) !== null   // hardcoded secret
  || content.match(/token\s*[:=]\s*["'][a-zA-Z0-9_-]{20,}/) !== null  // hardcoded token

checks.push({ name: `${rel}:no-critical-security`, pass: !hasCritical })

// HIGH severity
checks.push({ name: `${rel}:no-sql-concat`,      pass: !content.match(/["'`]\s*SELECT.*\+\s*\w/) })
checks.push({ name: `${rel}:errors-not-exposed`,  pass: !content.match(/res\.(json|send)\(\s*\{[^}]*error\s*:\s*\w+\.message/) })
```

### 3. Dead Code

```typescript
// Unused imports (basic heuristic)
const importLines = content.match(/^import .+ from .+$/gm) || []
for (const imp of importLines) {
  const name = imp.match(/import\s+(\w+)/)?.[1] || imp.match(/import\s*\{([^}]+)\}/)?.[1]?.trim()
  if (name && !content.slice(content.indexOf(imp) + imp.length).includes(name)) {
    checks.push({ name: `${rel}:no-unused-import:${name}`, pass: false })
  }
}

// TODO/FIXME comments left in (treat as debt, not blocking)
const todos = (content.match(/\/\/\s*(TODO|FIXME|HACK|XXX)/g) || []).length
checks.push({ name: `${rel}:no-todo-debt`, pass: todos === 0 })

// Commented-out code blocks (3+ consecutive comment lines)
checks.push({ name: `${rel}:no-commented-code`, pass: !content.match(/(\/\/.*\n){4,}/) })
```

### 4. Async Hygiene (Hot Path Check)

```typescript
// execSync/readFileSync in non-startup code = blocks event loop
// Only flag if it's in a function (not top-level init)
const inFunction = content.match(/function\s+\w+[^{]*\{[^}]*readFileSync[^}]*\}/ms)
checks.push({ name: `${rel}:no-sync-in-function`, pass: !inFunction })

const syncGit = content.match(/execSync.*git/)
checks.push({ name: `${rel}:no-sync-git`, pass: !syncGit })

// Unhandled promise rejections
checks.push({ name: `${rel}:no-floating-promise`, pass: !content.match(/^\s+\w+\([^)]*\)\.then\(/m) || content.includes('.catch(') })
```

### 5. Error Handling

```typescript
// Empty catch blocks
checks.push({ name: `${rel}:no-empty-catch`,     pass: !content.match(/catch\s*\([^)]*\)\s*\{\s*\}/) })

// Swallowed errors (catch with only comment)
checks.push({ name: `${rel}:catch-not-swallowed`, pass: !content.match(/catch\s*\([^)]*\)\s*\{\s*\/\/[^\n]*\n\s*\}/) })

// Error logged at minimum
const hasCatch = content.includes("catch")
const hasLogging = content.includes("console.error") || content.includes("logger.error") || content.includes("log.error")
if (hasCatch) checks.push({ name: `${rel}:errors-logged`, pass: hasLogging })
```

### 6. Test Coverage

```typescript
// Check if source file has a co-located test
const testPath = file.replace("/src/", "/src/").replace(/\.ts$/, ".test.ts")
const altTestPath = file.replace("src/", "src/__tests__/").replace(/\.ts$/, ".test.ts")
const hasTest = existsSync(testPath) || existsSync(altTestPath)

// Exclude index files, type files, config files from test requirement
const needsTest = !rel.includes("index.ts") && !rel.includes(".d.ts") && !rel.includes("config") && !rel.includes("types")
if (needsTest) checks.push({ name: `${rel}:has-test`, pass: hasTest })
```

---

## Agent TOML — Code Quality

```toml
[agent]
name = "quality-typescript-strictness"
scope = "improve"
metric = "quality_score"
direction = "maximize"
time_budget_seconds = 900
rounds = 5
target_repo = "."

[eval]
script = "eval/quality/typescript-strictness.ts"

[task]
description = "Remove all ': any' and 'as any' type assertions. Add explicit return types to all exported functions. Remove @ts-ignore comments. Fix without breaking tests or compilation."

[constraints]
scope_files = ["src/**/*.ts"]
max_file_changes = 10
readonly = ["eval/**", "EXPERIMENTS.md", "package.json"]
```

---

## Multi-Repo Sweep

To run quality agents across multiple repos before a Visa org migration:

```bash
#!/bin/bash
# Run quality sweep across all target repos
REPOS=(
  "/path/to/jfl-cli"
  "/path/to/visa-cli"
  "/path/to/402_cat_rust"
  "/path/to/jfl-platform"
)

DIMENSIONS=(
  "typescript-strictness"
  "security"
  "async-hygiene"
  "error-handling"
)

for repo in "${REPOS[@]}"; do
  repo_name=$(basename "$repo")
  echo "=== Scanning $repo_name ==="

  for dim in "${DIMENSIONS[@]}"; do
    # Run baseline eval first
    baseline=$(cd "$repo" && AGENT_WORKTREE="$repo" npx tsx eval/quality/$dim.ts 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('score',0))" 2>/dev/null || echo "0")
    echo "$repo_name/$dim baseline: $baseline"

    # Only launch agent if score < 0.85
    if python3 -c "exit(0 if float('$baseline') < 0.85 else 1)" 2>/dev/null; then
      cd "$repo" && tenet peter agent quality-$dim --rounds 3
    fi
  done
done
```

### Baseline Scan Without Agents

Run a read-only quality scan to get scores before deciding whether to launch agents:

```bash
# Get quality score per dimension per repo without running any agents
for dim in typescript-strictness security async-hygiene error-handling; do
  score=$(AGENT_WORKTREE=. npx tsx eval/quality/$dim.ts 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin).get('score','?'))" 2>/dev/null)
  printf "%-35s %s\n" "$dim" "$score"
done
```

---

## Severity Model

Not all failing checks are equal. Use this model to prioritize:

| Severity | Pattern | Action |
|----------|---------|--------|
| **CRITICAL** | Hardcoded secret, eval(), SQL injection, shell injection via template literal | Block PR, fix immediately |
| **HIGH** | Empty catch blocks, `: any` in API surface, no return types on exports | Agent PR required |
| **MEDIUM** | TODO/FIXME debt, sync ops in functions, missing test files | Agent PR if time allows |
| **LOW** | @ts-ignore, commented code, non-null assertions | Batch into cleanup PR |

```typescript
// In eval — score 0 on any CRITICAL finding
if (criticalIssues.length > 0) {
  console.error(`[eval] CRITICAL: ${criticalIssues.join(', ')}`)
  return 0  // Hard fail — agent must fix before anything else
}
```

---

## Pre-Migration Checklist (Visa Org)

Before migrating repos into an enterprise org, every repo should pass:

```
[ ] security eval > 0.95    (no CRITICAL findings)
[ ] typescript-strictness > 0.80
[ ] error-handling > 0.85
[ ] async-hygiene > 0.80    (no blocking sync in hot paths)
[ ] tsc --noEmit: passes clean
[ ] npm test: passing (≥ 95% of suites)
[ ] no hardcoded keys/tokens in git history (use git-secrets scan)
[ ] package.json: no critical CVEs (npm audit --audit-level=critical)
```

Run the full pre-migration check:

```bash
tenet quality check --pre-migration --repos jfl-cli,visa-cli,jfl-platform
```

---

## Common Failures

| Failure | Root Cause | Fix |
|---------|-----------|-----|
| Score 0.0 on first run | Eval scanning dist/ not src/ | Filter out `node_modules`, `dist`, `.d.ts` files |
| All files fail `:no-any` | Third-party type gaps, not your code | Scope to `src/` only, exclude `types/` declarations |
| Security eval false positives | Template literal pattern too broad | Tighten regex to only flag `execSync(\`${` patterns |
| Agent improves score but tsc fails | Agent removed `any` without fixing types | Always include compile check — enforce it gating return |
| Score regresses between runs | Imports added `: any` again | Add pre-commit hook: `npx tsc --noEmit --strict` |
| Multi-repo sweep hangs | Agents run in series, one stalls | Use `--timeout 600` flag, kill and skip on timeout |

---

## Connecting to the RL Loop

Quality evals feed the same training loop as build evals:

```typescript
// Eval output format — supervisor reads this to generate the hint
{
  "failed_checks": ["src/lib/hub-client.ts:no-any", "src/commands/pivot.ts:no-sync-git"],
  "score": 0.73,
  "severity": "HIGH"
}
```

The supervisor sees exactly which files have which anti-patterns and injects that into the agent's hint. The agent makes ONE targeted fix, eval re-runs, score updates. 1-3 rounds to clean file, same as a build agent.

---

## Learnings from Past Runs

These patterns emerged from reviewing merged quality PRs and rejected experiments:

**What converges fast (1 round):**
- Removing unused imports — clear, mechanical, grep-findable
- Adding `await` to floating promises — compiler error guides the agent
- Replacing `execSync("git ...")` with `simpleGit()` — one import, one call pattern

**What stalls (3+ rounds):**
- "Add return types to all functions" — too broad, agent touches too many files
- "Fix all TypeScript errors" — agent doesn't know which errors to fix first

**Fix: always decompose to file-level checks, never repo-level.**
`src/lib/hub-client.ts:no-any` → fast convergence.
`all files must have no any` → stalls.

**The decomposition law applies to quality just as much as to features.**
