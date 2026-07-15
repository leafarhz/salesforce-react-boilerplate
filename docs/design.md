# salesforce-react-boilerplate — Design

**Date:** 2026-07-15
**Author:** Rafael Hernandez (with Claude)
**Status:** Approved design, pending implementation plan

## Purpose

Package hard-won Salesforce React UIBundle (Multi-Framework) knowledge as a reusable, public **Claude skill** so that starting a new UIBundle project no longer means rediscovering the same gotchas by hand. The skill guides Claude through the full lifecycle — scaffold → deploy → make visible → debug — and ships with proven metadata boilerplate in the same repo.

This is a **public, community** project. It must not carry internal org identifiers; content distilled from internal notes is genericized before publishing.

## Repository & account

- **GitHub repo:** `leafarhz/salesforce-react-boilerplate` (public)
- **Owner account:** `leafarhz` (personal GitHub, NOT an internal org account)
- **Local path:** `~/Documents/GitHome/SalesforceReactBoilerPlate` (outside any OneDrive-ImagineLearning sync)
- **Default branch:** `main`

## Decisions (locked during brainstorming)

1. **One repo, skill + boilerplate together** — a single clone gets everything; the skill points at the local `boilerplate/` directory.
2. **Full lifecycle guide** — the skill covers scaffold, deploy, make-visible, debug.
3. **Both distribution paths** — installable as a Claude Code plugin/marketplace AND documented for manual copy into `.claude/skills/`.
4. **Boilerplate sourced from the existing proven repo** — files copied from `github.com/rafaimaginelearning/sf-uibundle-boilerplate`, then cleaned/genericized for public release.

## Layout

```
salesforce-react-boilerplate/
├── README.md                         # what it is; both install paths
├── LICENSE                           # MIT
├── .gitignore
├── .claude-plugin/
│   ├── marketplace.json              # single-plugin marketplace manifest
│   └── plugin.json                   # plugin manifest (name, version, skills path)
├── skills/
│   └── salesforce-uibundle/
│       ├── SKILL.md                  # full-lifecycle guide (entry point)
│       └── references/
│           ├── deployment-runbook.md # ordered 7-step deploy
│           ├── gotchas.md            # the gotchas, symptom-indexed
│           └── visibility-chain.md   # UIBundle → Tab → App → Permission Set
├── boilerplate/
│   ├── README.md
│   ├── sfdx-project.json             # sourceApiVersion 67.0
│   ├── destructive/
│   │   ├── package.xml
│   │   └── destructiveChanges.xml
│   └── force-app/main/default/
│       ├── applications/MyApp.app-meta.xml
│       ├── classes/MyAppSyncQueueable.cls
│       ├── namedCredentials/SalesforceInternal.namedCredential-meta.xml
│       ├── permissionsets/MyApp_Admin.permissionset-meta.xml
│       └── uiBundles/MyApp/MyApp.uibundle-meta.xml
└── docs/
    └── design.md                     # this file
```

The repo doubles as its own single-plugin marketplace so both install paths work:
- **Plugin:** `/plugin marketplace add leafarhz/salesforce-react-boilerplate` → install.
- **Manual:** clone and copy `skills/salesforce-uibundle/` into a project or user `.claude/skills/`.

## Component: the skill (`SKILL.md`)

Progressive-disclosure design — a lean `SKILL.md` entry point that routes to focused `references/` files. The `description:` frontmatter is tuned to trigger on: "Salesforce React app," "UIBundle," "Multi-Framework," "deploy React to Salesforce," "app not showing in App Launcher."

### Lifecycle flow the skill directs Claude through

1. **Scaffold**
   - Copy `boilerplate/` into the target project.
   - Rename every `MyApp` reference → chosen DeveloperName (case-sensitive, everywhere).
   - Confirm `sourceApiVersion: 67.0` (68.0 is rejected; bump 66.0 → 67.0 if inherited).
   - Generate the React app inside `force-app/main/default/uiBundles/<App>/` via the Salesforce UIBundle CLI (`@salesforce/plugin-uibundle`). The boilerplate carries only the `.uibundle-meta.xml`, not React source — the CLI generates the app.

2. **Deploy** → `references/deployment-runbook.md`
   - The ordered 7-step deploy (UIBundle → CustomApplication → objects → classes → permission set → assign → open).
   - Mandatory `<uiBundle>` survival check via retrieve + grep after the CustomApplication deploy.

3. **Make visible** → `references/visibility-chain.md`
   - UIBundle → Custom Tab → Lightning App (`navItems`) → Permission Set (`tabSettings` + `applicationVisibilities` + `classAccesses` + object/field perms) → `sf org assign permset`.
   - The `.salesforce.app` domain URL patterns (sandbox / scratch / production).

4. **Debug** → `references/gotchas.md`
   - Symptom-indexed lookup into the gotchas (e.g., "App shows 'No Items'" → wrong domain; "field access broken" → FLS separate from object perms).

### Reference files

- **`deployment-runbook.md`** — the exact ordered CLI sequence, plus the destructive delete-and-recreate path for changing `<uiBundle>`.
- **`gotchas.md`** — the gotchas, framed symptom-first so Claude can jump from an error message to the fix. **Genericized** — no internal project/decision-table/app names.
- **`visibility-chain.md`** — the full visibility chain and `.salesforce.app` domain rules.

## Content source & genericization

- **Boilerplate files:** copied from `rafaimaginelearning/sf-uibundle-boilerplate` (confirmed present: `README.md`, `sfdx-project.json`, `destructive/*`, and five `force-app` metadata files), then reviewed for any internal specifics.
- **Reference docs:** distilled from internal notes. **All internal org identifiers are stripped** before publishing — no real app names, project codenames, or decision-table API names. Examples in the docs use neutral placeholders (`MyApp`, `MyObject__c`, `My_Decision_Table`).

## Distribution details

- **Plugin manifests:** `.claude-plugin/plugin.json` (plugin definition) and `.claude-plugin/marketplace.json` (single-plugin marketplace pointing at this repo).
- **Schema caveat:** the exact `plugin.json` / `marketplace.json` schema will be verified against current Claude Code documentation during implementation rather than trusted from memory — the plugin format is relatively new. This is an explicit implementation step.

## Out of scope (YAGNI)

- Migrating/mirroring the boilerplate out of the `rafaimaginelearning` org.
- Bundling actual React app source in the boilerplate (the CLI generates it).
- Production deploy support (Multi-Framework is sandbox/scratch only in this Beta).

## Success criteria

- A public `leafarhz/salesforce-react-boilerplate` repo exists with the layout above.
- The skill installs via the marketplace command AND via manual copy.
- Invoking the skill on a new project reproduces scaffold → deploy → make-visible → debug without the human re-deriving the gotchas.
- No internal org identifiers appear anywhere in the published repo.
