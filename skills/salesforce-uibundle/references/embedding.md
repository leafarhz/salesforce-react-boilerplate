# Embedding a UIBundle on a Record Page (Microfrontends)

A UIBundle app doesn't have to live only in the App Launcher. Salesforce **Microfrontends (UI Embedding)** let a thin LWC host your React app inside a Lightning record, app or home page, in a sandboxed iframe, with a typed channel for props, events, theme and resize.

- **Status (late 2026):** embedding *externally hosted* apps is GA. Embedding your own **Salesforce-hosted UIBundle** (served from `*.salesforce.app`) is **Beta**, with GA targeted for mid-November 2026. Re-check the release notes; some details below may change at GA.
- **Best working reference:** Salesforce's own [trailheadapps/multiframework-recipes](https://github.com/trailheadapps/multiframework-recipes). The `microfrontend-recipes/` folder holds the host LWCs, and `react-recipes/.../src/recipes/embedding/` holds the React guests. The developer guide at `developer.salesforce.com/docs/platform/microfrontend` returns **403 to automated fetches** (WebFetch, curl), so an agent should read the recipes repo instead.

The proven setup has four parts:

```
Lightning record page
  └─ host LWC (myAppHost)  ── <lightning-ui-embedding src=… props=…>  ── iframe ──►  your UIBundle (React guest)
        ▲  calls Apex                                                                 │
        └──────────────── apprequest event (guest → host) ◄───────────────────────────┘
                          appresponse event (host → guest) ─────────────────────────►
```

## 1. Guest (the React app)

