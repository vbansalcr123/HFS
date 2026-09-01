#!/usr/bin/env bash
set -euo pipefail

# cleanup.sh — Step 9 of Org-Configuration-Runbook-JWT-ECA-HFS-V1.md
#
# Usage: ./cleanup.sh <env-name>
#
# Removes local cert/key material for an environment. This is deliberately NOT automatic
# after upload-secrets.sh — you must confirm secrets are uploaded AND a real pipeline run
# has succeeded before this deletes anything.

ENV_NAME="${1:?Usage: $0 <env-name>}"

CERT_BASE="${HFS_CERT_DIR:-$HOME/.hfs-ci-certs}"
TARGET_DIR="${CERT_BASE}/${ENV_NAME}"

if [[ ! -d "$TARGET_DIR" ]]; then
  echo "Nothing to clean up at ${TARGET_DIR}." >&2
  exit 0
fi

echo "This will permanently delete: ${TARGET_DIR} (private key included)."
read -rp "Have you confirmed secrets are uploaded AND a pipeline run succeeded against this environment? (yes/no): " CONFIRM

if [[ "$CONFIRM" != "yes" ]]; then
  echo "Aborted. Nothing deleted."
  exit 1
fi

if command -v shred >/dev/null 2>&1; then
  shred -u "${TARGET_DIR}"/*
  rmdir "$TARGET_DIR"
else
  rm -rf "$TARGET_DIR"
fi

echo "Local key material for '${ENV_NAME}' removed."
