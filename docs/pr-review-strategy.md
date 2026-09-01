## HFS PR Review System — context for Claude Code

This repo has a two-layer AI code review system implementing Section 10 of
CI-CD-Pipeline-HFS-V1.docx ("AI review is the required first approval gate
before a PR can move to human review").

**Layer 1 — `.githooks/pre-push`**: runs `claude -p "/hfs-pr-review local"`
locally before code leaves a developer's machine. Advisory only, bypassable
with `git push --no-verify`.

**Layer 2 — `.github/workflows/claude-pr-review.yml`**: runs on every PR
open/synchronize/reopen via `anthropics/claude-code-action`, invoking the
same skill in PR mode. Posts a real GitHub review (`gh pr review`) under
the Claude GitHub App's own bot identity — not the PR author's account, so
it isn't blocked by GitHub's self-approval restriction.

Both layers invoke the same skill: `.claude/skills/hfs-pr-review/SKILL.md`.
Treat that file as the single source of truth for what gets checked and how
the verdict gets posted — read it in full before touching either layer.

**Scope is deliberately narrow.** This skill only flags genuine
functional/logic bugs — things that would actually misbehave at runtime.
It does NOT flag naming, style, formatting, or generic security/best-practice
issues, since PMD (`bestpractices`, `security`) and ESLint already run on
every PR and cover that ground (CI-CD-Pipeline-HFS-V1.docx, Section 15). If
asked to extend this skill, preserve that boundary — don't let it drift into
a second linter.

**Design decisions already made — don't relitigate without a real reason:**
- Verdict logic: `Request Changes` on a real bug, plain `Comment` on a clean
  pass, `Approve` only to clear the bot's own earlier `Request Changes`
  block (GitHub requires the same reviewer to clear their own block — a
  comment or someone else's approval won't do it).
- Branch protection must require **2** approving reviews, not 1 — one slot
  is the bot's, one must come from an actual human. With only 1 required,
  the bot's own clearing-approve could satisfy the whole gate alone.
- GitHub can't enforce that AI review happens *before* human review, only
  that both exist before merge. Ordering is a team norm, not a platform
  guarantee.

**Still pending — real prerequisites, not done yet:**
1. Install the Claude GitHub App on this repo (`/install-github-app`, or
   manually).
2. Add `CLAUDE_CODE_OAUTH_TOKEN` or `ANTHROPIC_API_KEY` as a repo secret —
   see the comment block at the top of the workflow file for the tradeoffs.
3. Set branch protection to require 2 approving reviews.
4. Confirm the real bot login (`claude` vs `claude[bot]`) against an actual
   PR and hardcode it into the skill's "check for prior outstanding review"
   step — it's currently a guess.
5. Run `git config core.hooksPath .githooks` once per clone, and
   `chmod +x .githooks/pre-push`. Requires `jq` installed locally.

**Known limitations already tracked** — see "Known limitations" at the
bottom of SKILL.md for the full list; don't rediscover these as new bugs.
Notably: full-PR re-review on every push (not incremental), local-mode
verdict relies on a plain-text grep for an exact marker line
(`HFS_REVIEW_RESULT: ISSUES_FOUND`/`CLEAN`), and GitHub Actions usage of
`CLAUDE_CODE_OAUTH_TOKEN` draws from a separate, capped monthly credit —
not unlimited subscription use.