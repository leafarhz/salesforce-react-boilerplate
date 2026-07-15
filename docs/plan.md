# Salesforce React Boilerplate — Skill + Plugin Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship `leafarhz/salesforce-react-boilerplate` as an installable Claude Code plugin containing a full-lifecycle Salesforce React UIBundle skill plus the proven, genericized SFDX boilerplate.

**Architecture:** One public repo that is simultaneously (a) a single-plugin Claude Code marketplace, (b) the plugin, and (c) the boilerplate. The plugin exposes one skill, `salesforce-uibundle`, whose lean `SKILL.md` routes to three reference docs. The boilerplate files are copied from the proven `rafaimaginelearning/sf-uibundle-boilerplate` repo and stripped of all internal org identifiers.

**Tech Stack:** Claude Code plugin format (`.claude-plugin/plugin.json` + `marketplace.json`), Markdown skills, SFDX metadata (API v67.0), Apex.

## Global Constraints

- **Salesforce API version is `67.0` everywhere** — `68.0` returns "Invalid version specified" (as of 2026). Never write 68.0.
- **No internal org identifiers anywhere in the published repo.** All real app names, project codenames, team names, and decision-table API names from the source org have been stripped. Examples use neutral placeholders only: `MyApp`, `MyObject__c`, `MyField__c`, `My_Decision_Table`, `RefreshMyDecisionTable`.
- **Plugin name:** `salesforce-react-boilerplate`. **Marketplace name:** `leafarhz-plugins`. **Skill directory:** `skills/salesforce-uibundle/`. **Skill invocation:** `/salesforce-react-boilerplate:salesforce-uibundle`.
- **Starting version:** `0.1.0` (semver).
- **Author:** name `Rafael Hernandez`, GitHub `leafarhz`. **License:** MIT (already in repo).
- **Branching:** all tasks land on branch `feat/skill-and-plugin` off `main`; open a PR at the end. Commit after every task.
- **Working directory:** `~/Documents/GitHome/SalesforceReactBoilerPlate` (repo root). All paths below are relative to it.

## File Structure

- Create: `.claude-plugin/plugin.json` — plugin manifest (name, version, author, metadata).
- Create: `.claude-plugin/marketplace.json` — single-plugin marketplace pointing at repo root.
- Create: `skills/salesforce-uibundle/SKILL.md` — skill entry point (frontmatter + lifecycle routing).
- Create: `skills/salesforce-uibundle/references/deployment-runbook.md` — ordered deploy + destructive re-deploy.
- Create: `skills/salesforce-uibundle/references/gotchas.md` — symptom-indexed gotchas.
- Create: `skills/salesforce-uibundle/references/visibility-chain.md` — UIBundle→Tab→App→PS + domain URLs.
- Create: `boilerplate/*` — 8 files copied from source repo, genericized.
- Modify: `README.md` — correct install commands + repo status.

---

### Task 1: Feature branch + plugin & marketplace manifests

**Files:**
- Create: `.claude-plugin/plugin.json`
- Create: `.claude-plugin/marketplace.json`

**Interfaces:**
- Produces: plugin name `salesforce-react-boilerplate`, marketplace name `leafarhz-plugins`. All later tasks live inside this plugin; the skill in Task 4 is discovered under `skills/`.

- [ ] **Step 1: Create the feature branch**

Run:
```bash
cd ~/Documents/GitHome/SalesforceReactBoilerPlate
git checkout main && git pull -q origin main
git checkout -b feat/skill-and-plugin
```

- [ ] **Step 2: Write `.claude-plugin/plugin.json`**

```json
{
  "name": "salesforce-react-boilerplate",
  "displayName": "Salesforce React UIBundle Kit",
  "version": "0.1.0",
  "description": "Full-lifecycle guide and boilerplate for building Salesforce React UIBundle (Multi-Framework) apps — scaffold, deploy, make visible, and debug the known gotchas.",
  "author": {
    "name": "Rafael Hernandez",
    "url": "https://github.com/leafarhz"
  },
  "homepage": "https://github.com/leafarhz/salesforce-react-boilerplate",
  "repository": "https://github.com/leafarhz/salesforce-react-boilerplate",
  "license": "MIT",
  "keywords": ["salesforce", "react", "uibundle", "multi-framework", "sfdx"]
}
```

- [ ] **Step 3: Write `.claude-plugin/marketplace.json`**

