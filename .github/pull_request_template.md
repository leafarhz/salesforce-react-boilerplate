<!-- Thanks for contributing! Keep changes focused. See CONTRIBUTING.md. -->

## What & why

<!-- What does this change and why? Link any related issue (#123). -->

## Type

- [ ] New / corrected gotcha
- [ ] Boilerplate fix or addition
- [ ] Skill / docs improvement
- [ ] Plugin / marketplace metadata

## Checklist

- [ ] `claude plugin validate ./` passes
- [ ] `jq empty .claude-plugin/plugin.json .claude-plugin/marketplace.json` passes
- [ ] No internal/employer identifiers — neutral placeholders only (`MyApp`, `MyObject__c`, …)
- [ ] No `68.0` as a version value in any `.json`/`.xml` (API stays `67.0`)
- [ ] If content changed, `SKILL.md` stays lean and detail lives in `references/*.md`
- [ ] `version` bumped in **both** `plugin.json` and `marketplace.json` (if releasing)
