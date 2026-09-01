# Slack Integration FAQ

*HFS Salesforce Project — Reference doc — Draft v1*

## 0. Purpose & Scope

This doc explains how Slack notifications work across this repo's GitHub Actions workflows, and walks through the most common request: changing which channel `deploy.yml` posts to.

---

## 1. Two different Slack integrations in this repo

This repo uses **two separate Slack mechanisms** that are easy to conflate because they both post to Slack, but they work differently and are configured in different places.

| | `deploy.yml` | `scratch-org-create.yml` |
|---|---|---|
| **Mechanism** | Incoming webhook (`SLACK_WEBHOOK_URL`) | Bot token (`SLACK_BOT_TOKEN`) via `.github/scripts/notify-slack-user.sh` pattern (inlined directly in this workflow, not via the script file) |
| **Destination** | One fixed **channel**, baked into the webhook URL | A specific **person**, resolved from an email address via Slack's `users.lookupByEmail` → DM'd via `chat.postMessage` |
| **Audience** | Broadcast — anyone watching the deploy channel | Just the developer who requested the scratch org |
| **What it sends** | Deploy success/failure summary (environment, branch, actor, run link) | The scratch org's login URL, username, and password (or a failure notice) |
| **How to change destination** | Repoint/recreate the webhook in Slack, then update the `SLACK_WEBHOOK_URL` secret | Nothing to configure per-run — it's driven by whatever email the requester types into the `workflow_dispatch` form |

**Why the difference:** an incoming webhook can only ever post to the one channel it was created for — there's no way to parameterize the destination per-run. That's fine for `deploy.yml`, which always wants the same audience (a shared deploy-status channel). But `scratch-org-create.yml` needs to reach a *different person* every time it runs, which a fixed-channel webhook can't do — hence the bot-token + `users.lookupByEmail` + `chat.postMessage` pattern instead, which can target any user in the workspace at runtime.

Related script: `.github/scripts/notify-slack-user.sh` implements this same bot-token DM pattern, but keyed off a **GitHub username → Slack email** mapping (`.github/reviewer-slack-map.json`) rather than a raw email input. Note that `scratch-org-create.yml` does **not** currently call this script — it inlines the same logic itself (looking up by the `email` input directly, since that workflow already collects an email rather than a GitHub username). `deploy.yml` doesn't call it either. Nothing in the repo currently invokes `notify-slack-user.sh` — it exists for a future workflow that wants to DM a specific reviewer by GitHub username (e.g. a PR-review notification).

---

## 2. How to change the channel `deploy.yml` posts to

The channel isn't set anywhere in the workflow YAML — it's baked into the Slack **incoming webhook URL** itself (`secrets.SLACK_WEBHOOK_URL`). Incoming webhooks are created per-channel in Slack, so redirecting one means repointing or recreating it in Slack, then updating the GitHub secret.

### Part 1 — Find/recreate the webhook in Slack

1. Go to **https://api.slack.com/apps** and log in with the Slack account tied to your workspace.
2. Click the app that owns this webhook (e.g. "GitHub Actions", "CI/CD Bot" — check with whoever originally set up `SLACK_WEBHOOK_URL` if the app isn't obvious).
3. In the left sidebar, click **Incoming Webhooks**.
4. You'll see existing webhook URLs, each labeled with the channel it posts to.
5. Slack incoming webhooks can't be edited in place to point at a different channel — create a new one instead:
   - Click **Add New Webhook to Workspace**, pick the new target channel, and authorize.
   - Copy the new **Webhook URL** (`https://hooks.slack.com/services/...`). Treat it as a secret — never paste it into chat, commits, or issues.
   - Once the new webhook is confirmed working (Part 3), come back and remove the old one from this list to revoke it.

### Part 2 — Update the secret in GitHub

`deploy.yml` scopes secrets by GitHub **Environment** (`environment: ${{ inputs.environment }}`), so update it in whichever environment(s) you're changing:

1. Repo → **Settings** → **Environments**.
2. Click the environment to change (`dev`, `qa`, `uat`, or `prod`).
3. Under **Environment secrets**, find `SLACK_WEBHOOK_URL`.
4. Click **Update**, paste the new webhook URL, and save.
5. Repeat for any other environments you want repointed.

### Part 3 — Verify

Trigger `deploy.yml` via `workflow_dispatch` for that environment (a no-op run against an already-deployed commit is fine — Step 12 "Notify Slack" runs `if: always()`), and confirm the message lands in the new channel.

**Same channel for every environment vs. per-environment channels:** since the secret is Environment-scoped, you can either point all four environments' `SLACK_WEBHOOK_URL` at the same webhook (one shared deploy channel), or create a separate webhook per environment and store each in its own Environment's secrets (e.g. a `#deploys-prod` channel separate from `#deploys-dev`). No workflow code change is needed either way — `deploy.yml` already reads `secrets.SLACK_WEBHOOK_URL` per-environment.
