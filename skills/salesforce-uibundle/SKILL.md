---
name: salesforce-uibundle
description: Use when building, deploying, or debugging a Salesforce React UIBundle (Multi-Framework) app — scaffolding a new UIBundle project, deploying it to an org, making it appear in the App Launcher, or troubleshooting issues like the app not showing, "No Items", stripped uiBundle fields, field-access errors, or INVALID_SESSION_ID. Covers the full lifecycle end to end.
---

# Salesforce React UIBundle — Full Lifecycle

Salesforce Multi-Framework lets you build native React apps that deploy to the App Launcher. **It went GA in Summer '26** — production-ready, supported for business-critical workloads, and already enabled in every org (no opt-in). It deploys to production, sandbox, Developer Edition, and scratch orgs. This skill carries the proven runbook and the known gotchas so you don't rediscover them.

**Boilerplate lives in this plugin at `boilerplate/`.** Reference docs are in `references/`.

> **On a beta app built before Summer '26?** See `references/gotchas.md` #12 for the 5 beta→GA breaking changes (SDK rename, `graphql()` split, target value, deprecated scratch config).

## Global rules (apply throughout)

- Salesforce API version is **`67.0`** (Summer '26). `68.0` returns "Invalid version specified." Verify against your org's release if newer.
- UIBundle apps are served on the **`.salesforce.app`** domain, not `lightning.force.com`.
- The `<uiBundle>` field on a CustomApplication is **creation-only** — deploy it exactly once as a create.
- **Data + auth are handled by the platform Data SDK** (`@salesforce/platform-sdk`) — no OAuth/token management inside the app. See "Data access" below.
- **GA limitation:** React apps surface as **standalone App Launcher apps**. Lightning App Builder drag-drop placement and embedding externally-hosted React components are **not yet supported** (roadmap). If you need a component embedded on a record/home page, that's still LWC territory today.

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

## Data access (React → Salesforce)

The React bundle reads and writes Salesforce data through the **platform Data SDK** — `@salesforce/platform-sdk`. Auth is automatic: the user's Salesforce session (on the `.salesforce.app` domain) is used under the platform security/governance model, so there is **no OAuth flow, token storage, or CORS setup** inside the app (unlike a static-resource or externally-hosted React app).

The SDK gives three things:
- **GraphQL** — `.query()` for reads, `.mutate()` for writes. Same UI API GraphQL backend LWC uses (Relay `edges → node` shape; scalars wrapped as `{ value: … }`).
- **Apex invocation** — call `@AuraEnabled` / Apex REST methods directly. Use this for anything the GraphQL layer can't express: dynamic SOQL, aggregate queries (`COUNT`, `GROUP BY`, `WEEK_IN_YEAR`), batch orchestration, and multi-step server-side business logic.
- **UI API** — user context and record UI metadata.

**Prerequisite — the running user needs the Agentforce entitlement.** Even a System Admin gets **401 on every data call** (app renders, but no session is minted) until assigned a permission set backed by the *Agentforce Platform Developer and Admin* PSL — the standard **`AgentforceDeveloperAndAdminTools`** perm set (`sf org assign permset --name AgentforceDeveloperAndAdminTools`). This is the #1 "it renders but data 401s" trap — see gotcha #13. Once entitled, `sdk.fetch` works from **either** `@salesforce/sdk-data` or `@salesforce/platform-sdk`; a plain global `fetch()` still 401s (use the SDK's authenticated fetch).

Practical guidance:
- Wrap all SDK calls behind **one thin data module** so the UI never imports the SDK directly — keeps components testable (mock the module) and the transport swappable.
- Reuse existing Apex controllers where the logic is non-trivial (they already enforce sharing/FLS and hold the business rules); expose reads over GraphQL only where a plain record query suffices.
- **Never trust a client-only permission flag** (e.g. an "admin-only" button) — gate privileged actions with a server-side check (custom permission / `isAccessible`) in the Apex method itself.
- `@salesforce/apex` (the LWC compiler import) does **not** exist here — that's LWC-only. Use the Data SDK's Apex invocation instead.
