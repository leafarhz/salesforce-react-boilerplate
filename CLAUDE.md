# CLAUDE.md — salesforce-react-boilerplate

Context for working in this repo with Claude Code.

## What this repo is

A **public Claude Code plugin** (MIT) that packages the full-lifecycle workflow for building **Salesforce React UIBundle (Multi-Framework)** apps — a Salesforce feature introduced Spring '26 that lets you build native React apps deployed to the App Launcher. The repo is simultaneously:

1. a **marketplace** (`.claude-plugin/marketplace.json`, name `leafarhz-plugins`),
2. a **plugin** (`.claude-plugin/plugin.json`, name `salesforce-react-boilerplate`),
3. a **skill** (`skills/salesforce-uibundle/`), and
4. the **boilerplate** it references (`boilerplate/`).

Install: `/plugin marketplace add leafarhz/salesforce-react-boilerplate` → `/plugin install salesforce-react-boilerplate@leafarhz-plugins`.
Invoke the skill explicitly with `/salesforce-react-boilerplate:salesforce-uibundle` (it also auto-triggers on UIBundle tasks).

## Layout

```
.claude-plugin/{plugin.json, marketplace.json}   # plugin + single-plugin marketplace
skills/salesforce-uibundle/
  SKILL.md                                        # lean entry point; routes to references/
  references/{deployment-runbook, gotchas, visibility-chain}.md
boilerplate/                                      # 9 SFDX metadata files, genericized (API v67.0)
docs/{design.md, plan.md}                         # how this repo was designed + built
```

## Conventions (do not break)

- **Salesforce API version is `67.0` everywhere.** `68.0` returns "Invalid version specified." It may appear in prose *warning against* its use (gotcha #8), but never as a version value in any `.json`/`.xml`.
- **No internal/employer identifiers, ever.** This is a public repo. The knowledge was distilled and **genericized** from private work — examples use neutral placeholders only: `MyApp`, `MyObject__c` / `MyCustomObject__c`, `MyField__c`, `My_Decision_Table`, `RefreshMyDecisionTable`. Before publishing any content sourced from internal notes, strip real app names, project codenames, team names, and decision-table API names.
- **Skill design is progressive disclosure:** keep `SKILL.md` short and route detail into `references/*.md`. The `description:` frontmatter is tuned for auto-triggering — change it deliberately.
- **Boilerplate must stay self-consistent** for copy-paste use: the CustomApplication `<uiBundle>c__MyApp</uiBundle>` must match the UIBundle DeveloperName, and the permission set's `classAccesses` must reference the class that actually ships (`MyAppSyncQueueable`).
- **Semver.** Bump `version` in *both* `plugin.json` and `marketplace.json` together.

## Verifying changes

```bash
claude plugin validate ./                         # plugin/marketplace schema
jq empty .claude-plugin/plugin.json .claude-plugin/marketplace.json
# No internal identifiers anywhere (expect no output / exit 1):
grep -rinE 'PricingSyncUtility|IL Engineering|Imagine Learning' --exclude-dir=.git .
# No 68.0 as a config version value (expect no output):
grep -rnE '68\.0' --include='*.json' --include='*.xml' --exclude-dir=.git .
```

## Provenance

Built 2026-07-15 via brainstorm → spec (`docs/design.md`) → plan (`docs/plan.md`) → subagent-driven implementation with per-task + whole-branch review. The UIBundle knowledge originated from real deployments; this repo is the public, genericized home of it.