```json
{
  "name": "leafarhz-plugins",
  "owner": {
    "name": "Rafael Hernandez",
    "url": "https://github.com/leafarhz"
  },
  "description": "Rafael Hernandez's Claude Code plugins.",
  "plugins": [
    {
      "name": "salesforce-react-boilerplate",
      "source": "./",
      "description": "Full-lifecycle guide and boilerplate for building Salesforce React UIBundle (Multi-Framework) apps.",
      "version": "0.1.0",
      "author": { "name": "Rafael Hernandez" }
    }
  ]
}
```

- [ ] **Step 4: Validate the JSON is well-formed**

Run:
```bash
jq empty .claude-plugin/plugin.json && jq empty .claude-plugin/marketplace.json && echo "JSON OK"
```
Expected: prints `JSON OK` with no jq errors.

- [ ] **Step 5: Validate the plugin (if the CLI supports it)**

Run:
```bash
claude plugin validate ./ 2>&1 || echo "validate command unavailable — skipping (JSON check above is sufficient)"
```
Expected: either a validation success message, or the fallback line. A non-zero from a *found* validator that reports a real schema error must be fixed before commit.

- [ ] **Step 6: Commit**

```bash
git add .claude-plugin/plugin.json .claude-plugin/marketplace.json
git commit -m "feat: add plugin and marketplace manifests

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 2: Import and genericize the boilerplate

**Files:**
- Create: `boilerplate/README.md`
- Create: `boilerplate/sfdx-project.json`
- Create: `boilerplate/destructive/package.xml`
- Create: `boilerplate/destructive/destructiveChanges.xml`
- Create: `boilerplate/force-app/main/default/applications/MyApp.app-meta.xml`
- Create: `boilerplate/force-app/main/default/uiBundles/MyApp/MyApp.uibundle-meta.xml`
- Create: `boilerplate/force-app/main/default/permissionsets/MyApp_Admin.permissionset-meta.xml`
- Create: `boilerplate/force-app/main/default/classes/MyAppSyncQueueable.cls`
- Create: `boilerplate/force-app/main/default/namedCredentials/SalesforceInternal.namedCredential-meta.xml`

**Interfaces:**
- Consumes: nothing.
- Produces: a self-contained `boilerplate/` directory the skill (Task 4) instructs users to copy. Placeholder names are `MyApp`, `MyObject__c` / `MyCustomObject__c`, `MyField__c`, `My_Decision_Table`.

- [ ] **Step 1: Fetch the source files verbatim into `boilerplate/`**

Run (uses `gh`, authenticated as leafarhz):
```bash
cd ~/Documents/GitHome/SalesforceReactBoilerPlate
SRC=rafaimaginelearning/sf-uibundle-boilerplate
mkdir -p boilerplate/destructive \
  boilerplate/force-app/main/default/applications \
  boilerplate/force-app/main/default/uiBundles/MyApp \
  boilerplate/force-app/main/default/permissionsets \
  boilerplate/force-app/main/default/classes \
  boilerplate/force-app/main/default/namedCredentials
