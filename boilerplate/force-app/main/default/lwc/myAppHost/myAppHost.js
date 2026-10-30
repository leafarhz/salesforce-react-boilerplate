/**
 * BOILERPLATE: host LWC that embeds the MyApp UIBundle on a Lightning record page with <lightning-ui-embedding>.
 * Pattern from trailheadapps/multiframework-recipes (microfrontend-recipes). See skills/.../references/embedding.md.
 *
 * - src: the UIBundle is served from the org's *.salesforce.app domain; worked out from the Lightning host so the
 *   same component works in every org (override with the appUrl App Builder property).
 * - props: a fresh plain object on every read, so changes reach the guest via viewSDK.getUiState().
 * - Data: an embedded guest has no direct org data access. It sends `apprequest` events; this host calls Apex and
 *   answers with an `appresponse` event on the embedding element.
 * - Lifecycle: a spinner until sf-embedding.component.ready, the reason on sf-embedding.component.error.
 *
 * REPLACE: MyApp / myAppHost / MyAppEmbedController → your names.
 */
import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import handleRequest from '@salesforce/apex/MyAppEmbedController.handleRequest';

const APP = 'c__MyApp';
const READY_EVENT = 'sf-embedding.component.ready';
const ERROR_EVENT = 'sf-embedding.component.error';

export default class MyAppHost extends NavigationMixin(LightningElement) {
    @api recordId;
    @api appUrl; // optional override, e.g. https://<myDomain>--c.my.salesforce.app/app/c__MyApp
    loading = true;
    error;

    onReady = () => {
        this.loading = false;
    };

    onError = (event) => {
        const { phase, code, message } = event.detail || {};
        this.error = { phase, code, message };
        this.loading = false;
    };

    connectedCallback() {
        // the error can fire while the embedding mounts (before renderedCallback); both events are composed
        this.template.addEventListener(READY_EVENT, this.onReady);
        this.template.addEventListener(ERROR_EVENT, this.onError);
    }

    disconnectedCallback() {
        this.template.removeEventListener(READY_EVENT, this.onReady);
        this.template.removeEventListener(ERROR_EVENT, this.onError);
    }

    get embeddingUrl() {
        if (this.appUrl) return this.appUrl;
        const host = window.location.hostname;
        let appHost = host;
        if (host.endsWith('.sandbox.lightning.force.com')) {
            appHost = host.replace('.sandbox.lightning.force.com', '--c.sandbox.my.salesforce.app');
        } else if (host.endsWith('.scratch.lightning.force.com')) {
            appHost = host.replace('.scratch.lightning.force.com', '--c.scratch.my.salesforce.app');
        } else if (host.endsWith('.lightning.force.com')) {
            appHost = host.replace('.lightning.force.com', '--c.my.salesforce.app');
        }
        return `https://${appHost}/app/${APP}`;
    }

    // fresh object each read, so the embedding forwards changes
    get hostProps() {
        return { recordId: this.recordId };
    }

    async handleRequest(event) {
        const { id, action, payload = {} } = event.detail || {};
        let response;
        try {
            const json = await handleRequest({ action, payloadJson: JSON.stringify({ ...payload, recordId: this.recordId }) });
            response = { id, ok: true, data: json ? JSON.parse(json) : null };
        } catch (e) {
            response = { id, ok: false, error: (e && e.body && e.body.message) || (e && e.message) || 'The request failed.' };
        }
        this.refs.embedding?.dispatchEvent(new CustomEvent('appresponse', { detail: response }));
    }

    handleNavigate(event) {
        const recordId = event.detail && event.detail.recordId;
        if (!recordId) return;
        this[NavigationMixin.Navigate]({ type: 'standard__recordPage', attributes: { recordId, actionName: 'view' } });
    }
}
