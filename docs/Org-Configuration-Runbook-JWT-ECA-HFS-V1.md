# Org Configuration Runbook — JWT Auth via External Client App (ECA)

_HFS Salesforce Project — Reference doc — Draft v1_

## 0. Purpose & Scope

This is the repeatable, step-by-step checklist for configuring a **new Salesforce org** for CI/CD JWT-based authentication, so it can be added as a Dev/QA/UAT (or any future) environment in the GitHub Actions pipeline.

**This supersedes the Connected App steps in Section 9 of `CI-CD-Pipeline-HFS-V1.docx` as literally written.** That section describes a Connected App; as of Spring '26, Salesforce deprecated that model in favor of **External Client Apps (ECA)** for this use case. Everything below uses ECA. Section 9's surrounding logic (per-org credentials, GitHub Environment secrets, no shared creds across orgs) still holds — only the Salesforce-side app type changes.

Use this doc every time a new org needs to be onboarded to the pipeline (new sandbox, Production at go-live, or a one-off testing org).

---

## 1. Prerequisites

- [ ] OpenSSL installed locally (`openssl version` to confirm)
- [ ] System Administrator access to the target Salesforce org
- [ ] Repo admin access on GitHub (to create/edit Environments and secrets)
- [ ] Salesforce CLI installed (`sf --version`)
- [ ] Know which GitHub Environment this maps to (`Dev`, `QA`, `UAT`, or a new one)

---

## 2. Step 1 — Generate Certificate + Private Key

Run locally, in a scratch folder outside the repo (never inside a Git-tracked directory):

```bash
mkdir hfs-jwt-<env> && cd hfs-jwt-<env>

openssl genrsa -out server.key 2048

openssl req -new -x509 -key server.key -out server.crt -days 3650 \
  -subj "/CN=hfs-ci-<env>"
```

- `server.key` — private key. Goes into GitHub Secrets. **Never commit this anywhere.**
- `server.crt` — public certificate. Gets uploaded to the ECA in Salesforce.
- `-days 3650` = ~10 years, matching the existing Dev/QA/UAT certs. See Section 14 (Decision Log) before changing this.

---

## 3. Step 2 — Create the External Client App (ECA)

In the target org:

1. **Setup → search "External Client Apps" → External Client App Manager → New External Client App.**
2. **Basic Information:** Name it `hfs_CI_<Env>` (e.g., `hfs_CI_QA`), add a contact email.
3. **API (OAuth) Settings:**
   - Enable OAuth.
   - Callback URL: required field even though JWT flow doesn't use it — use `https://login.salesforce.com/services/oauth2/callback` as a placeholder.
   - Check **"Use digital signatures"** and upload `server.crt`.
   - OAuth Scopes: at minimum `Manage user data via APIs (api)` and `Perform requests at any time (refresh_token, offline_access)`.
4. Save, then find the **Consumer Key** on the app's detail page — this is your `CONSUMER_KEY`.

---

## 4. Step 3 — Configure OAuth Policies + Permission Set

