#!/usr/bin/env bash
set -euo pipefail

# setup-org.sh — orchestrates the scriptable half of Org-Configuration-Runbook-JWT-ECA-HFS-V1.md
#
# Usage: ./setup-org.sh <env-name> <github-environment-name> [validity-days]
#
# You must complete the MANUAL Salesforce-side steps (ECA creation, OAuth policy +
# permission set, CI integration user + its one-time interactive login — Sections 3-6
# of the runbook) when prompted partway through. Nothing in Salesforce Setup itself
# can be scripted here.

ENV_NAME="${1:?Usage: $0 <env-name> <github-environment-name> [validity-days]}"
GH_ENV="${2:?Missing github-environment-name}"
VALIDITY_DAYS="${3:-3650}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "== Step 1: Generate cert + key =="
"${SCRIPT_DIR}/generate-cert.sh" "$ENV_NAME" "$VALIDITY_DAYS"

CERT_BASE="${HFS_CERT_DIR:-$HOME/.hfs-ci-certs}"

cat <<EOF

Now complete the MANUAL steps before continuing (Sections 3-6 of the runbook):
  - Create the External Client App and upload ${CERT_BASE}/${ENV_NAME}/server.crt
  - Configure the OAuth policy (admin-pre-authorized) + permission set
  - Create/assign the dedicated CI integration user
  - Complete that user's one-time interactive login (required post-Spring '26)
  - Note the Consumer Key, the CI user's Username, and the My Domain instance URL

EOF
read -rp "Press Enter once these are done and you have those three values ready..."

echo ""
echo "== Step 2: Verify JWT auth locally =="
read -rp "CI Integration Username: " CI_USERNAME
read -rp "Consumer Key: " CONSUMER_KEY
read -rp "Instance URL (My Domain): " INSTANCE_URL

"${SCRIPT_DIR}/verify-jwt.sh" "$ENV_NAME" "$CI_USERNAME" "$CONSUMER_KEY" "$INSTANCE_URL"

echo ""
echo "== Step 3: Upload secrets to GitHub =="
"${SCRIPT_DIR}/upload-secrets.sh" "$GH_ENV" "${CERT_BASE}/${ENV_NAME}/server.key" \
  "$CONSUMER_KEY" "$CI_USERNAME" "$INSTANCE_URL"

cat <<EOF

Scripted steps complete for '${ENV_NAME}' -> GitHub Environment '${GH_ENV}'.

Next:
  1. Trigger a real workflow run against '${GH_ENV}' and confirm it succeeds.
  2. Only then run: ./cleanup.sh ${ENV_NAME}
EOF
