#!/usr/bin/env bash
set -euo pipefail

# verify-jwt.sh — Step 7 of Org-Configuration-Runbook-JWT-ECA-HFS-V1.md
#
# Usage: ./verify-jwt.sh <env-name> <username> <consumer-key> <instance-url> [key-file]
#
# Confirms JWT auth works BEFORE secrets are uploaded to GitHub or local key material
# is deleted. Only run this after completing the manual Salesforce steps (ECA creation,
# OAuth policy + permission set, CI integration user + its one-time interactive login —
# Sections 3-6 of the runbook).

ENV_NAME="${1:?Usage: $0 <env-name> <username> <consumer-key> <instance-url> [key-file]}"
CI_USERNAME="${2:?Missing username}"
CONSUMER_KEY="${3:?Missing consumer key}"
INSTANCE_URL="${4:?Missing instance url}"

CERT_BASE="${HFS_CERT_DIR:-$HOME/.hfs-ci-certs}"
KEY_FILE="${5:-${CERT_BASE}/${ENV_NAME}/server.key}"

if [[ ! -f "$KEY_FILE" ]]; then
  echo "Key file not found at ${KEY_FILE}" >&2
  echo "Run generate-cert.sh first, or pass the key file path explicitly." >&2
  exit 1
fi

if [[ "$INSTANCE_URL" == *"login.salesforce.com"* ]]; then
  echo "WARNING: instance-url looks like the generic login URL, not a My Domain URL." >&2
  echo "Per the Spring '26 ECA change, JWT auth will likely fail against this." >&2
  echo "Use https://yourdomain.my.salesforce.com instead (Setup -> My Domain)." >&2
fi

sf org login jwt \
  --username "$CI_USERNAME" \
  --jwt-key-file "$KEY_FILE" \
  --client-id "$CONSUMER_KEY" \
  --instance-url "$INSTANCE_URL" \
  --alias "hfs-${ENV_NAME}"

echo ""
echo "JWT auth succeeded for '${ENV_NAME}'. Safe to proceed to upload-secrets.sh."
