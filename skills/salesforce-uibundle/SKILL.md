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
- **`vite.config.ts` MUST pass an explicit `orgAlias` to the `salesforce()` plugin call — never leave it bare.** Without it, the plugin resolves the API version it bakes into the build from whatever org is the *building machine's* global CLI default (`sf config get target-org`), completely unrelated to your actual target org. This is THE most common cause of a persistent 401 that survives every other fix — see gotcha #16. Set it during scaffolding, not after debugging it.
- **Data + auth are handled by the platform Data SDK** (`@salesforce/sdk-data` — see "Data access" below for why, despite Salesforce's own beta→GA docs suggesting `@salesforce/platform-sdk`) — no OAuth/token management inside the app.
- **GA limitation:** React apps surface as **standalone App Launcher apps**. Lightning App Builder drag-drop placement and embedding externally-hosted React components are **not yet supported** (roadmap). If you need a component embedded on a record/home page, that's still LWC territory today.

## Lifecycle

### 1. Scaffold
1. Copy this plugin's `boilerplate/` into the user's SFDX project.
2. Rename every `MyApp` reference to the chosen DeveloperName — case-sensitive, in filenames AND file contents (`applications/`, `uiBundles/`, `permissionsets/`, `classes/`).
3. Confirm `sfdx-project.json` has `"sourceApiVersion": "67.0"`.
4. Generate the React app inside `force-app/main/default/uiBundles/<App>/` using the Salesforce UIBundle CLI (`@salesforce/plugin-uibundle`). The boilerplate ships the `.uibundle-meta.xml` only — the CLI creates the React source, including a fresh `vite.config.ts`.
5. **MANDATORY, do not skip:** open the generated `vite.config.ts` and add the target org alias to the `salesforce()` plugin call: `salesforce({ orgAlias: '<target-org-alias>' })`. The CLI generates this call bare (no options), which is unsafe — see gotcha #16 for exactly what breaks and why it's easy to not notice until hours into debugging a 401. Do this before the first build, not after something goes wrong.
6. Verify it actually took: `npm run build && grep -o 'v67\.0' dist/assets/*.js` (or whatever your target org's real API version is) — confirms the correct version landed in the compiled bundle, not just that you edited the config file.

### 2. Deploy
Follow **[references/deployment-runbook.md](references/deployment-runbook.md)** in exact order. Do not skip the `<uiBundle>` survival check after the CustomApplication deploy — if it was stripped, use the destructive re-deploy in the runbook.

### 3. Make it visible
Follow **[references/visibility-chain.md](references/visibility-chain.md)**: grant `applicationVisibilities` + `classAccesses` + object/field permissions in the Permission Set, assign it, then open the app on the `.salesforce.app` domain.

### 4. Debug
Start from the symptom index in **[references/gotchas.md](references/gotchas.md)** — map the error message or behavior to the numbered fix.

## Data access (React → Salesforce)

The React bundle reads and writes Salesforce data through the **platform Data SDK**. Auth is automatic: the user's Salesforce session (on the `.salesforce.app` domain) is used under the platform security/governance model, so there is **no OAuth flow, token storage, or CORS setup** inside the app (unlike a static-resource or externally-hosted React app).

**Use `@salesforce/sdk-data` for `createDataSDK()`, not `@salesforce/platform-sdk`.** Every proven working reference app this skill has verified uses `sdk-data` with zero options and a plain relative-path `sdk.fetch(path)` — no `basePath` override, no absolute-URL workaround, nothing. `platform-sdk` is what Salesforce's own beta→GA docs suggest migrating to, but it pulls in a heavier analytics/o11y chunk for no benefit here, and it's easy to end up down a debugging rabbit hole assuming it's the "more correct" choice when it isn't. (Whichever package you pick, gotcha #16 — the build baking in the wrong org's API version — affects both identically; picking `sdk-data` doesn't protect you from that, only setting `orgAlias` does.)

The SDK gives three things:
- **GraphQL** — `sdk.graphql<TData, TVariables>({ query, variables })` is a single callable (NOT separate `.query()`/`.mutate()` methods — that's `platform-sdk`'s shape, not `sdk-data`'s; check which package's type signature you're actually coding against, don't assume). Same UI API GraphQL backend LWC uses (Relay `edges → node` shape; scalars wrapped as `{ value: … }`).
- **Apex invocation** — call `@AuraEnabled` / Apex REST methods directly via `sdk.fetch()`. Use this for anything the GraphQL layer can't express: dynamic SOQL, aggregate queries (`COUNT`, `GROUP BY`, `WEEK_IN_YEAR`), batch orchestration, and multi-step server-side business logic.
- **UI API** — user context and record UI metadata.

**If every data call 401s, check gotcha #16 FIRST** (build baked in the wrong org's API version at compile time — the actual answer almost every time, regardless of what the symptom looks like). Only after ruling that out: gotcha #13 (the running user needs the **Agentforce entitlement** — a permission set backed by the *Agentforce Platform Developer and Admin* PSL, `sf org assign permset --name AgentforceDeveloperAndAdminTools`), gotcha #14 (`AppFrameworkPsl`, a separate license some orgs also require), and gotcha #15 (stale cached bundle after a redeploy). A plain global `fetch()` always 401s regardless of any of this — the SDK's authenticated fetch is required either way.

Practical guidance:
- Wrap all SDK calls behind **one thin data module** so the UI never imports the SDK directly — keeps components testable (mock the module) and the transport swappable.
- Reuse existing Apex controllers where the logic is non-trivial (they already enforce sharing/FLS and hold the business rules); expose reads over GraphQL only where a plain record query suffices.
- **Never trust a client-only permission flag** (e.g. an "admin-only" button) — gate privileged actions with a server-side check (custom permission / `isAccessible`) in the Apex method itself.
- `@salesforce/apex` (the LWC compiler import) does **not** exist here — that's LWC-only. Use the Data SDK's Apex invocation instead.
