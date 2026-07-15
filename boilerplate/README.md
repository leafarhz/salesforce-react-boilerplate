# Salesforce React UIBundle — Boilerplate & Lessons Learned

**Rafael Hernandez · 2026**

This is a copy-paste starting point for any new Salesforce React UIBundle (Multi-Framework) app.
All gotchas below were discovered the hard way deploying real UIBundle apps.

---

## Quick Start

1. Copy this folder and rename `MyApp` to your app's DeveloperName everywhere (case-sensitive).
2. Build your React app inside `force-app/main/default/uiBundles/MyApp/` using the Salesforce UIBundle CLI.
3. Follow the deploy order in **Deployment Runbook** below.
4. Access the app at the correct URL (see **The URL** section).

---

## The URL (not what you think)

UIBundle apps do NOT live on `lightning.force.com` or `my.salesforce.com`. They live on a completely different domain:

| Org Type | URL Pattern |
|----------|-------------|
| Sandbox  | `https://<myDomain>--<sandbox>--c.sandbox.my.salesforce.app/app/c__<AppApiName>` |
| Scratch  | `https://<domain>--c.scratch.my.salesforce.app/app/c__<AppApiName>` |
| Prod     | `https://<myDomain>--c.my.salesforce.app/app/c__<AppApiName>` |

The app only appears in App Launcher when you're on the `.salesforce.app` domain. If you're on `lightning.force.com` you'll either see "No Items" or the app won't appear at all — that's expected, not a bug.

---

## Deployment Runbook

Follow this order exactly. Deploying out of order causes hard-to-diagnose failures.

### Step 1 — Deploy the UIBundle (React build)

```bash
sf project deploy start --source-dir force-app/main/default/uiBundles/MyApp --target-org <alias>
```

### Step 2 — Deploy the CustomApplication (FIRST TIME ONLY)

```bash
sf project deploy start --source-dir force-app/main/default/applications/MyApp.app-meta.xml --target-org <alias>
```

**Verify the `<uiBundle>` field survived** (do not skip this):
```bash
sf project retrieve start --metadata "CustomApplication:MyApp" --target-org <alias>
grep uiBundle force-app/main/default/applications/MyApp.app-meta.xml
```
If the field is missing, see **Gotcha #1** below.

### Step 3 — Deploy objects and fields

```bash
sf project deploy start --source-dir force-app/main/default/objects --target-org <alias>
```

### Step 4 — Deploy Apex classes

```bash
sf project deploy start --source-dir force-app/main/default/classes --target-org <alias>
```

### Step 5 — Deploy the Permission Set

```bash
sf project deploy start --source-dir force-app/main/default/permissionsets/MyApp_Admin.permissionset-meta.xml --target-org <alias>
```

### Step 6 — Assign the Permission Set

```bash
sf org assign permset --name MyApp_Admin --target-org <alias>
```

### Step 7 — Open the app

```bash
sf org open --target-org <alias>
# Then navigate manually to the .salesforce.app URL
```

---

## How to Re-deploy the CustomApplication (after initial deploy)

For everything EXCEPT `<uiBundle>`, you can update normally. For the `<uiBundle>` field itself, if you ever need to change it:

```bash
# 1. Delete the app from the org
sf project deploy start \
  --manifest destructive/package.xml \
  --post-destructive-changes destructive/destructiveChanges.xml \
  --target-org <alias>

# 2. Redeploy fresh — uiBundle will stick this time
sf project deploy start \
  --source-dir force-app/main/default/applications/MyApp.app-meta.xml \
  --target-org <alias>

# 3. Verify
sf project retrieve start --metadata "CustomApplication:MyApp" --target-org <alias>
grep uiBundle force-app/main/default/applications/MyApp.app-meta.xml
```

---

## Lessons Learned (The Hard Way)

### Gotcha #1 — `<uiBundle>` is creation-only and silently stripped

This is the #1 time sink. If a CustomApplication already exists in the org without `<uiBundle>`, you cannot add it via a deploy update. Salesforce accepts the deploy (shows "State: Changed") but silently drops the field. The only fix is to delete the CustomApplication from the org and recreate it.

