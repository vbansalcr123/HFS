---
name: hfs-pr-review
description: Review a Salesforce Apex/LWC pull request in the HFS project for functional correctness — whether the code will actually work at runtime — not style, naming, or security (PMD/Salesforce Code Analyzer and ESLint already run in CI and cover that ground). Use whenever asked to review a PR, act as the AI-review-first gate before human review, or check whether a PR's logic actually holds up. Invoked as /hfs-pr-review <PR-number>.
---

# HFS PR Correctness Review

## Scope — read this first

This project already runs PMD (`bestpractices`, `security`) and ESLint on every PR (`CI-CD-Pipeline-HFS-V1.docx`, Section 15). **Do not re-flag:**
- Missing `hfs_` prefixes, naming drift, formatting
- Generic security/best-practice lint rules (CRUD/FLS mechanics, unused vars, empty catch blocks)
- Anything PMD or ESLint would already catch

This skill has exactly one job: **will this code behave correctly**, given the project's specific fflib architecture and conventions (`Apex-LWC-Development-Standards-HFS-V1.md`). If an issue is a style opinion rather than a genuine logic/functional bug, leave it out.

**Filter before flagging anything:** *if this shipped as-is, would a real user or the next commit hit a wrong result, an exception, or silently-lost/incorrect data?* If yes, it's in scope. If the honest answer is "it would work, just not how I'd have written it," it's not.

## Modes

This skill runs from two different places, sharing one checklist:

- **PR mode** — invoked as `/hfs-pr-review <PR-number>` by the GitHub Action on every PR push. Reviews the full PR diff and posts a formal GitHub review.
- **Local mode** — invoked as `/hfs-pr-review local` by the shared `pre-push` git hook, or manually by a developer. Reviews `git diff origin/develop...HEAD` (everything about to be pushed) and prints findings to the terminal — there's no PR yet, so nothing gets posted anywhere.

## Process

1. **PR mode:** `gh pr view <PR> --json title,body,files` and `gh pr diff <PR>` to get the changed files and diff.
   **Local mode:** `git diff origin/develop...HEAD` (or `git diff develop...HEAD` if there's no `origin` remote configured under that name) to get the same information without a PR.
2. Classify each changed file by layer from its name (Selector / Domain / Service / Controller / Trigger / TriggerHandler / Queueable / Batch / Client / LWC / Test — Section 3 naming conventions).
3. For files where the diff alone doesn't show enough (e.g. you need the rest of a method, or the SObject's real field list), check out the branch (`gh pr checkout <PR>` in PR mode; already on the branch in local mode) and read the full file — don't guess from a partial hunk.
4. Apply the layer-specific checks below.
5. Post the verdict per "Posting the review" — PR mode posts a GitHub review; local mode prints a plain-text summary to stdout and exits non-zero if it found a genuine issue (so the calling `pre-push` hook can block the push), zero otherwise.

## Layer-specific correctness checks

### Application wiring (`Application.cls`)
- Anything `new`-ing a Selector/Domain/Service implementation directly instead of going through `Application.Selector/Domain/Service.newInstance(...)` isn't just an architecture preference — it silently breaks `Application.*.setMock(...)` substitution, so Tier 2 tests that think they're mocking a dependency are actually hitting the real one (or the real one is never reachable and the code NPEs). Treat this as a functional bug, not a style note.

### Selector
- Every bind token in `whereClause` (`:paramName`) has a matching key in `bindMap` — a mismatch is a runtime `System.QueryException`, not a compile error.
- No literal value concatenated into `whereClause` while relying on `bindMap` for something else — a partial-bind bug is a correctness issue, not just an injection risk.
- The `fieldsToGet` fallback still produces a valid, queryable field list.

### Domain
- Generic `create{Objects}Records` / `update{Objects}Records`: the `Map<String, Object>` keys must be real API names on the target SObject. A typo compiles fine and fails — or silently no-ops — only at runtime. Cross-check against fields visible elsewhere in the diff or the object's schema.
- Never calls `commitWork()` — only registers against the passed-in `fflib_ISObjectUnitOfWork`.
- Check the actual comparison/boundary logic in validation and defaulting (`<` vs `<=`, wrong field referenced, off-by-one) — not just that a check exists.

