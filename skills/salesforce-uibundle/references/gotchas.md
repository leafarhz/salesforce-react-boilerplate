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
| App **renders** but every data call is **401** (often + a `.../ui-api/session/csrf` **404** on a stale API version) | #13 (user lacks the Agentforce entitlement — NOT a code bug); if that checks out, also try #14 (`AppFrameworkPsl`) |

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

1. **SDK import path:** `@salesforce/sdk-data` → **`@salesforce/platform-sdk`**.
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

**Proof it's not code:** the exact same `sdk.fetch` code that 401'd before the assignment works after it. `sdk.fetch` from **either** `@salesforce/sdk-data` or `@salesforce/platform-sdk` works once entitled. (A plain global `fetch()` 401s regardless — the SDK's authenticated fetch is still required; see the Data access section in SKILL.md.)

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
