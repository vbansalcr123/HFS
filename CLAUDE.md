# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository status

Salesforce project with three package directories under `force-app/`: `hfs-backend` (Apex classes, LWC, permission sets), `hfs-frontend` (LWC, objects, static resources), and `hfs-integration` (Apex classes, LWC, aura). `sfdx-project.json` and `package.json` are both set up.

Commands (from `package.json`):
- `npm run lint` — ESLint over `aura`/`lwc` JS
- `npm test` — LWC Jest tests via `sfdx-lwc-jest`; single component: `npx sfdx-lwc-jest -- <componentName>`
- `npm run prettier` / `npm run prettier:verify` — format / check formatting (Apex, LWC, and other tracked file types)
- Apex tests run via Salesforce CLI, not npm: `sf apex run test --test-level RunLocalTests --code-coverage` (see `.github/workflows/scratch-org-validation.yml`); single class: `sf apex run test --tests <ClassName>`

Update this section again as the architecture evolves (new package directories, changed tooling, etc.).

## Apex & LWC development standards

Apex code follows the **fflib** pattern (Apex Enterprise Patterns — Domain, Selector, Service, Unit of Work layers). When writing or reviewing Apex, adhere to this layered architecture rather than putting logic directly in triggers or controllers.

Full coding standards — naming conventions, LWC component patterns, test class structure, error handling/logging, and a running list of open/future decisions — are documented in `docs/Apex-LWC-Development-Standards-HFS-V1.md` (currently under review). Treat it as binding once finalized; flag rather than silently deviate.

## Branch naming convention

When asked to create a branch from a Jira ticket, use:

- Feature: `feature/sprint_name/userstory/shorthand-name-of-the-feature`
- Bugfix: `bugfix/sprint_name/bug-id/shorthand-name-of-the-bug`

The shorthand name segment is optional — it exists to help the developer identify which story/bug they're working on.
