# Claude review bot: stale thread acknowledgment

Status: **working (partial) solution in place** — the bot cannot yet make GitHub
show a thread as "Resolved" automatically. It can only detect that a previously
flagged issue is now fixed and say so in a plain PR comment. A human still has to
click "Resolve conversation" themselves. See "Future work" below for the likely
path to full automation.

## Original issue

`.github/workflows/claude-code-review.yml` runs Claude on every PR push
(`opened`/`synchronize`) to post inline review comments and submit
`--approve`/`--request-changes`. Each run was stateless: it only looked at the
current `gh pr diff` and never read back its own prior comments. Result: an
issue gets flagged, gets fixed in a later commit, and the original inline
comment thread just sits there forever — nothing ever went back to check it or
tell anyone it was fixed.

## Approach tried: dedicated bot account + PAT, calling `resolveReviewThread` directly

The first fix attempt tried to make the bot _actually_ resolve the GitHub
thread (the real "Resolved" UI state), via GitHub's GraphQL
`resolveReviewThread` mutation. Since the default Actions `GITHUB_TOKEN` can't
do this (see below), the plan was:

1. Create a dedicated bot/service GitHub account (not a personal account) as a
   collaborator on the repo.
2. Generate a fine-grained PAT for that account, scoped to just this repo,
   with "Pull requests: Read and write".
3. Store it as the `PR_RESOLVE_BOT_TOKEN` repo secret.
4. Have the agent call `resolveReviewThread` using that token for threads it
   judged fixed.

**This bot account and PAT already exist** (`PR_RESOLVE_BOT_TOKEN` secret) and
can be reused if the future-work path below is picked up again.

### Why it failed — three separate, hard walls

1. **Fine-grained PATs don't support `resolveReviewThread` at all.** Confirmed
   live: `FORBIDDEN: Resource not accessible by personal access token`, even
   with the correct "Pull requests: Read and write" permission granted and
   verified working for reads. This is a known gap in fine-grained PAT
   coverage of certain GraphQL mutations — not something fixable by picking a
   different permission checkbox.

2. **Getting the token into the agent's own shell at all was its own fight,**
   independent of (1):
   - A step-level `env:` block on the `claude-code-action` step sets the
     GitHub Actions _step's_ process environment, but that doesn't reliably
     reach Claude Code's own Bash tool subprocess.
   - The documented `settings.env` input (meant for exactly this) also didn't
     work.
   - Root cause: Claude Code has a **secret-scrubbing guardrail** — it strips
     secret-looking values from the Bash tool's subprocess environment
     specifically so a hostile PR diff can't trick the reviewer into leaking a
     credential it holds. This is a deliberate security feature (this bot's
     whole job is reading attacker-influenceable PR content), not a bug, and
     should not be disabled.

3. **Once the mutation call could actually run** (after restructuring so a
   separate, non-agent shell step held the token instead of the LLM), it hit
   a **login-format mismatch** (GraphQL reports the bot as `"github-actions"`,
   REST reports `"github-actions[bot]"` — a real gotcha worth remembering for
   any future GraphQL/REST author-matching code), and after fixing that, hit
   wall #1 above anyway.

## Approach tried: `addPullRequestReviewComment` (reply) via GraphQL, default token

After abandoning the PAT/resolve approach, the next attempt had the agent
_reply_ on the stale thread (not resolve it) using GraphQL's
`addPullRequestReviewComment` mutation with `inReplyTo`, using the default
`GITHUB_TOKEN` (no PAT needed for a reply, in theory).

**Why it failed:** also `FORBIDDEN`, live-confirmed:
`github-actions[bot] does not have the correct permissions`, despite
`pull-requests: write` being granted. PR-review GraphQL mutations are broadly
blocked for GitHub App-style tokens — and the Actions `GITHUB_TOKEN` **is**
one under the hood. This is a platform-level restriction, not a permissions
misconfiguration.

## Approach tried: REST reply endpoint, default token

REST was the obvious next candidate, since the _inline comments_ the bot posts
during Step 2 have been working via REST with the default token the entire
time. The REST reply endpoint is
`POST /repos/{owner}/{repo}/pulls/{pr}/comments/{comment_id}/replies`.

**Why it failed — and this one is not a GitHub problem at all:** confirmed via
a full-output diagnostic run (`show_full_output: true`) that the call was
denied by **Claude Code's own Bash tool allowlist**, not GitHub:

```
"decision_reason": "This command requires approval"
"non_execution_kind": "user-rejected"
```

`claude_args`'s `--allowedTools "Bash(<prefix>:*)"` syntax matches **whole
shell tokens exactly** — e.g. `Bash(gh api graphql:*)` works because `graphql`
is its own complete token (a space follows it). But a REST URL like
`repos/OWNER/REPO/pulls/50/comments/3921353709/replies` is **one single
contiguous token** with no internal whitespace. Any prefix pattern ending
partway through that token (e.g. stopping at `.../pulls`) is a _substring_ of
the real token, not an _equal_ token — and substring prefixes don't match.
There is no way to write an allow-pattern admitting arbitrary comment IDs
embedded inside one unbroken token. This is a hard limitation of the
allowlist syntax, not something fixable by rephrasing the pattern.

## What we're using now

The agent (Step 1 in the workflow prompt) still re-checks every one of its own
open threads against the current diff and judges whether each is actually
fixed. But instead of trying to resolve or reply inside the thread, it posts
**one plain top-level PR comment** (`gh pr comment`, a fixed whole-token
command — same shape as the already-working `gh pr view`/`gh pr diff`/`gh pr
review`) summarizing every thread it verified as fixed, asking a human to
resolve those conversations if they agree. The overall
`--approve`/`--request-changes` verdict correctly treats a "fixed" thread as
not a blocking bug, and a still-open/genuinely-unfixed thread as one.

Net effect: no more silent, permanently-stale threads with zero indication
they're fixed — but resolving the actual GitHub thread UI is still a manual,
one-click human step.

## Future work

The most promising unexplored path: swap the existing fine-grained
`PR_RESOLVE_BOT_TOKEN` PAT for a **classic PAT** (`repo` scope) on the same
dedicated bot account, and reuse the split-architecture we already built (a
separate, non-agent `run:` step — not the LLM's own Bash tool — reads which
threads the agent judged fixed from a marker/comment, then calls
`resolveReviewThread` via `gh api graphql` with that token). Classic PATs are
reported to support `resolveReviewThread` where fine-grained PATs don't, and
routing the token through a plain shell step rather than the agent's own Bash
tool sidesteps both the secret-scrubbing guardrail and the allowlist
token-matching limitation, since neither applies to a deterministic,
non-agent workflow step. This wasn't retried after the pivot to `gh pr
comment`, purely due to time — worth a follow-up attempt.