**Use `@salesforce/platform-sdk` 12.x (verified with 12.3.3).** 10.x has no `./ui-embedding` entry point, and without it the embedding can never connect (gotcha #17). This is the one case where `platform-sdk` is required over `sdk-data`.

```bash
npm install --save-exact @salesforce/platform-sdk@12.3.3 @salesforce/ui-bundle@12.3.3
npm install --save-dev --save-exact @salesforce/vite-plugin-ui-bundle@12.3.3
```

**Bootstrap: this import must run before anything else** (first line of `main.tsx`). It registers the listener that catches the host's handshake. If it's missing or late, the host never reveals the frame. It's harmless when the app is opened full-page.

```tsx
// src/main.tsx
import '@salesforce/platform-sdk/ui-embedding';

import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import { App } from './App';

createRoot(document.getElementById('root')!).render(<StrictMode><App /></StrictMode>);
```

**An embedded guest has no direct org data access.** Data comes either as host **props** or as **events** the host answers. Keep one thin module for both modes, so the same app also works full-page:

```ts
// src/host.ts
import { getViewSDK, isSfEmbeddingIframe, type ViewSDK } from '@salesforce/platform-sdk';

export const embedded: boolean = (() => { try { return isSfEmbeddingIframe(); } catch { return false; } })();
const view = (): Promise<ViewSDK | null> => getViewSDK().catch(() => null);

/** Record Id from host props (embedded) or ?recordId= (full page). Returns an unsubscribe. */
export function watchRecordId(onChange: (id: string | null) => void): () => void {
  if (!embedded) { onChange(new URLSearchParams(location.search).get('recordId')); return () => undefined; }
  let unsubscribe: (() => void) | undefined;
  let cancelled = false;
  const read = (p?: Record<string, unknown>) => onChange(typeof p?.recordId === 'string' ? p.recordId : null);
  void view().then((sdk) => {
    if (cancelled || !sdk?.getUiState) return;
    const ui = sdk.getUiState();
    read(ui.state.props);
    unsubscribe = ui.subscribe((next) => read(next.props));
  });
  return () => { cancelled = true; unsubscribe?.(); };
}

type Response = { id: number; ok: boolean; data?: unknown; error?: string };
const pending = new Map<number, (r: Response) => void>();
let seq = 0;
let listening: Promise<ViewSDK> | null = null;

function listen(): Promise<ViewSDK> {
  listening ??= view().then((sdk) => {
    if (!sdk?.addEventListener || !sdk.dispatchEvent) throw new Error('The page did not connect to the app.');
    sdk.addEventListener('appresponse', (e: Event) => {
      const r = (e as CustomEvent<Response>).detail;
      if (r && pending.has(r.id)) { pending.get(r.id)!(r); pending.delete(r.id); }
    });
    return sdk;
  });
  return listening;
}

/** Ask the host LWC to run an Apex action; resolves with its answer. */
export async function askHost<T>(action: string, payload: Record<string, unknown> = {}): Promise<T> {
  const sdk = await listen();
  const id = ++seq;
  return new Promise<T>((resolve, reject) => {
    const timer = setTimeout(() => { pending.delete(id); reject(new Error('The page did not answer in time.')); }, 120_000);
    pending.set(id, (r) => { clearTimeout(timer); r.ok ? resolve(r.data as T) : reject(new Error(r.error || 'Request failed.')); });
    sdk.dispatchEvent!(new CustomEvent('apprequest', { detail: { id, action, payload }, bubbles: true }));
  });
}
```

```ts
// src/api.ts: one entry point, two transports
import { createDataSDK } from '@salesforce/platform-sdk';
import { askHost, embedded } from './host';

async function rest<T>(path: string, body: unknown): Promise<T> {
  const sdk = await createDataSDK();
  const res = await sdk.fetch!(`/services/apexrest/MyApp/${path}`, {
    method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body),
  });
  const json = await res.json();
  if (!res.ok) throw new Error(json?.error ?? `Request failed (${res.status})`);
  return json as T;
}

export const ping = (recordId: string | null) =>
  embedded ? askHost<{ ok: boolean }>('ping', { recordId }) : rest<{ ok: boolean }>('ping', { recordId });
```

Other guest notes:
- **Resize is automatic.** The SDK watches `document.body` and reports height changes; `viewSDK.resize(w, h)` is only for overrides. Don't add your own ResizeObserver that fights it.
- **Navigation:** a relative `/lightning/r/...` link resolves against `*.salesforce.app` and 404s. Send an event (for example `appnavigate`) and let the host use `NavigationMixin`.
- **Event names:** use lowercase with no dots or hyphens (`apprequest`, `appresponse`), because the host binds them declaratively as `on<eventname>`.

## 2. Host LWC

Scaffold it with the CLI, then adapt it. The template is `boilerplate/force-app/main/default/lwc/myAppHost/`.

```bash
sf template generate ui-embedding --name MyAppHost --src https://placeholder.example \
  --sandbox allow-popups --shell-title "My App" -d force-app/main/default/lwc
```

What the boilerplate host does, and why:
- **`sandbox="allow-popups"`,** as in the recipes. The component adds the tokens it needs itself.
- **`src` is computed from `window.location`** (`*.lightning.force.com` → `*--c.my.salesforce.app/app/c__MyApp`), so one component works in every sandbox and in production. An optional `appUrl` App Builder property overrides it. `src` is session-binding: it can't be changed on a live element.
- **`props` is a getter that returns a fresh object** each time, so changes are forwarded. Pass **plain JSON**; Apex results are read-only proxies that can't cross the frame, so run them through `JSON.parse(JSON.stringify(...))`.
- **It listens for `sf-embedding.component.ready` and `sf-embedding.component.error`** on `this.template`, in `connectedCallback`, because the error can fire before the first render. Until ready it shows a spinner. On error it shows `{ phase, code, message }` instead of a blank box. This is what turns "blank panel" into a diagnosable error.
- **It answers `apprequest`** by calling `@AuraEnabled` Apex and dispatching `appresponse` on the embedding element: `this.refs.embedding.dispatchEvent(new CustomEvent('appresponse', { detail }))`.
- **CSS `height: auto` on the embedding** overrides its default `height: 100%`, so the auto-resize can grow the panel.

Place it on the record page in App Builder like any LWC. Use a component visibility rule such as `$Permission.CustomPermission.MyApp_Access` for convenience only; the real gate belongs in the Apex (see section 4).

## 3. Org setup

1. **CustomApplication with `<uiBundle>c__MyApp</uiBundle>`.** Without it the bundle has no `/app/c__MyApp` URL ("Page doesn't exist"), embedded or not. It's creation-only (gotcha #1): verify with a retrieve **into a separate folder** so your local file isn't overwritten (gotcha #2).
2. **Two Trusted URLs (CSP), both with `frame-src`:** `https://*.salesforce.app` and `https://*.lightning.force.com`. The second covers the session hand-off the frame makes through the Lightning domain. Templates are in `boilerplate/force-app/main/default/cspTrustedSites/`.
3. **A permission set** with `applicationVisibilities` for the app, `classAccesses` for the host's Apex controller (and the REST class if you have a full-page mode), plus the object access the Apex checks for.

Deploy order: the UIBundle, then the CustomApplication (and verify `<uiBundle>`), then Apex, the host LWC, the Trusted URLs and the permission set. Then place the host on the page. **Validate with tests before deploying to a shared sandbox:** `sf project deploy validate`, then `sf project deploy quick --job-id …`.

## 4. Server-side guardrails (learned the hard way)

- **The Apex must check access itself.** Code that reads records in system mode (the default for Apex) will happily return data the user can't otherwise see. Check the custom permission **and** `Schema.SObjectType.MyObject__c.isAccessible()` at the top of every `@AuraEnabled` / REST entry point.
- **Batch org-wide work per request.** One "check the last 50 records" request that re-runs real business logic used **97 of 100 SOQL queries**. Triggers and flows on touched records count too. Send batches of about 10 per request from the guest and add up the results there. Each request gets fresh governor limits.
- **Simulations: use a savepoint and roll back.** To show what a change *would* do, run the real logic inside `Database.setSavepoint()` and `Database.rollback(sp)` in a `finally`. That means no records, feed posts or emails are left behind. Notifications fire on commit, so they never go out.
- **`AuraHandledException.getMessage()` is generic** ("Script-thrown exception") unless you call `setMessage(msg)`. Do that if REST callers need the real text.

## 5. UX guardrails ("don't let it become a doorbell")

- **Live preview with a debounce** (about 600 ms after a control stops moving) makes tuning feel immediate, but give **feedback for every run**: a spinner while it runs, then "✓ Updated at 3:21 PM: X → Y (▼5)". Also flash the changed cards. Otherwise users click again because "nothing happened".
- **Cache results by the exact inputs** (`JSON.stringify` of the settings and the record). The same question is never sent twice; the button reads "Up to date ✓". Returning to earlier inputs shows that result instantly.
- **Long work:** show progress ("20 of 50"), offer **Stop** (checked between batches), disable the conflicting buttons, pause auto-preview, and add a short cooldown (about 5 s) so a double-click can't queue a second run.

## 6. Troubleshooting

| Symptom | Likely cause |
| --- | --- |
| Blank space where the panel should be; the space may even resize, but no content shows | The handshake never completed: `@salesforce/platform-sdk` < 12 or the `ui-embedding` import isn't first (gotcha #17). The host's `sf-embedding.component.error` detail says which. |
| Full-page `/app/c__MyApp` → "Page doesn't exist" | No CustomApplication with `<uiBundle>`, or the field was stripped (gotchas #1 and #18) |
| Works full-page, empty or blocked when embedded | Missing Trusted URLs `*.salesforce.app` / `*.lightning.force.com` with frame-src (gotcha #19) |
| Embedded app loads but every data call fails | It called Apex/GraphQL directly. Embedded guests must go through the host (gotcha #20). |
| `System.LimitException: Too many SOQL queries: 101` on a bulk action | Batch per request (gotcha #21) |
| Copied `node_modules` from another bundle and the build or SDK resolution is broken | Symlinked packages don't copy cleanly. Delete it and run `npm install` (gotcha #22). |
| `document.querySelectorAll('iframe')` finds nothing in the console | Expected: the frame lives in a closed component. Use the host's ready/error events, the Network tab (filter on your app name), or the console's context dropdown. |
| A plain `/lightning/...` link inside the app 404s | It resolved against `*.salesforce.app`. Navigate through the host. |