fetch() { gh api "repos/$SRC/contents/$1" --jq '.content' | base64 -d > "boilerplate/$2"; }
fetch README.md README.md
fetch sfdx-project.json sfdx-project.json
fetch destructive/package.xml destructive/package.xml
fetch destructive/destructiveChanges.xml destructive/destructiveChanges.xml
fetch force-app/main/default/applications/MyApp.app-meta.xml force-app/main/default/applications/MyApp.app-meta.xml
fetch force-app/main/default/uiBundles/MyApp/MyApp.uibundle-meta.xml force-app/main/default/uiBundles/MyApp/MyApp.uibundle-meta.xml
fetch force-app/main/default/permissionsets/MyApp_Admin.permissionset-meta.xml force-app/main/default/permissionsets/MyApp_Admin.permissionset-meta.xml
fetch force-app/main/default/classes/MyAppSyncQueueable.cls force-app/main/default/classes/MyAppSyncQueueable.cls
fetch force-app/main/default/namedCredentials/SalesforceInternal.namedCredential-meta.xml force-app/main/default/namedCredentials/SalesforceInternal.namedCredential-meta.xml
echo "fetched $(find boilerplate -type f | wc -l | tr -d ' ') files"
```
Expected: `fetched 9 files`.

- [ ] **Step 2: Write the failing check — no internal identifiers**

Run:
```bash
grep -rinE '<FORBIDDEN_PATTERN>' boilerplate/ && echo "FOUND INTERNAL IDENTIFIERS (must be zero)"
```
Expected: matches ARE printed (the source README and the `.cls` comments contain internal identifiers from the source org). This confirms the check works and shows exactly what to fix.

- [ ] **Step 3: Genericize `boilerplate/README.md`**

Apply these exact edits to `boilerplate/README.md`:
- Replace the internal team byline with `**Rafael Hernandez · 2026**`.
- Replace the internal-app-specific gotcha summary with `All gotchas below were discovered the hard way deploying real UIBundle apps.`
- In the Gotcha #9 Apex example, replace the internal decision-table API name with `'My_Decision_Table'` and the internal flow name with `'RefreshMyDecisionTable'`.
- In Gotcha #10, replace internal decision-table references with `My_Decision_Table` and `"My Decision Table"`, and remove the pricing-specific SOQL filter so it reads `FROM DecisionTable ORDER BY DeveloperName`.
- In the References section, delete the entire line referencing internal org examples.

- [ ] **Step 4: Genericize `boilerplate/force-app/main/default/classes/MyAppSyncQueueable.cls`**

Apply this exact edit to the `.cls` file:
- Replace the internal decision-table API name in the header comment (appears twice) with `My_Decision_Table` (the code body already uses generic names — leave those).
- Replace the internal decision-table display label with `"My Decision Table"`.

- [ ] **Step 5: Run the check to verify it now passes**

Run:
```bash
grep -rinE '<FORBIDDEN_PATTERN>' boilerplate/ ; echo "exit=$?"
```
Expected: no matches printed and `exit=1` (grep found nothing).

- [ ] **Step 6: Verify API version and XML are intact**

Run:
```bash
grep -R '68.0' boilerplate/ ; echo "68-check-exit=$?"
grep -c '67.0' boilerplate/sfdx-project.json
```
Expected: first `echo` prints `68-check-exit=1` (no 68.0 anywhere); second prints `1` (67.0 present in sfdx-project.json).

- [ ] **Step 7: Commit**

```bash
git add boilerplate/
git commit -m "feat: add genericized SFDX boilerplate

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 3: Reference docs (deployment-runbook, gotchas, visibility-chain)

**Files:**
- Create: `skills/salesforce-uibundle/references/deployment-runbook.md`
- Create: `skills/salesforce-uibundle/references/gotchas.md`
- Create: `skills/salesforce-uibundle/references/visibility-chain.md`

**Interfaces:**
- Consumes: the `boilerplate/` file layout from Task 2 (paths referenced in commands).
- Produces: three docs `SKILL.md` (Task 4) links to by relative path `references/<name>.md`.

- [ ] **Step 1: Write `deployment-runbook.md`**

```markdown
# Deployment Runbook

Deploy in this exact order. Out-of-order deploys cause hard-to-diagnose failures.
`<alias>` = your target org alias. Replace `MyApp` with your app's DeveloperName.

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
```

- [ ] **Step 2: Write `gotchas.md`** (symptom-first; genericized)

```markdown
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
```

- [ ] **Step 3: Write `visibility-chain.md`**

```markdown
# Making a UIBundle App Visible

Deploying a UIBundle does NOT surface it. Visibility requires the full chain plus the right domain.

## The chain

```
UIBundle  →  CustomApplication (<uiBundle> field)  →  Permission Set  →  assign to user
```

Unlike a classic Lightning app, a UIBundle app served via the `c__<AppName>` URL does NOT need a Custom Tab or FlexiPage — the CustomApplication's `<uiBundle>` field serves the React app directly. The Permission Set must grant:

- `applicationVisibilities` — the app is visible in App Launcher.
- `classAccesses` — every Apex class the React app invokes.
- `objectPermissions` — read (and CRUD as needed) on every object the app queries.
- `fieldPermissions` — every non-required custom field the app reads (object read does NOT imply field access — see gotchas.md #3).

Then: `sf org assign permset --name MyApp_Admin --target-org <alias>`.

If `assign permset` fails, check for a missing Permission Set License first.

## The URL (not what the docs say)

UIBundle apps live on `*.salesforce.app`, NOT `lightning.force.com` or `my.salesforce.com`:

| Org Type | URL Pattern |
| --- | --- |
| Sandbox | `https://<myDomain>--<sandbox>--c.sandbox.my.salesforce.app/app/c__<AppApiName>` |
| Scratch | `https://<domain>--c.scratch.my.salesforce.app/app/c__<AppApiName>` |
| Production | `https://<myDomain>--c.my.salesforce.app/app/c__<AppApiName>` |

