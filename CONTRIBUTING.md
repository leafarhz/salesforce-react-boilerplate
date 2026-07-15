# Contributing

Thanks for helping improve the Salesforce React UIBundle skill + boilerplate! Contributions of new gotchas, deployment fixes, and boilerplate improvements are very welcome.

## Ground rules

Please read [`CLAUDE.md`](CLAUDE.md) first — it documents the conventions this repo depends on. The important ones:

1. **Salesforce API version is `67.0` everywhere.** `68.0` returns "Invalid version specified." It may appear in prose *warning against* its use, but never as a version value in any `.json`/`.xml`.
2. **No employer/internal identifiers.** This is a public repo. Use neutral placeholders only: `MyApp`, `MyObject__c` / `MyCustomObject__c`, `MyField__c`, `My_Decision_Table`, `RefreshMyDecisionTable`. Strip any real app names, project codenames, team names, or decision-table API names before opening a PR.
3. **Keep the skill lean.** `skills/salesforce-uibundle/SKILL.md` is a short entry point; put detail in `references/*.md` (progressive disclosure). Change the `description:` frontmatter deliberately — it drives auto-triggering.
4. **Boilerplate must stay self-consistent** for copy-paste use: the CustomApplication `<uiBundle>` must match the UIBundle DeveloperName, and the permission set's `classAccesses` must reference a class that actually ships.
5. **Semver:** bump `version` in *both* `plugin.json` and `marketplace.json` together.

## Development

Install the SF CLI UIBundle plugin if you're testing deploys:

```bash
sf plugins install @salesforce/plugin-uibundle
```

Test the plugin locally without installing from the marketplace:

```bash
claude --plugin-dir ./
```

## Before you open a PR

Run the verification gates — all must pass:

```bash
# Plugin/marketplace schema
claude plugin validate ./
jq empty .claude-plugin/plugin.json .claude-plugin/marketplace.json

# No internal identifiers anywhere (expect no output)
grep -rinE 'IL Engineering|Imagine Learning' --exclude-dir=.git .

# No 68.0 as a config version value (expect no output)
grep -rnE '68\.0' --include='*.json' --include='*.xml' --exclude-dir=.git .
```

## PR flow

1. Fork and branch from `main` (e.g. `feat/new-gotcha`, `fix/permission-set`).
2. Make focused commits with clear messages.
3. Ensure the gates above pass.
4. Open a PR describing what changed and why. If you're adding a gotcha, include the symptom (error text) and the fix so it slots into `references/gotchas.md`'s symptom index.

## Reporting issues

Use the issue templates — a **Deployment gotcha / bug** report (with the exact error string and org type) or a **Feature / coverage request**. The more concrete the symptom, the faster it becomes a documented fix.
