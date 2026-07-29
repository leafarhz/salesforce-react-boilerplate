# Gotchas — Symptom Index

Jump from what you're seeing to the fix.

| Symptom | Gotcha |
| --- | --- |
| App not in App Launcher / "No Items" / "doesn't have any navigation items" | #11 (wrong domain), #1 (uiBundle stripped) |
| Deploy says "State: Changed" but the app still has no React UI | #1 (`<uiBundle>` silently stripped) |
| Your local `.app-meta.xml` lost its `<uiBundle>` after a retrieve | #2 (retrieve overwrites local) |
| `No such column 'MyField__c' on entity 'MyObject__c'` | #3 (FLS is separate from object perms) |
| `You cannot deploy to a required field` | #4 (required fields can't be in PS fieldPermissions) |
| `Property 'componentInstances' not valid in version 67.0` | #6 (don't use a FlexiPage) |
| `Invalid version specified` | #8 (use API 67.0, not 68.0) |
| `INVALID_SESSION_ID` on a REST callout from Apex | #9 (never use a Lightning session ID) |
| `The decision table API Name is invalid` | #10 (use DeveloperName, not display label) |
| NamedCredential deploy fails cryptically | #7 (`<endpoint>` + `<principalType>` required; no `<name>`) |
| Beta app broke after Summer '26 GA | #12 (5 beta→GA breaking changes) |
| App **renders** but every data call is **401** (often + a `.../ui-api/session/csrf` **404** on a stale-looking API version like `v50.0`) | **Check #16 FIRST** (build baked in the wrong org's API version — the actual answer almost every time this symptom shows up with a wrong-looking version number). Only after ruling that out: #15 (stale cached bundle), #13 (Agentforce entitlement), #14 (`AppFrameworkPsl`) |

## #1 — `<uiBundle>` is creation-only and silently stripped

BIGGEST TIME SINK. If a CustomApplication already exists in the org without `<uiBundle>`, you cannot add it via a deploy update. Salesforce accepts the deploy ("State: Changed") but silently drops the field. Fix: delete the CustomApplication from the org and recreate it (see deployment-runbook.md → "Changing the `<uiBundle>` field").

Check if you're in this situation:
```bash
sf project retrieve start --metadata "CustomApplication:MyApp" --target-org <alias>
grep uiBundle force-app/main/default/applications/MyApp.app-meta.xml
# No output = you're in this situation.
```

## #2 — `sf project retrieve start` overwrites your local files

If your local `MyApp.app-meta.xml` has `<uiBundle>` but the org doesn't (because it was stripped), a retrieve overwrites your local file to match the org — silently deleting your fix. When local intentionally differs from the org, inspect via Tooling API instead of retrieving:
```bash
sf data query --use-tooling-api \
  --query "SELECT Id, DeveloperName FROM UIBundle WHERE DeveloperName = 'MyApp'" \
  --target-org <alias>
```

## #3 — Object permission ≠ field access (FLS is always separate)

Even with `allowRead: true` on an object, users cannot see custom fields until you add explicit `<fieldPermissions>` entries. The error `No such column 'MyField__c' on entity 'MyObject__c'` fires for BOTH a missing field AND missing FLS — confusing. Add a `<fieldPermissions>` block for every non-required custom field the app queries.

## #4 — Required fields cannot appear in Permission Set fieldPermissions

Adding `<fieldPermissions>` for a required field fails the deploy: "You cannot deploy to a required field." Required fields are always accessible — exclude them. Find them:
```bash
grep -l "<required>true</required>" force-app/main/default/objects/MyObject__c/fields/*.field-meta.xml
```

## #5 — `<target>CustomApplication</target>` in uibundle-meta.xml IS valid

Some docs imply this element doesn't exist. It does, and it's required for the UIBundle to be linkable from a CustomApplication.

## #6 — Don't use a FlexiPage for CustomApplication UIBundle apps