The app only appears in App Launcher on the `.salesforce.app` domain. On `lightning.force.com` you'll see "No Items" — expected, not a bug (gotchas.md #11).
```

- [ ] **Step 4: Verify no internal identifiers and no 68.0**

Run:
```bash
grep -rinE '<FORBIDDEN_PATTERN>' skills/ ; echo "exit=$?"
```
Expected: no matches, `exit=1`.

- [ ] **Step 5: Commit**

```bash
git add skills/salesforce-uibundle/references/
git commit -m "docs: add genericized skill reference docs

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 4: The skill entry point (`SKILL.md`)

**Files:**
- Create: `skills/salesforce-uibundle/SKILL.md`

**Interfaces:**
- Consumes: the three `references/*.md` files from Task 3 (linked by relative path) and the `boilerplate/` directory from Task 2.
- Produces: the auto-discovered skill for the plugin; invocation `/salesforce-react-boilerplate:salesforce-uibundle`.

- [ ] **Step 1: Write `SKILL.md`**

```markdown
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
```

- [ ] **Step 2: Verify the frontmatter parses and required keys exist**

Run:
```bash
head -5 skills/salesforce-uibundle/SKILL.md
awk '/^---$/{c++} c==1 && /^name:/{n=1} c==1 && /^description:/{d=1} END{exit (n&&d)?0:1}' skills/salesforce-uibundle/SKILL.md && echo "frontmatter OK (name + description present)"
```
Expected: prints the frontmatter and `frontmatter OK (name + description present)`.

- [ ] **Step 3: Verify reference links resolve to real files**

Run:
```bash
cd skills/salesforce-uibundle
for f in references/deployment-runbook.md references/visibility-chain.md references/gotchas.md; do
  test -f "$f" && echo "OK $f" || echo "MISSING $f"
done
cd - >/dev/null
```
Expected: three `OK` lines, no `MISSING`.

- [ ] **Step 4: Re-validate the plugin**

Run:
```bash
jq empty .claude-plugin/plugin.json && echo "manifest OK"
claude plugin validate ./ 2>&1 || echo "validate command unavailable — skipping"
```
Expected: `manifest OK`, plus validator success or the fallback line.

- [ ] **Step 5: Commit**

```bash
git add skills/salesforce-uibundle/SKILL.md
git commit -m "feat: add salesforce-uibundle skill entry point

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 5: Finalize README install instructions + open PR

**Files:**
- Modify: `README.md`

**Interfaces:**
- Consumes: plugin name `salesforce-react-boilerplate` and marketplace name `leafarhz-plugins` from Task 1.

- [ ] **Step 1: Fix the install commands in `README.md`**

In `README.md`, replace the entire "As a Claude Code plugin (recommended)" fenced block with:
````markdown
```
/plugin marketplace add leafarhz/salesforce-react-boilerplate
/plugin install salesforce-react-boilerplate@leafarhz-plugins
```
````
The skill then invokes automatically on relevant tasks, or explicitly via `/salesforce-react-boilerplate:salesforce-uibundle`.

- [ ] **Step 2: Update the "Status" line**

In `README.md`, replace the Status section body `Early — scaffolding in progress. See \`docs/\` for the design.` with `Working plugin: one skill (\`salesforce-uibundle\`) + boilerplate. See \`docs/design.md\` for the design and \`docs/plan.md\` for the build plan.`

- [ ] **Step 3: Final full-repo identifier + version sweep**

Run:
```bash
grep -rinE '<FORBIDDEN_PATTERN>' --exclude-dir=.git . ; echo "identifiers-exit=$?"
grep -rn '68\.0' --exclude-dir=.git . ; echo "v68-exit=$?"
```
Expected: both print `...-exit=1` (no matches).

- [ ] **Step 4: Commit**

```bash
git add README.md
git commit -m "docs: finalize README install instructions

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

- [ ] **Step 5: Push and open the PR**

```bash
git push -u origin feat/skill-and-plugin
gh pr create --base main --head feat/skill-and-plugin \
  --title "Add UIBundle skill + plugin + boilerplate" \
  --body "Implements docs/plan.md: plugin & marketplace manifests, genericized boilerplate, three reference docs, and the salesforce-uibundle skill.

🤖 Generated with [Claude Code](https://claude.com/claude-code)"
```
Expected: prints the new PR URL.

---

## Notes for the implementer

- `claude plugin validate` may not exist in every CLI build; the `jq empty` JSON checks are the required gate, the validator is a bonus.
- Do not edit anything under the internal org path (`OneDrive-ImagineLearning/…`). All work is in `~/Documents/GitHome/SalesforceReactBoilerPlate`.
- If `sf`/`objects` directories don't exist in a consuming project, that's fine — the boilerplate intentionally ships no `objects/`; step 3 of the runbook is a no-op when a project has no custom objects.
```
