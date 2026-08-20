#!/usr/bin/env bash
# Look up a GitHub username's Slack account via .github/reviewer-slack-map.json + Slack's
# users.lookupByEmail, then DM them the given message. Any lookup/post failure is logged as a
# workflow warning and exits 0 — a missing mapping or Slack hiccup must never fail the calling job.
#
# Usage: notify-slack-user.sh <github-username> <message-text>
# Requires SLACK_BOT_TOKEN in the environment.
set -euo pipefail

GH_USERNAME="$1"
MESSAGE="$2"
MAP_FILE=".github/reviewer-slack-map.json"

if [ ! -f "$MAP_FILE" ]; then
  echo "::warning::$MAP_FILE not found — skipping Slack notification for $GH_USERNAME."
  exit 0
fi

SLACK_EMAIL=$(jq -r --arg user "$GH_USERNAME" '.[$user] // empty' "$MAP_FILE")
if [ -z "$SLACK_EMAIL" ]; then
  echo "::warning::No Slack mapping found for GitHub user '$GH_USERNAME' in $MAP_FILE — skipping notification."
  exit 0
fi

USER_LOOKUP=$(curl -s -G -H "Authorization: Bearer $SLACK_BOT_TOKEN" \
  --data-urlencode "email=$SLACK_EMAIL" \
  https://slack.com/api/users.lookupByEmail)

if [ "$(jq -r '.ok' <<< "$USER_LOOKUP")" != "true" ]; then
  echo "::warning::Slack lookup for $SLACK_EMAIL (GitHub user $GH_USERNAME) failed: $(jq -r '.error' <<< "$USER_LOOKUP")"
  exit 0
fi
SLACK_USER_ID=$(jq -r '.user.id' <<< "$USER_LOOKUP")

# chat.postMessage accepts a user ID directly as "channel" and opens the DM itself — avoids
# needing the im:write scope conversations.open would require (see scratch-org-create.yml).
POST_RESULT=$(curl -s -X POST -H "Authorization: Bearer $SLACK_BOT_TOKEN" \
  -H 'Content-type: application/json; charset=utf-8' \
  --data "$(jq -n --arg channel "$SLACK_USER_ID" --arg text "$MESSAGE" '{channel: $channel, text: $text}')" \
  https://slack.com/api/chat.postMessage)

if [ "$(jq -r '.ok' <<< "$POST_RESULT")" != "true" ]; then
  echo "::warning::Slack DM post to $GH_USERNAME failed: $(jq -r '.error' <<< "$POST_RESULT")"
fi