Apps opened via the `c__<AppName>` URL are served directly by the CustomApplication's `<uiBundle>` field — no FlexiPage needed. Deploying a FlexiPage with UIBundle components fails: `Property 'componentInstances' not valid in version 67.0`. (A FlexiPage is only for embedding a UIBundle component inside a record/home page — a different use case.)

## #7 — NamedCredential required fields in v67.0

The `<name>` element is invalid (API name comes from the filename). Required fields are `<endpoint>` and `<principalType>`. Missing either causes a cryptic deploy failure.

## #8 — `sourceApiVersion` must be `67.0`

`67.0` is the Summer '26 GA version. `68.0` returns "Invalid version specified" (as of 2026). Projects inherited from earlier may be on `66.0` — bump to `67.0`. On a release newer than Summer '26, verify the current version against the org before assuming `68.0` still fails.

## #9 — Never call the Salesforce REST API from Apex with a Lightning session ID

Lightning UI session IDs (`UserInfo.getSessionId()` in a UI context) are browser-scoped and return `INVALID_SESSION_ID` (401) as a Bearer token — even inside a Queueable with `Database.AllowsCallouts`.

For Flow-only standard platform actions (some actions can't be called via `Invocable.Action.createStandardAction()` — error "isn't a valid action type"), create an AutoLaunched Flow that calls the action and invoke it from Apex:
```apex
Map<String, Object> inputs = new Map<String, Object>{
    'DecisionTableApiName' => 'My_Decision_Table'
};
Flow.Interview interview = Flow.Interview.createInterview('RefreshMyDecisionTable', inputs);
interview.start();
String errorMessage = (String) interview.getVariableValue('ErrorMessage');
```
CRITICAL: add a `<faultConnector>` capturing `{!$Flow.FaultMessage}` into an output variable — otherwise failures only send admin emails and the message is the useless "An unhandled fault has occurred." Do all DML AFTER `interview.start()`, never before. For genuine external callouts (Jira, Zendesk, etc.) use a Named Credential with OAuth 2.0, not a session ID.

## #10 — Flow-only table actions need the DeveloperName, not the display label

Parameters like `DecisionTableApiName` must be the sObject **DeveloperName** (e.g. `My_Decision_Table`), NOT the SetupName display label (e.g. "My Decision Table"). Wrong name → "The decision table API Name is invalid." Verify:
```bash
sf data query --query "SELECT DeveloperName, SetupName FROM DecisionTable ORDER BY DeveloperName" --target-org <alias>
```

## #11 — App Launcher only works on the `.salesforce.app` domain

On `lightning.force.com` the app shows "No Items" / "doesn't have any navigation items" — that's the wrong domain, not a bug. Open UIBundle apps from `.salesforce.app` (see visibility-chain.md for URL patterns).

## #12 — Beta → GA (Summer '26) breaking changes

Multi-Framework went GA in Summer '26 (production-ready, no opt-in, all org types). An app scaffolded against the beta needs these five changes:

1. **SDK import path:** Salesforce's own beta→GA migration guidance says `@salesforce/sdk-data` → `@salesforce/platform-sdk`. **In practice, prefer `@salesforce/sdk-data`** — it's the package used by every proven working reference app this skill has actually verified, it's actively maintained (current releases track the same version line as `@salesforce/ui-bundle`/`@salesforce/vite-plugin-ui-bundle`), and it produces a smaller bundle (no analytics/o11y chunk). **Note:** the CSRF-handshake 401 in gotcha #16 hits *both* packages identically — it's baked in at build time by `@salesforce/vite-plugin-ui-bundle`, upstream of either SDK's own code, so switching packages was never going to fix it (confirmed empirically: reverting from `platform-sdk` to `sdk-data` hit the exact same wrong version). Prefer `sdk-data` for the reasons above, not because it avoids #16 — nothing avoids #16 except setting `orgAlias`.
2. **GraphQL API split:** the single `graphql()` call is now **`.query()`** (reads) and **`.mutate()`** (writes).
3. **Optional-chain results:** `result?.data` — `data` can now be `undefined`; guard it.
4. **UIBundle metadata target:** `<target>AppLauncher</target>` → **`<target>CustomApplication</target>`**. (This boilerplate already ships the GA-correct value — see gotcha #5.)
5. **Remove** the deprecated `UiBundleSettings` scratch-org configuration.

Fresh scaffolds via the current `@salesforce/plugin-uibundle` CLI already emit the GA shape — this list is only for migrating an existing beta app.

## #13 — App renders but every data call 401s → it's an ENTITLEMENT, not code

The single most expensive trap. The app deploys, loads on `.salesforce.app`, shows "Logged in as …" — but **every** call to `/services/apexrest/*` (or the Data SDK) returns **401 Unauthorized**, usually alongside a `GET /services/data/v50.0/ui-api/session/csrf` **404** (a stale API version). It looks exactly like a data-layer / auth-header bug, so you'll burn hours swapping SDKs and fetch patterns. **Don't.**

**Root cause:** the *running user* lacks the **Agentforce entitlement** to run a Multi-Framework app with an authenticated session. Multi-Framework is on the Agentforce 360 platform, so without the entitlement the platform **refuses to mint a session** for the app — and the 401 + `v50` CSRF 404 are just symptoms of "no session provisioned." Being a System Administrator is **not** enough.

**Fix:** assign the user a permission set backed by the **Agentforce Platform Developer and Admin** PSL — the standard **`AgentforceDeveloperAndAdminTools`** permission set. That PSL ships **200,000 seats** (effectively free), so there's no license wall for it.
```bash
sf org assign permset --name AgentforceDeveloperAndAdminTools --target-org <alias>
```
The 401 and CSRF 404 clear **immediately** on the next reload — no code change, no redeploy.

**Proof it's not code:** the exact same `sdk.fetch` code that 401'd before the assignment works after it — at least in the org (`suakhil`) this was originally diagnosed in. (A plain global `fetch()` 401s regardless — the SDK's authenticated fetch is still required; see the Data access section in SKILL.md.)

**⚠️⚠️ FINAL CORRECTION (2026-07-29) — read this, not the two corrections below it.** Everything past this point in the PP2 incident (the package swap, the `basePath` workaround, the `AppFrameworkPsl` finding in #14, the stale-cache finding in #15) was chasing symptoms of **gotcha #16** — a build-time bug that bakes the wrong org's API version into the bundle, independent of SDK package, entitlement, or cache. None of those intermediate fixes were the actual answer; #16 was. If you're reading this gotcha because of a persistent 401, **skip straight to #16** and only come back here if it genuinely doesn't apply (both PSLs really do matter for a *first-time* deploy to a new org — just not for this specific symptom once #16 is ruled out).

**Diagnose fast:** compare the *working* user's permission sets against the *failing* user's — the delta is the Agentforce entitlement:
```bash
sf data query --query "SELECT PermissionSet.Name FROM PermissionSetAssignment WHERE Assignee.Username='<user>'" --target-org <alias>
```

**Red-herring warning:** trying to assign the perm set may throw *"All Agentforce (Default) permission set licenses are in use."* That error is usually from a **different** perm set in the same assign batch (e.g. `GenieAdmin`, which needs a maxed license) — NOT from `AgentforceDeveloperAndAdminTools`. Confirm the specific PSL a perm set needs and its seat count before assuming you're out of licenses:
```bash
# PermissionSet.LicenseId → the required PermissionSetLicense; check its seats
sf data query --query "SELECT Name, LicenseId FROM PermissionSet WHERE Name='AgentforceDeveloperAndAdminTools'" --target-org <alias>
sf data query --query "SELECT MasterLabel, TotalLicenses, UsedLicenses FROM PermissionSetLicense WHERE Id='<LicenseId>'" --target-org <alias>
```

## #14 — `AgentforceDeveloperAndAdminTools` alone isn't always enough — also check `AppFrameworkPsl`

Found 2026-07-28: a user already correctly entitled with `AgentforceDeveloperAndAdminTools` (verified assigned, PSL active with plenty of seats) still got a persistent 401 on every data call, in an org where the app had never been opened before by anyone. Comparing the same user's permission sets in a working org (where the app had been used before) against the failing org surfaced a second, separate permission set: **`AppFrameworkPsl`** (label "App Framework") — present and assignable in both orgs, but only actually *assigned* in the working one.

```bash
sf org assign permset --name AppFrameworkPsl --target-org <alias>
```

The 401 is the same symptom as gotcha #13 (Agentforce entitlement missing), so it's easy to stop diagnosing once `AgentforceDeveloperAndAdminTools` checks out — don't. If the 401 persists after confirming that permset is assigned and correct, check for `AppFrameworkPsl` too before assuming something else is wrong. Diagnose the same way as #13: compare a working user/org's full permission set list against the failing one — the delta names the gap directly, faster than guessing.

**Not yet confirmed:** whether `AppFrameworkPsl` is required in every org, or only some (parallel to how gotcha #13's Agentforce PSL provisioning itself varies per sandbox). Treat both #13 and #14 as "check this too" rather than a fixed two-step checklist until this is verified across more orgs.

**⚠️⚠️ FINAL CORRECTION (2026-07-29):** the actual root cause of the 401 in this incident was **gotcha #16** (build baked in the wrong org's API version), not this. The `AppFrameworkPsl` finding is still real and worth having assigned (a genuine, separately-verified license requirement for a first-time deploy to a new org), but it did not cause and was not the fix for this particular 401 — check #16 first for that symptom.

## #15 — Persistent 401 after a redeploy: check for a stale cached bundle before touching permissions

**The tell:** you redeploy the UIBundle (new code, new content-hashed JS/CSS filenames), reload the app, and it *still* shows the old UI/old behavior — not just old data, the actual old interface. If the rendered page doesn't reflect your latest change, the browser never loaded your new `index.html`/bundle at all, and no amount of server-side permission work will fix what you're seeing.

**Root cause:** `index.html` (and the browser's cache of it) references the built JS/CSS by content-hashed filename. If the browser has a cached copy of the old `index.html`, every reload keeps requesting the old hash — which may 404 or, worse, still resolve if the old asset wasn't cleaned up — regardless of what's actually deployed org-side. A normal reload (or even what looks like a hard reload) doesn't always bypass this on the `.salesforce.app` domain.

**Why this is easy to misdiagnose as gotcha #13/#14:** the symptom is identical — "renders, but every data call 401s." If the OLD bundle used a plain `fetch()` instead of the SDK's authenticated `sdk.fetch` (or any other code that's since been fixed in source), you'll see the exact same 401 pattern as a genuine entitlement gap, even after the entitlement is fixed — because the browser is still running the pre-fix code.

**Fix:**
1. Force a true cache bypass — an actual hard refresh (Cmd+Shift+R / Ctrl+Shift+R), or open the app in a private/incognito window, or clear site data for the `.salesforce.app` origin.
2. Confirm you're now running the new bundle: check the Network tab for the JS asset filename and compare it to what's in the deployed `dist/assets/` folder.
3. Only escalate to #13/#14 (permission/entitlement troubleshooting) if the 401 survives a *confirmed* fresh bundle load.

**Diagnostic note for AI agents without browser access:** if you can't inspect the Network tab yourself, you can't tell #13/#14 apart from #15 by symptom alone — server-side checks (permission sets, licenses) can all come back clean while the real problem is sitting in the user's browser cache. Ask the user to try a hard refresh or incognito window *before* spending time on permission-set archaeology; it's the cheaper test and rules out a whole category of false leads.

**⚠️⚠️ FINAL CORRECTION (2026-07-29):** in the incident that produced this gotcha, cache genuinely was part of the picture (the browser really was serving a stale bundle at one point) — but even after a confirmed fresh bundle load, the 401 persisted, because the real cause was **gotcha #16**. Rule out #16 first; it's a build-time bug that no amount of browser-side cache-clearing can fix.

## #16 — THE 401 ROOT CAUSE: the build bakes in the wrong org's API version if `orgAlias` isn't set

**Check this FIRST for any persistent 401, before #13/#14/#15.** It's the actual answer behind all three of those gotchas' original incidents — a multi-hour debugging saga that swapped SDK packages, added `basePath` overrides, chased entitlements, and cleared caches, none of which could have worked, because the real bug was never in the app's code, the SDK choice, or the user's permissions at all.

**The mechanism:** `@salesforce/vite-plugin-ui-bundle` (the `salesforce()` plugin in `vite.config.ts`) bakes a Salesforce API version into the build as a compile-time constant (`__SF_API_VERSION__`). It gets that version by calling `@salesforce/core`'s `Org.create({ aliasOrUsername: options.orgAlias })` — and **if `orgAlias` isn't passed to the plugin, that call becomes `Org.create({})`, which resolves to whatever org is the *local machine's* CLI global default target-org** (`sf config get target-org`, falling through to `~/.sf/config.json` if the project has no local `.sf/config.json` of its own). That has nothing to do with which org you're actually deploying to. If your global default happens to be some other org — a scratch org, a Trailhead/orgfarm practice org, anything — that org's own (possibly long-stale, cached-at-authentication-time) API version gets baked into the bundle instead.

That stale version then breaks the Data SDK's internal CSRF/session handshake specifically — the handshake URL is built from this baked-in version, not from anything in `globalThis.SFDC_ENV`, so it 404s against your real target org regardless of entitlement, SDK package (`@salesforce/sdk-data` and `@salesforce/platform-sdk` both hit this identically — it's the same build plugin baking in the same wrong constant either way), or cache state. Every real REST/GraphQL call your own code makes then 401s, because the SDK never got a valid session token from that broken handshake.

**Symptom:** a `GET .../services/data/vNN.0/ui-api/session/csrf` **404**, where `NN` doesn't match your target org's actual API version (classically something implausibly old, like `50.0`, when your org is on `67.0`) — followed by 401 on every real data call. Renders fine; only data calls fail. Looks identical to gotchas #13/#14/#15.

**Diagnose fast — don't guess, get the plugin to tell you:**
```ts
// vite.config.ts — temporarily, for diagnosis only
salesforce({ debug: true }),
```
```bash
npm run build 2>&1 | grep -i "api version"
# [ui-bundle-plugin] Using Salesforce API version: 50.0   <- if this doesn't match your target org, you're in this gotcha
```
If you need to know *which* org it resolved to (not just the version), temporarily patch the installed plugin to also log `orgInfo` (it's not exposed as a public option) — find the `if (options.debug)` block in `node_modules/@salesforce/vite-plugin-ui-bundle/dist/index.js` and add a line logging `JSON.stringify(orgInfo)` right after the existing debug log. `orgInfo.username`/`orgInfo.instanceUrl` will tell you exactly which org it grabbed. Revert the patch (`rm -rf node_modules/@salesforce/vite-plugin-ui-bundle && npm install`) once you've confirmed it — it's not something to commit.

**Fix — pin the org explicitly, don't rely on machine state:**
```ts
// vite.config.ts
salesforce({ orgAlias: 'your-target-org-alias' }),
```
This is **not optional, and not just for this incident** — without it, the build's correctness silently depends on whatever org happens to be the *building machine's* global CLI default at build time, which is mutable, unrelated to the project, and can differ between your machine, a teammate's machine, and CI. Every UIBundle project should set this in `vite.config.ts` at scaffold time, not discover it's missing after a debugging marathon.

**Verify the fix actually landed before deploying** (don't just trust `debug: true`'s console output — confirm the literal is really in the compiled artifact you're about to ship):
```bash
npm run build
grep -o 'v67\.0' dist/assets/*.js   # or your target org's actual API version
# Absence of output, or a DIFFERENT version showing up, means it didn't take.
```

**Why the reference apps (this boilerplate's own proven examples) never hit this:** they either had their own local `.sf/config.json` pinning the right org, or the building machine's global default happened to already be correct at the time they were last built — not because they were somehow immune. Don't assume "it works elsewhere" means the plugin call itself was safe; check whether `orgAlias` was actually set explicitly before trusting a reference app as proof this gotcha doesn't apply.
