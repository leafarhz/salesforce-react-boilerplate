# Deployment Runbook

Deploy in this exact order. Out-of-order deploys cause hard-to-diagnose failures.
`<alias>` = your target org alias. Replace `MyApp` with your app's DeveloperName.

Since Summer '26 GA, `<alias>` can be a **production** org as well as a sandbox/scratch org — the sequence is identical. The creation-only `<uiBundle>` caveat (step 2 / gotcha #1) applies **per org**, so the first CustomApplication deploy into production must also be a create, not an update.

## Before every build — verify the baked-in org (see gotcha #16)

**Do this before step 1, every time, not just once.** The build bakes a Salesforce API version into the bundle from whatever org `vite.config.ts`'s `salesforce({ orgAlias: ... })` resolves — if that's missing or wrong, the app renders fine but every data call 401s, and no amount of permission/entitlement/cache troubleshooting will fix it (it's a build-time bug, not a runtime one).

```bash
grep orgAlias force-app/main/default/uiBundles/MyApp/vite.config.ts
# Must show your actual target org's alias, e.g. orgAlias: 'preprod2' — a bare
# salesforce() with no orgAlias resolves to the BUILDING MACHINE's global CLI
# default target-org instead, unrelated to <alias> below.

npm run build
grep -o 'v67\.0' force-app/main/default/uiBundles/MyApp/dist/assets/*.js
# (replace 67.0 with your target org's real API version) - no output, or a
# different version, means the wrong org got baked in. Fix vite.config.ts
# and rebuild before deploying anything.
```

## First-time deploy

```bash
# 1 — UIBundle (React build)
sf project deploy start --source-dir force-app/main/default/uiBundles/MyApp --target-org <alias>

# 2 — CustomApplication (FIRST TIME ONLY — see gotchas.md #1)
sf project deploy start --source-dir force-app/main/default/applications/MyApp.app-meta.xml --target-org <alias>

# VERIFY the <uiBundle> field survived (never skip):
sf project retrieve start --metadata "CustomApplication:MyApp" --target-org <alias>
grep uiBundle force-app/main/default/applications/MyApp.app-meta.xml
# No output = the field was stripped → see gotchas.md #1 (destructive re-deploy).

# 3 — Objects and fields
sf project deploy start --source-dir force-app/main/default/objects --target-org <alias>

# 4 — Apex classes
sf project deploy start --source-dir force-app/main/default/classes --target-org <alias>

# 5 — Permission Set
sf project deploy start --source-dir force-app/main/default/permissionsets/MyApp_Admin.permissionset-meta.xml --target-org <alias>

# 6 — Assign the Permission Set
sf org assign permset --name MyApp_Admin --target-org <alias>

# 7 — Open the org, then navigate to the .salesforce.app URL (see visibility-chain.md)
sf org open --target-org <alias>
```

## Changing the `<uiBundle>` field after initial deploy

`<uiBundle>` is creation-only. To change it you must delete and recreate the app:

```bash
# 1 — Delete the app from the org
sf project deploy start \
  --manifest destructive/package.xml \
  --post-destructive-changes destructive/destructiveChanges.xml \
  --target-org <alias>

# 2 — Redeploy fresh (uiBundle sticks this time)
sf project deploy start --source-dir force-app/main/default/applications/MyApp.app-meta.xml --target-org <alias>

# 3 — Verify
sf project retrieve start --metadata "CustomApplication:MyApp" --target-org <alias>
grep uiBundle force-app/main/default/applications/MyApp.app-meta.xml
```

## Debugging commands

```bash
# List UIBundles / CustomApplications in the org
sf org list metadata --metadata-type UIBundle --target-org <alias>
sf org list metadata --metadata-type CustomApplication --target-org <alias>

# Inspect the UIBundle via Tooling API (does NOT overwrite local files)
sf data query --use-tooling-api \
  --query "SELECT Id, DeveloperName, MasterLabel, Target, IsActive FROM UIBundle" \
  --target-org <alias>

# Check permission-set assignment
sf data query \
  --query "SELECT PermissionSet.Name FROM PermissionSetAssignment WHERE Assignee.Username = '<user>'" \
  --target-org <alias>

# List a custom object's fields (confirm what's really in the org)
sf data query \
  --query "SELECT QualifiedApiName FROM FieldDefinition WHERE EntityDefinition.QualifiedApiName = 'MyObject__c' ORDER BY QualifiedApiName" \
  --target-org <alias>
```
