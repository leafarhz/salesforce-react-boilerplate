---
name: salesforce-uibundle
description: Use when building, deploying, or debugging a Salesforce React UIBundle (Multi-Framework) app — scaffolding a new UIBundle project, deploying it to an org, making it appear in the App Launcher, or troubleshooting issues like the app not showing, "No Items", stripped uiBundle fields, field-access errors, or INVALID_SESSION_ID. Covers the full lifecycle end to end.
---

# Salesforce React UIBundle — Full Lifecycle

Salesforce Multi-Framework (Beta) lets you build native React apps that deploy to the App Launcher. It is powerful but under-documented; this skill carries the proven runbook and the known gotchas so you don't rediscover them.

**Boilerplate lives in this plugin at `boilerplate/`.** Reference docs are in `references/`.

## Global rules (apply throughout)

- Salesforce API version is **`67.0`**. `68.0` returns "Invalid version specified."
- UIBundle apps are served on the **`.salesforce.app`** domain, not `lightning.force.com`.
- The `<uiBundle>` field on a CustomApplication is **creation-only** — deploy it exactly once as a create.

## Lifecycle

### 1. Scaffold
1. Copy this plugin's `boilerplate/` into the user's SFDX project.
2. Rename every `MyApp` reference to the chosen DeveloperName — case-sensitive, in filenames AND file contents (`applications/`, `uiBundles/`, `permissionsets/`, `classes/`).
3. Confirm `sfdx-project.json` has `"sourceApiVersion": "67.0"`.
4. Generate the React app inside `force-app/main/default/uiBundles/<App>/` using the Salesforce UIBundle CLI (`@salesforce/plugin-uibundle`). The boilerplate ships the `.uibundle-meta.xml` only — the CLI creates the React source.

### 2. Deploy
Follow **[references/deployment-runbook.md](references/deployment-runbook.md)** in exact order. Do not skip the `<uiBundle>` survival check after the CustomApplication deploy — if it was stripped, use the destructive re-deploy in the runbook.

### 3. Make it visible
Follow **[references/visibility-chain.md](references/visibility-chain.md)**: grant `applicationVisibilities` + `classAccesses` + object/field permissions in the Permission Set, assign it, then open the app on the `.salesforce.app` domain.

### 4. Debug
Start from the symptom index in **[references/gotchas.md](references/gotchas.md)** — map the error message or behavior to the numbered fix.
