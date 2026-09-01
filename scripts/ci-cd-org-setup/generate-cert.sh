#!/usr/bin/env bash
set -euo pipefail

# generate-cert.sh — Step 1 of Org-Configuration-Runbook-JWT-ECA-HFS-V1.md
#
# Usage: ./generate-cert.sh <env-name> [validity-days]
#
# Generates a self-signed cert + private key pair for JWT auth against a Salesforce org.
#
# SAFETY: output goes to $HFS_CERT_DIR (default: ~/.hfs-ci-certs), deliberately OUTSIDE
# any git working tree, regardless of where this script itself lives. Private keys should
# never sit inside a repo folder, even a gitignored one — a single .gitignore mistake would
# put a private key into Git history permanently. Only override HFS_CERT_DIR if you
# understand that tradeoff.

ENV_NAME="${1:?Usage: $0 <env-name> [validity-days]}"
VALIDITY_DAYS="${2:-3650}"   # default ~10 years, matches existing Dev/QA/UAT certs.
                              # See "Decision Log" in the runbook before changing this.

CERT_BASE="${HFS_CERT_DIR:-$HOME/.hfs-ci-certs}"
OUT_DIR="${CERT_BASE}/${ENV_NAME}"
mkdir -p "$OUT_DIR"

KEY_FILE="${OUT_DIR}/server.key"
CRT_FILE="${OUT_DIR}/server.crt"

if [[ -f "$KEY_FILE" || -f "$CRT_FILE" ]]; then
  echo "Cert material already exists for '${ENV_NAME}' at ${OUT_DIR}." >&2
  echo "Remove it manually first if you intend to regenerate." >&2
  exit 1
fi

openssl genrsa -out "$KEY_FILE" 2048
openssl req -new -x509 -key "$KEY_FILE" -out "$CRT_FILE" -days "$VALIDITY_DAYS" \
  -subj "/CN=hfs-ci-${ENV_NAME}"

chmod 600 "$KEY_FILE"

EXPIRY_DATE=$(openssl x509 -enddate -noout -in "$CRT_FILE" | cut -d= -f2)

cat <<EOF

Generated cert pair for '${ENV_NAME}':
  Private key: ${KEY_FILE}
               (used by verify-jwt.sh and upload-secrets.sh, then deleted via cleanup.sh)
  Certificate: ${CRT_FILE}
               (upload THIS one to the External Client App in Salesforce Setup)
  Expires:     ${EXPIRY_DATE}

Record this expiry date in the tracking table in Org-Configuration-Runbook-JWT-ECA-HFS-V1.md.
EOF
