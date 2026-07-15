# salesforce-react-boilerplate

A Claude skill **and** boilerplate for building **Salesforce React UIBundle (Multi-Framework)** apps — the full lifecycle, from scaffold to a visible, working app in the App Launcher, with the hard-won gotchas baked in.

Multi-Framework (Beta, TDX 2026) lets you build native React apps that deploy to the Salesforce App Launcher. It is powerful but under-documented — the deploy order, the `.salesforce.app` domain, the creation-only `<uiBundle>` field, and FLS-vs-object-permission traps cost real hours the first time. This repo captures that so you (and Claude) don't rediscover it.

## What's in here

| Path | What it is |
| --- | --- |
| `skills/salesforce-uibundle/` | The Claude skill — full-lifecycle guide + symptom-indexed gotchas |
| `boilerplate/` | Proven SFDX metadata scaffolding (CustomApplication, UIBundle, Permission Set, etc.) |
| `.claude-plugin/` | Plugin + marketplace manifests for one-command install |
| `docs/` | Design spec and background |

## Install the skill

**As a Claude Code plugin (recommended):**

```
/plugin marketplace add leafarhz/salesforce-react-boilerplate
/plugin install salesforce-uibundle
```

**Manually:**

Clone this repo and copy the skill into your project or user skills directory:

```shell
git clone https://github.com/leafarhz/salesforce-react-boilerplate
cp -R salesforce-react-boilerplate/skills/salesforce-uibundle ~/.claude/skills/
```

## Status

Early — scaffolding in progress. See `docs/` for the design.

## License

MIT — see [LICENSE](LICENSE).
