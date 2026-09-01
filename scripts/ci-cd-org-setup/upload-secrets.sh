#!/usr/bin/env bash
set -euo pipefail

# upload-secrets.sh — Step 8 of Org-Configuration-Runbook-JWT-ECA-HFS-V1.md
#
# Usage: ./upload-secrets.sh <github-environment-name> [key-file] [consumer-key] [username] [instance-url]
#
# Uploads CONSUMER_KEY, JWT_KEY, USERNAME, INSTANCE_URL to a scoped GitHub Environment.
#
# Prerequisites:
#   - GitHub CLI (gh) installed and authenticated: gh auth login
#   - Run from inside a clone of the repo (gh infers the repo from the git remote)
#   - verify-jwt.sh has already succeeded for this environment
#
# If consumer-key/username/instance-url are omitted, you'll be prompted for them —
# safer than typing them as CLI args, since CLI args can be visible via `ps` and land
# in shell history.

GH_ENV="${1:?Usage: $0 <github-environment-name> [key-file] [consumer-key] [username] [instance-url]}"

CERT_BASE="${HFS_CERT_DIR:-$HOME/.hfs-ci-certs}"
KEY_FILE="${2:-${CERT_BASE}/${GH_ENV}/server.key}"
CONSUMER_KEY="${3:-}"
CI_USERNAME="${4:-}"
INSTANCE_URL="${5:-}"

if [[ ! -f "$KEY_FILE" ]]; then
  echo "Key file not found at ${KEY_FILE}" >&2
  exit 1
fi

if ! command -v gh >/dev/null 2>&1; then
  echo "GitHub CLI (gh) is not installed. Install it first: https://cli.github.com" >&2
  exit 1
fi

[[ -z "$CONSUMER_KEY" ]] && read -rp "Consumer Key: " CONSUMER_KEY
[[ -z "$CI_USERNAME" ]] && read -rp "CI Integration Username: " CI_USERNAME
[[ -z "$INSTANCE_URL" ]] && read -rp "Instance URL (My Domain, e.g. https://yourdomain.my.salesforce.com): " INSTANCE_URL

gh secret set CONSUMER_KEY  --env "$GH_ENV" --body "$CONSUMER_KEY"
gh secret set USERNAME      --env "$GH_ENV" --body "$CI_USERNAME"
gh secret set INSTANCE_URL  --env "$GH_ENV" --body "$INSTANCE_URL"
gh secret set JWT_KEY       --env "$GH_ENV" < "$KEY_FILE"

cat <<EOF

Secrets uploaded to GitHub Environment '${GH_ENV}': CONSUMER_KEY, USERNAME, INSTANCE_URL, JWT_KEY.

GitHub never lets you read secret values back once set — the real check is a live
pipeline run. Trigger a workflow against '${GH_ENV}' and confirm it deploys successfully
before running cleanup.sh.
EOF