**How to check if you're in this situation:**
```bash
sf project retrieve start --metadata "CustomApplication:MyApp" --target-org <alias>
grep uiBundle force-app/main/default/applications/MyApp.app-meta.xml
# If no output → you're in this situation
```

**Fix:** Use the destructive deploy in `destructive/` (see runbook above).

---

### Gotcha #2 — `sf project retrieve start` overwrites your local files

If your local `MyApp.app-meta.xml` has `<uiBundle>` but the org doesn't (because it was stripped), running a retrieve overwrites your local file to match the org — silently deleting your fix.

**Rule:** When your local metadata intentionally differs from the org, inspect the org with Tooling API instead of retrieve:
```bash
sf data query --use-tooling-api \
  --query "SELECT Id, DeveloperName FROM UIBundle WHERE DeveloperName = 'MyApp'" \
  --target-org <alias>
```

---

### Gotcha #3 — Object permission ≠ field access (FLS is separate)

Even with `allowRead: true` on an object, users cannot see any custom fields until you add explicit `<fieldPermissions>` entries in the permission set. The error looks like:

```
Error 500: No such column 'MyField__c' on entity 'MyObject__c'
```

This same error fires for BOTH missing fields AND missing FLS — making it confusing.

**Fix:** Add a `<fieldPermissions>` block for every non-required custom field the app queries.

**Find required fields (exclude these from the PS):**
```bash
grep -l "<required>true</required>" force-app/main/default/objects/MyObject__c/fields/*.field-meta.xml
```

---

### Gotcha #4 — Required fields cannot appear in Permission Set fieldPermissions

If you add `<fieldPermissions>` for a required field, the deploy fails:
```
You cannot deploy to a required field: MyObject__c.MyField__c
```

Required fields are always accessible — they don't need (and can't have) explicit FLS. Remove them from the PS.

---

### Gotcha #5 — `<target>CustomApplication</target>` in uibundle-meta.xml IS valid

Some Salesforce docs imply this element doesn't exist. It does. It's required for the UIBundle to be linkable from a CustomApplication. Without it, the connection may not work depending on API version.

---

### Gotcha #6 — Don't use a FlexiPage for CustomApplication UIBundle apps

UIBundle apps accessed via the `c__<AppName>` URL pattern are served directly by the CustomApplication's `<uiBundle>` field — no FlexiPage needed. A FlexiPage is for embedding a UIBundle component inside a Lightning record page or home page, which is a different use case.

If you try to deploy a FlexiPage with UIBundle components, it will fail with:
```
Property 'componentInstances' not valid in version 67.0
```

---

### Gotcha #7 — NamedCredential required fields in v67.0

The `<name>` element is invalid in NamedCredential metadata (the API name comes from the filename). Required fields are `<endpoint>` and `<principalType>`. Missing either causes a failed deploy with cryptic errors.

---

### Gotcha #8 — `sourceApiVersion` must be `67.0`

As of June 2026, version `68.0` is not yet supported and returns "Invalid version specified." Keep `sfdx-project.json` at `67.0`. Projects inherited from before this date may be on `66.0` — bump them to `67.0`.

---

### Gotcha #9 — Never call the Salesforce REST API from Apex using a session ID

If your app needs to call a Salesforce platform API, do NOT pass the Lightning session ID to a Queueable and use it as a Bearer token. Lightning UI session IDs are scoped to the browser and are rejected by the REST API with `INVALID_SESSION_ID`.

**Right approach for Salesforce platform actions — use `Flow.Interview`:**

Some standard Salesforce actions (like `refreshDecisionTable`) are **Flow-only** — they cannot be called from `Invocable.Action.createStandardAction()` in Apex. The error is "XYZ isn't a valid action type." The workaround is to create an AutoLaunched Flow that calls the action, then invoke that Flow from Apex via `Flow.Interview`:

```apex
// Works for Flow-only standard actions (e.g. refreshDecisionTable)
Map<String, Object> inputs = new Map<String, Object>{
    'DecisionTableApiName' => 'My_Decision_Table'
};
Flow.Interview interview = Flow.Interview.createInterview('RefreshMyDecisionTable', inputs);
interview.start();
String errorMessage = (String) interview.getVariableValue('ErrorMessage');
```

