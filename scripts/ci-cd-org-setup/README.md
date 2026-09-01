# Org Setup Scripts

Scripted half of `Org-Configuration-Runbook-JWT-ECA-HFS-V1.md`. Covers everything that
doesn't require clicking through Salesforce Setup.

## Setup

```bash
chmod +x scripts/org-setup/*.sh
gh auth login   # one-time, if not already done
```

## Usage

**Guided, one environment at a time:**
```bash
./scripts/org-setup/setup-org.sh <env-name> <github-environment-name>
```
Walks through cert generation, pauses for the manual Salesforce steps, then verifies
JWT auth and uploads secrets.

**Or run each step standalone** (useful if you're re-running just one step):
```bash
./generate-cert.sh <env-name> [validity-days]
./verify-jwt.sh <env-name> <username> <consumer-key> <instance-url>
./upload-secrets.sh <github-environment-name>
./cleanup.sh <env-name>
```

## Where keys live

Certs and private keys are written to `~/.hfs-ci-certs/<env-name>/` — **outside** this
repo, on purpose. Only these scripts belong in Git; the key material they generate
never should, even gitignored. Override with the `HFS_CERT_DIR` environment variable
only if you've deliberately decided that tradeoff is worth it.

## Order

1. `generate-cert.sh` — creates `server.key` / `server.crt`
2. *(manual)* create the ECA in Salesforce, upload `server.crt`, configure OAuth
   policy + permission set, create the CI user, complete its one-time interactive login
3. `verify-jwt.sh` — confirms auth works before anything touches GitHub
4. `upload-secrets.sh` — pushes the 4 secrets to the scoped GitHub Environment
5. Trigger a real pipeline run against that environment and confirm it succeeds
6. `cleanup.sh` — deletes local key material (asks for explicit confirmation first)
