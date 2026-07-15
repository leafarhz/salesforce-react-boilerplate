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