**CRITICAL — always add a `<faultConnector>` to the Flow:**

Without a fault connector, any action failure sends admin error emails AND the exception message is just "An unhandled fault has occurred in this flow" — useless for debugging. Add a fault handler that captures `{!$Flow.FaultMessage}` into an output variable:

```xml
<actionCalls>
    <name>Refresh_Decision_Table</name>
    <actionName>refreshDecisionTable</actionName>
    <actionType>refreshDecisionTable</actionType>
    <faultConnector>
        <targetReference>Capture_Fault_Message</targetReference>
    </faultConnector>
    ...
</actionCalls>
<assignments>
    <name>Capture_Fault_Message</name>
    <assignmentItems>
        <assignToReference>ErrorMessage</assignToReference>
        <operator>Assign</operator>
        <value><elementReference>$Flow.FaultMessage</elementReference></value>
    </assignmentItems>
</assignments>
```

**DML must come AFTER all work** — no DML before any `interview.start()` calls.

If a callout to an **external** system is genuinely needed (Jira, Zendesk, etc.), use a proper Named Credential with OAuth 2.0 — not a session ID.

---

### Gotcha #10 — `refreshDecisionTable` requires the DeveloperName, not the display name

The `DecisionTableApiName` parameter must be the **DeveloperName** field from the `DecisionTable` sObject (e.g. `My_Decision_Table`), not the SetupName display label (e.g. "My Decision Table"). Always verify with:

```bash
sf data query --query "SELECT DeveloperName, SetupName FROM DecisionTable ORDER BY DeveloperName" --target-org <alias>
```

Using the wrong name returns "The decision table API Name is invalid" for every table.

---

### Gotcha #11 — App Launcher only works on `.salesforce.app` domain

If you're on `lightning.force.com` and the UIBundle app shows "This app doesn't have any navigation items" — that's not a bug, it's the wrong domain. UIBundle apps must be opened from the `.salesforce.app` domain.

---

## Debugging Commands

```bash
# List UIBundles in org
sf org list metadata --metadata-type UIBundle --target-org <alias>

# List CustomApplications in org
sf org list metadata --metadata-type CustomApplication --target-org <alias>

# Check UIBundle details via Tooling API
sf data query --use-tooling-api \
  --query "SELECT Id, DeveloperName, MasterLabel, Target, IsActive FROM UIBundle" \
  --target-org <alias>

# Check PS assignment
sf data query \
  --query "SELECT PermissionSet.Name FROM PermissionSetAssignment WHERE Assignee.Username = '<user>'" \
  --target-org <alias>

# List all fields on a custom object (check what's actually in org)
sf data query \
  --query "SELECT QualifiedApiName FROM FieldDefinition WHERE EntityDefinition.QualifiedApiName = 'MyObject__c' ORDER BY QualifiedApiName" \
  --target-org <alias>
```

---

## File Structure Reference

```
sf-uibundle-boilerplate/
├── sfdx-project.json                          # sourceApiVersion: 67.0
├── destructive/
│   ├── package.xml                            # Empty package for destructive deploys
│   └── destructiveChanges.xml                 # Delete CustomApplication (edit before use)
└── force-app/main/default/
    ├── applications/
    │   └── MyApp.app-meta.xml                 # CustomApplication with <uiBundle> field
    ├── uiBundles/
    │   └── MyApp/
    │       ├── MyApp.uibundle-meta.xml        # UIBundle with <target>CustomApplication</target>
    │       └── src/                           # Your React source goes here
    ├── permissionsets/
    │   └── MyApp_Admin.permissionset-meta.xml # Includes app visibility + FLS
    └── namedCredentials/
        └── SalesforceInternal.namedCredential-meta.xml
```

---

## References

- Salesforce UIBundle CLI: `@salesforce/plugin-uibundle`
- Sample project to reverse-engineer from: `@salesforce/ui-bundle-template-base-sfdx-project`