1. On the ECA, go to **OAuth Policies** (or the app's policy settings).
2. Set permitted users to **"Admin approved users are pre-authorized."**
3. Create (or reuse) a Permission Set that grants access to this ECA.
4. Assign that Permission Set to the dedicated CI integration user (Step 4).

---

## 5. Step 4 — Create/Assign the CI Integration User

- Use a **dedicated integration user**, not a real person's account — the pipeline shouldn't break if someone leaves.
- Assign it the minimum permission set needed to do its job (deploy metadata, run tests) plus the ECA permission set from Step 3.
- Note its username — this is your `USERNAME` secret.

---

## 6. Step 5 — One-Time Interactive Login (Spring '26 requirement)

**Known gotcha, easy to miss:** as of Spring '26, a newly created CI integration user must log in **interactively at least once** (browser login with username/password) before JWT-based auth will succeed for that user. Skipping this step is a common cause of JWT auth failing on a brand-new user even when everything else is configured correctly.

- [ ] Log in once via browser as the CI integration user before attempting Step 7.

---

## 7. Step 6 — Find the Correct Instance URL

**Second Spring '26 gotcha:** `--instance-url` must be the org's **My Domain** URL (e.g., `https://yourdomain.my.salesforce.com`), not the generic `https://login.salesforce.com`. Using the generic URL will fail post-Spring '26 even if the rest of the setup is correct.

- Find it under **Setup → My Domain**, or from the org's login URL after My Domain is deployed.
- This becomes your `INSTANCE_URL` secret.

---

## 8. Step 7 — Verify JWT Auth Locally

Before wiring this into GitHub Actions, confirm it works from your machine:

```bash
sf org login jwt \
  --username <ci-user-username> \
  --jwt-key-file server.key \
  --client-id <consumer-key> \
  --instance-url https://yourdomain.my.salesforce.com \
  --alias hfs-<env>
```

Don't proceed to Step 9 until this succeeds. If it fails, see Section 13 (Troubleshooting) before assuming the GitHub Secrets are the problem.

---

## 9. Step 8 — Add GitHub Environment Secrets

1. Repo → **Settings → Environments** → select the existing environment (`Dev`/`QA`/`UAT`) or create a new one.
2. Add these secrets, scoped to that Environment (not repo-wide):
   - `CONSUMER_KEY`
   - `JWT_KEY` — paste the **full contents** of `server.key`, including the `-----BEGIN/END PRIVATE KEY-----` lines.
   - `USERNAME`
   - `INSTANCE_URL`

---

## 10. Step 9 — Register the Environment in the Deploy Workflow

Adding the GitHub Environment and its secrets (Step 8) makes the environment exist, but it will **not** show up as a choice in the "Deploy to Environment" Action until the workflow file knows about it — this step is easy to skip and is the most common reason a newly onboarded org "isn't there" when someone goes to run a deploy.

1. Open `.github/workflows/deploy.yml`.
2. Add the environment's name to the `options:` list under `on.workflow_dispatch.inputs.environment`:
   ```yaml
   options:
     - dev
     - qa
     - uat
     - prod
     - dev-sandbox
     - <new-environment-name>
   ```
3. The value you add here **must exactly match** (case-sensitive) the GitHub Environment name created in Step 8 — `environment: ${{ inputs.environment }}` in the job is what ties the selected dropdown value back to that Environment's scoped secrets. A mismatch means the job either fails to resolve the environment or silently pulls no secrets.
4. Check the **"Known coupling to watch for"** comment above the `Validate Deploy (Dry Run)` step in the same file. It hard-codes a check for the literal string `"prod"` to decide `RunLocalTests` (mandatory, org-wide) vs. `RunSpecifiedTests` (scoped to this project). Every environment other than `prod` is currently treated as shared/non-production for that purpose — if the new environment is production-tier, or if it's _not_ shared with other projects and could safely run a narrower test scope, update that condition by hand; it can't be inferred from the org automatically.
5. Commit the change (PR + merge like any other workflow edit) and confirm the new option now appears in the Actions tab under **Run workflow → Target environment to deploy to**.
6. Do a first test run against the new environment before considering onboarding complete — see the Definition of Done checklist below.

---

## 11. Step 10 — Clean Up Local Key Material

- [ ] Delete the local `server.key` / `server.crt` working folder once secrets are uploaded, or move it to a secured password manager — don't leave it sitting in a Downloads folder.
- [ ] Confirm `server.key`/`server.crt` are not tracked by Git (add to `.gitignore` if they were ever generated inside the repo folder).

---

## 12. Definition of Done

- [ ] ECA created, digital signature enabled, `server.crt` uploaded
- [ ] OAuth policy set to admin-pre-authorized, Permission Set assigned
- [ ] CI integration user created, permission set assigned, one interactive login completed
- [ ] Correct My Domain instance URL identified
- [ ] `sf org login jwt` succeeds locally
- [ ] All 4 secrets added to the correct GitHub Environment
- [ ] Environment name added to the `options:` list in `.github/workflows/deploy.yml` and visible in the Actions dropdown
- [ ] A test workflow run against this environment completes successfully
- [ ] Local key material cleaned up / secured

---

## 13. Troubleshooting

| Symptom                                                                          | Likely Cause                                                                                                                                |
| -------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------- |
| `invalid_grant`                                                                  | CI user hasn't completed the one-time interactive login (Section 6), or user hasn't been approved for the ECA                               |
| `invalid_client_id`                                                              | Wrong Consumer Key, or pointing at the wrong ECA                                                                                            |
| Auth fails only in CI, works locally                                             | `INSTANCE_URL` secret is set to `login.salesforce.com` instead of My Domain                                                                 |
| JWT signature invalid                                                            | The `.crt` uploaded to the ECA doesn't match the `.key` used to sign the JWT — regenerate the pair together, don't mix and match            |
| Works, then stops working after ~10 years                                        | Certificate expired — see Section 14 tracking table                                                                                         |
| New environment doesn't appear in the "Target environment to deploy to" dropdown | Step 9 (registering it in `deploy.yml`'s `options:` list) was skipped, or the option name doesn't exactly match the GitHub Environment name |

---

## 14. Decision Log & Tracking

**Cert validity — currently defaulting to 10 years**, consistent with existing Dev/QA/UAT certs. This is a real tradeoff, not a settled best practice for this project (see Section 17 of the CI/CD strategy doc, which already flags rotation as an open question):

|                             | 10-year (current default) | Shorter-lived (1–2 yr)            |
| --------------------------- | ------------------------- | --------------------------------- |
| Ops burden                  | None after initial setup  | Recurring rotation task           |
| Blast radius if key leaks   | Valid for a decade        | Limited window                    |
| Forcing function for review | None                      | Expiry forces a periodic check-in |

**Org tracking table** — log every org configured via this runbook, so expiry isn't invisible even without a formal rotation policy:

| Environment | ECA Name           | Created Date | Cert Expiry | Configured By                  |
| ----------- | ------------------ | ------------ | ----------- | ------------------------------ |
| Dev         | hfs_CI_Dev         |              |             |                                |
| QA          | hfs_CI_QA          |              |             |                                |
| UAT         | hfs_CI_UAT         |              |             |                                |
| Dev-Sandbox | hfs_CI_Dev-Sandbox | 2026-09-01   |             | varun.bansal@criticalriver.com |
| QA-Sandbox  | hfs_CI_QA-Sandbox  | 2026-09-04   |             | varun.bansal@criticalriver.com |

_(Fill in as orgs are configured/reconfigured against this runbook.)_