### Service
- Exactly one `commitWork()` per use case, and it's the outermost call — never inside a sub-Service or a Domain method.
- Nothing that can throw happens after `commitWork()` — a failure there would leave a partial commit uncaught.
- Exceptions thrown are typed (`hfs_ApplicationException` subclasses) with a real `errorCode` set via `.withErrorCode(...)`. A bare `throw new Exception(...)` or an unwrapped platform exception here degrades into `hfs_Response.error(Exception e)`'s generic "something went wrong" branch at the Controller — a real loss of error information, not a nitpick.
- External-system calls go through the dedicated client class, not inline `Http` calls in the Service.

### Controller
- Every code path returns `hfs_Response` — check for a branch that could fall through without a return, or a spot where an exception could still escape the try/catch.
- `hfs_Guard` checks run *before* any real work, not interleaved after side effects have already started.
- `cacheable=true` only on methods with no side effects.
- `payload` is a DTO — a raw SObject leaking into `hfs_Response.success(...)` is a functional problem (exposes fields the LWC/user shouldn't see, and can break serialization expectations downstream).
- For a DTO with nested objects/maps: flag it for a second look — `hfs_Response.payload` typed as `Object` is documented as unproven for deeply nested or `Map`-heavy payloads (standards doc Section 17). Don't assume it "just serializes fine."

### Trigger / TriggerHandler
- The handler delegates only to `fflib_SObjectDomain.triggerHandler(...)` plus bypass/recursion guards. Any real business logic sitting in the handler is a functional risk, not just a layering violation — it can behave differently than Domain-routed logic (e.g. for API-driven DML paths that assume trigger-context conventions).

### Async (Queueable / Batch / Scheduled)
- Has its own top-level try/catch — there's no Controller downstream, so an uncaught exception here fails silently except for Salesforce's default Apex Exception Email.
- Logs via `Logger.error(...)` + `Logger.saveLog()` before rethrowing, if it rethrows.
- `Database.AllowsCallouts` present if it makes callouts.
- If it re-queues itself on failure, check there's an attempt cap / backoff — an unbounded retry is a real bug, not a style note.

### External client (`hfs_*Client`, e.g. Shopify)
- Catches transport-level failures and rethrows a typed business exception. Check it's actually catching the right thing — conflating a timeout with a non-2xx response, or catching too broadly, can silently swallow a real integration failure instead of surfacing it.
- **Bulk/partial-success sync logic:** `hfs_Response`'s `isSuccess` is binary (Section 17 — no `hfs_BatchResponse` shape exists yet). If a PR introduces bulk Shopify (or similar) sync where some records can succeed and others fail in the same call, check whether the code is reporting an all-or-nothing result when the reality is mixed — that's a functional misrepresentation of what happened, worth flagging even though it's "by design" per the current docs.

### LWC
- Checks `response.isSuccess` / `data.isSuccess` before touching `payload` — code that treats a resolved Promise or a present `@wire` `data` as success will treat business-level failures as successes (this is the documented `hfs_Response` `@wire` caveat, Section 12.1).
- No direct Selector/Service calls from a component — only through the Controller.

### Tests
- Tier 1 (real-DML test): actually uses 200+ records, actually wraps the core assertion in `System.runAs()` with a restricted-permission user — check it's doing this, not just present in name.
- Assertions check the real outcome (`System.Assert.areEqual(expected, actual, 'message')`), not just "no exception was thrown."
- Tier 2 mocks: `mocks.verify(...)` is present for the interaction actually under test. Stubbing without verifying proves nothing about behavior.
- A test that's clearly written to satisfy the coverage gate without asserting real behavior is a functional gap in the safety net — flag it even though it "looks like" a test file, not a logic file.

## Posting the review

**PR mode** — first check whether this bot account already has an outstanding review on this PR — `gh pr view <PR> --json reviews` and look for a prior `CHANGES_REQUESTED` review from this same bot login (confirm the exact login once against a real PR; the Claude GitHub App typically shows up as `claude` or `claude[bot]`).

- **Found one or more genuine functional/logic issues this pass:**
  `gh pr review <PR> --request-changes --body "<one item per issue: file:line, what would go wrong, suggested fix>"`
  This blocks merge on its own — independent of the branch-protection approval count — until this same bot account approves a later pass, or a human with dismiss permission dismisses the stale review.

- **Nothing functional turned up, and there's no prior outstanding Request-Changes from this bot:**
  `gh pr review <PR> --comment --body "No functional/logic issues found in this pass. (Style, naming, and security are handled separately by PMD/ESLint.)"`
  Deliberately a comment, not an approval — this keeps a clean first pass from quietly satisfying the required-approval count on its own, so the human review stays load-bearing.

- **Nothing functional turned up, but a prior Request-Changes from this bot is still outstanding:**
  `gh pr review <PR> --approve --body "Functional issues from the earlier review appear resolved — clearing that gate. This means 'no bugs found,' not a merge sign-off; human review is still required."`
  GitHub only lets the *same* reviewer clear their own Request Changes — nothing else will. This approval exists to unstick the gate, not to replace the human review.

**Local mode** — there's no PR, so nothing gets posted to GitHub. This mode runs inside a `claude -p` subprocess launched by the `pre-push` hook script, which can only see stdout text, not this skill's internal reasoning — so the verdict must end with an exact, greppable marker line:

- **Found one or more genuine functional/logic issues:** print each as `file:line — what would go wrong — suggested fix`, then end the response with the exact line `HFS_REVIEW_RESULT: ISSUES_FOUND` (nothing else on that line).
- **Nothing functional turned up:** print a one-line summary, then end with the exact line `HFS_REVIEW_RESULT: CLEAN`.

The wrapping `pre-push` script greps for these two strings to decide whether to block the push — get the marker line exactly right, since that's the only part of the output the script actually parses.

**Branch protection dependency:** for this to actually enforce "AI reviews, then a human reviews" rather than letting the bot's own approval merge the PR unassisted, protected branches need to require **2** approving reviews, not 1 (`CI-CD-Pipeline-HFS-V1.docx`, Section 19 — same GitHub Team dependency already noted there). One slot is this bot's; the other must come from an actual human collaborator. This doesn't add reviewing load — it's still one human per PR, same as before.

## Known limitations — track these for future iterations

- **Full-PR re-review on every push, not incremental.** Each `synchronize` event re-reviews the whole PR diff, not just what changed since the bot's last pass. On a large PR with many small follow-up commits, this repeats token/time cost on every push instead of scaling with the size of the fix. Worth revisiting once real usage shows this is actually costly, not before (Guiding Principle #2 in the CI/CD strategy doc).
- **No enforced ordering, only enforced completeness.** GitHub has no concept of "reviewer A before reviewer B." The 2-required-approvals setup guarantees both the bot and a human review before merge, but nothing stops a human from approving before the bot's pass lands. If strict ordering ever matters, it has to be a team norm (wait for the bot's comment before requesting human review), not a platform guarantee.
- **Bot login isn't pinned yet.** The "check for a prior outstanding review from this bot" step assumes a login like `claude` or `claude[bot]` — confirm the real value against an actual PR once the app is installed, and hardcode it here rather than guessing each run.
- **Billing/quota risk on the automation path.** `CLAUDE_CODE_OAUTH_TOKEN` usage from GitHub Actions draws against Anthropic's separate, capped monthly credit for automated/Agent SDK usage (introduced 2026) — not unlimited use of the subscription the way interactive terminal sessions are. If that credit is exhausted, the workflow can start failing outright (an auth/quota error) rather than degrading gracefully. Worth monitoring from day one, and worth re-checking Anthropic's current billing docs before relying on this, since this area has changed more than once in 2026.
- **The pre-push hook uses each developer's own personal Claude Code login, not the Action's shared secret.** Different auth path, different billing — three developers running this frequently means three individual subscriptions absorbing the cost, not the one repo secret. Worth watching whether that's actually cheaper or more expensive than expected once real usage shows up.
- **Local-mode signaling is a plain-text grep, not a structured contract.** The `pre-push` hook decides whether to block purely by grepping stdout for `HFS_REVIEW_RESULT: ISSUES_FOUND` / `CLEAN`. If the model ever wraps that line in markdown formatting or phrases it slightly differently, the grep can miss it and silently let a real issue through with no warning. Worth hardening (e.g. `--output-format json` and parsing a structured field) if this hook sees real use, not before.
- **The `pre-push` hook only catches what's about to leave the machine**, at push time — there's no earlier, in-session check while code is actually being written, so a lot of iteration can happen before this ever runs. That's a deliberate cost/simplicity tradeoff for now, not an oversight; revisit if push-time feedback turns out to be too late in practice.
