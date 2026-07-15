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

`68.0` returns "Invalid version specified" (as of 2026). Projects inherited from earlier may be on `66.0` — bump to `67.0`.

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
