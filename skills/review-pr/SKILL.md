---
name: review-pr
version: 1.0.0
description: Triage review comments on Claude-authored PRs (fix/falsify/acknowledge + resolve threads), or post a full code review on incoming PRs
metadata:
  tags: github, pr, review, code-review, git
---

# review-pr

Handles two modes depending on who opened the PR:

- **Our PR** (Claude-authored): resolve merge conflicts if present, then read every unresolved review thread, reply with a decision (fix / falsify / acknowledge), implement any fixes, push, then resolve the thread.
- **Incoming PR** (someone else's): read the diff and post a structured code review.

## Usage

```
/review-pr          — use the most recent PR we opened
/review-pr <id>     — target a specific PR number
```

---

## Step 0 — Resolve the PR number

If `<id>` was provided, use it directly.

Otherwise find the most recent PR opened by us:

```bash
gh pr list --author "@me" --state open --limit 1 --json number --jq '.[0].number'
```

If nothing is returned, try `--state all` to catch recently merged/closed PRs.

Store the result as `PR_NUMBER`. If still nothing, tell the user and stop.

---

## Step 1 — Determine ownership

Fetch the PR metadata:

```bash
gh pr view $PR_NUMBER --json body,headRefName,author --jq '{body: .body, branch: .headRefName, author: .author.login}'
```

**The PR is "ours"** if ANY of the following are true:

- The body contains `Generated with [Claude Code]`
- The author login is `app/github-actions` (automated promotion PRs)
- Any commit on the branch has `Co-Authored-By: Claude` in its message:

```bash
gh pr view $PR_NUMBER --json commits --jq '.commits[].messageBody' | grep -i "Co-Authored-By: Claude"
```

If any check matches → **Our PR flow** (Step 2).
Otherwise → **Incoming PR flow** (Step 6).

Also store `HEAD_BRANCH` from the PR metadata — you'll need it to push fixes.

---

## Step 2 — Our PR: resolve merge conflicts (if any)

Check merge status:

```bash
gh pr view $PR_NUMBER --json mergeable,mergeStateStatus --jq '{mergeable: .mergeable, state: .mergeStateStatus}'
```

If `mergeable` is `CONFLICTING`:

1. Ensure you're on the PR branch:

```bash
git fetch origin
git checkout $HEAD_BRANCH || git checkout -b $HEAD_BRANCH origin/$HEAD_BRANCH
```

2. Determine the base branch:

```bash
BASE_BRANCH=$(gh pr view $PR_NUMBER --json baseRefName --jq '.baseRefName')
git fetch origin $BASE_BRANCH
```

3. Attempt the merge:

```bash
git merge origin/$BASE_BRANCH --no-edit
```

4. If the merge exits cleanly → no conflicts, skip ahead.

5. If there are conflicts, list the conflicted files:

```bash
git diff --name-only --diff-filter=U
```

6. For each conflicted file, use the Read tool to view it. Conflict markers look like:

```
<<<<<<< HEAD
  (our version — PR branch)
=======
  (their version — base branch)
>>>>>>> origin/<base>
```

Resolve each conflict:
- **Prefer our changes** when the base branch change is unrelated to what the PR is doing.
- **Prefer base changes** when the PR only touched unrelated lines and the base has the correct update.
- **Merge both** when both sets of changes are independently valid (e.g. both added new exports, routes, or entries to an array/object).
- **For append-only files** (JSONL logs, changelogs, lock files): keep all lines from both sides, strip the conflict markers.
- If the conflict is ambiguous and you cannot safely resolve it without breaking either change, pause and explain the conflict to the user before proceeding.

After editing, stage the resolved files:

```bash
git add <resolved-file> ...
```

7. Complete the merge:

```bash
git commit -m "$(cat <<'EOF'
chore: merge $BASE_BRANCH into $HEAD_BRANCH — resolve conflicts

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

8. Push:

```bash
git push origin $HEAD_BRANCH
```

9. Verify the PR is no longer conflicting:

```bash
gh pr view $PR_NUMBER --json mergeable --jq '.mergeable'
```

Should now return `MERGEABLE`. If still `CONFLICTING`, re-examine — don't loop more than once.

If `mergeable` was already `MERGEABLE` or `UNKNOWN` (GitHub hasn't computed it yet), skip this step entirely.

---

## Step 2.5 — Our PR: check CI status

Get the PR's check status:

```bash
gh pr checks $PR_NUMBER --json name,state,conclusion --jq '.[] | {name, state, conclusion}'
```

If all checks are `success` or `skipped`, proceed to Step 3.

If any check is `failure` or `pending`:

**For failures:** identify which checks failed, then fetch the logs:

```bash
# Get the most recent failed run ID for this branch
gh run list --branch $HEAD_BRANCH --status failure --limit 3 --json databaseId,name,conclusion,headSha

# View logs for a specific failed run
gh run view <run-id> --log-failed 2>&1 | head -200
```

Read the failure output carefully. Common failure types and how to handle each:

- **TypeScript / compile errors** — read the relevant source files, fix the type errors, commit, push
- **Test failures** — run the failing tests locally if possible (e.g. `cd <package> && pnpm test`), read the test file and source, fix the underlying code or test, commit, push
- **Lint errors** — read the ESLint output, fix the flagged lines, commit, push
- **Build errors** — read the build output, trace the error to source, fix, commit, push

After pushing a fix, re-check CI:

```bash
gh pr checks $PR_NUMBER --watch --interval 30
```

Wait for the run to complete. If still failing, re-read the logs and fix again. Do not loop more than **3 fix attempts** — if CI is still failing after 3 pushes, stop and explain the remaining failures to the user.

**For pending checks:** if checks are still queued or running, wait up to 2 minutes:

```bash
gh pr checks $PR_NUMBER --watch --interval 30
```

If still pending after 2 minutes, proceed to Step 3 anyway and note the pending status in the final report.

---

## Step 3 — Our PR: fetch all review threads (GraphQL)


Use `gh api graphql` to get every thread with its resolution state, comments, and file location:

```bash
gh api graphql -f query='
query($owner: String!, $repo: String!, $number: Int!) {
  repository(owner: $owner, name: $repo) {
    pullRequest(number: $number) {
      reviewThreads(first: 100) {
        nodes {
          id
          isResolved
          path
          line
          comments(first: 20) {
            nodes {
              databaseId
              body
              author { login }
              createdAt
            }
          }
        }
      }
    }
  }
}' -f owner=OWNER -f repo=REPO -F number=$PR_NUMBER
```

Replace `OWNER` and `REPO` from the current repo: `gh repo view --json owner,name --jq '"owner=\(.owner.login) repo=\(.name)"'`

Filter to threads where `isResolved == false`. If all threads are already resolved, tell the user and stop.

---

## Step 4 — Our PR: triage each unresolved thread

For each unresolved thread, read ALL comments in the thread. Then decide:

### Decision logic

**FIX** — The comment points out a real bug, mistake, missing case, security issue, or clear improvement that is consistent with the PR's intent. The fix is unambiguous.

**FALSIFY** — The comment is based on a misunderstanding, incorrect assumption, or asks for something out of scope. Explain why the current code is correct.

**ACKNOWLEDGE** — The comment raises a valid point but is a style preference, a future concern, or something deliberately deferred. Accept it without changing code.

---

### For each thread:

#### If FIX:
1. Implement the fix in the local working copy (checkout the branch first if not already on it: `git fetch origin && git checkout $HEAD_BRANCH`).
2. Use Edit/Write to make the change — keep it minimal, only address the comment.
3. Commit with message: `fix: address review comment on <path>:<line>` + `Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>`
4. Push: `git push origin $HEAD_BRANCH`
5. Reply to the thread via REST:

```bash
gh api repos/{owner}/{repo}/pulls/$PR_NUMBER/comments \
  --method POST \
  -f body="Fixed — <one sentence describing what changed>." \
  -F in_reply_to=FIRST_COMMENT_DATABASE_ID
```

6. Resolve the thread via GraphQL:

```bash
gh api graphql -f query='
mutation($id: ID!) {
  resolveReviewThread(input: { threadId: $id }) {
    thread { id isResolved }
  }
}' -f id=THREAD_GRAPHQL_ID
```

#### If FALSIFY:
1. Reply explaining why the current code is correct. Be direct and specific. Reference line numbers or types if helpful.
2. Resolve the thread (same GraphQL mutation as above).
3. No code change.

#### If ACKNOWLEDGE:
1. Reply accepting the point, optionally noting it as a future improvement or explaining the tradeoff.
2. Resolve the thread.
3. No code change.

---

## Step 5 — Our PR: report

After processing all threads, output a summary table:

```
PR #N — <title>

CI: ✅ all checks passed  (or ⚠️ N checks pending / ❌ N checks failed — list them)

Thread triage:
  path/to/file.ts:42   FIX          Removed unused import
  path/to/other.ts:10  FALSIFY      Type assertion is intentional — upstream returns `any`
  README.md            ACKNOWLEDGE  Good call, tracked as future cleanup

Commits pushed: N
Threads resolved: N / N
```

---

## Step 6 — Incoming PR: post a code review

Fetch the diff and PR context:

```bash
gh pr view $PR_NUMBER --json title,body,author,headRefName,baseRefName
gh pr diff $PR_NUMBER
```

Also list changed files:

```bash
gh pr view $PR_NUMBER --json files --jq '.files[].path'
```

Read each changed file using the Read tool to get full context (not just diff lines).

### Review structure

Post the review using:

```bash
gh pr review $PR_NUMBER --comment --body "$(cat <<'REVIEW'
<review body>
REVIEW
)"
```

Before writing the review, check CI:

```bash
gh pr checks $PR_NUMBER --json name,state,conclusion
```

The review body should cover:

**CI status** — One line: all passing, N failing (list names), or pending.

**Summary** — 2–3 sentences on what the PR does and overall assessment (approve / request changes / comment).

**Per-file findings** — For each file with meaningful changes:
- What changed
- Any bugs, edge cases, security issues, or type errors
- Style or architecture concerns (only if significant)

**Verdict** — One of:
- `LGTM` — looks good, can merge
- `NITPICK` — minor issues, author's call
- `REQUEST CHANGES` — specific blocking issues listed

Keep the review concise. Flag real issues, not style preferences. Don't comment on things that are fine.

If the PR is trivial (< 20 lines changed, single fix), a one-paragraph review is sufficient.

---

## Notes

- Always check `isResolved` before touching a thread — don't re-resolve already-resolved threads.
- If `git checkout $HEAD_BRANCH` fails (branch not local), do `git fetch origin $HEAD_BRANCH && git checkout $HEAD_BRANCH`.
- If multiple FIX commits are needed, batch them into one push after all edits are done.
- If a thread has replies from the PR author (not us), read those replies too before deciding — they may have already addressed the concern.
- The GraphQL `resolveReviewThread` mutation requires the thread's node ID (the `id` field in the GraphQL response), not the REST `databaseId`.
