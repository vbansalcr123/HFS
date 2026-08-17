# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository status

This is a Salesforce project. It currently contains no source code yet — the `.gitignore` is set up for Salesforce tooling (ignores `.sf/`, `.sfdx/`, `.localdevserver/`, LWC Jest coverage, etc.), but no `sfdx-project.json` or `force-app/` directory exists yet.

The project will include Apex, LWC, and other Salesforce metadata (objects, flows, permission sets, etc.).

When real code, build tooling, or tests are added to this repo, update this file with the actual commands (build/lint/test/single-test) and architecture notes.

## Apex development

Apex code follows the **fflib** pattern (Apex Enterprise Patterns — Domain, Selector, Service, Unit of Work layers). When writing or reviewing Apex, adhere to this layered architecture rather than putting logic directly in triggers or controllers.

## Branch naming convention

When asked to create a branch from a Jira ticket, use:

- Feature: `feature/sprint_name/userstory/shorthand-name-of-the-feature`
- Bugfix: `bugfix/sprint_name/bug-id/shorthand-name-of-the-bug`

The shorthand name segment is optional — it exists to help the developer identify which story/bug they're working on.
