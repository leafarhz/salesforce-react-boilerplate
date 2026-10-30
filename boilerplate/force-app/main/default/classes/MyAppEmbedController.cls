/**
 * BOILERPLATE: Apex behind the myAppHost LWC. The embedded React guest has no direct org data access, so it sends
 * `apprequest` events; the host calls handleRequest and answers the guest. See references/embedding.md.
 *
 * GUARDRAILS (do not remove):
 *   - Apex runs in system mode: check the user may read what you return (isAccessible / custom permission) at the
 *     top of every entry point, or the panel shows data the user can't otherwise see.
 *   - One request = one transaction = one set of governor limits. Keep bulk work to ~10 records per call and let the
 *     guest send several calls.
 *   - "What if" simulations: run the real logic inside a savepoint and roll back in a finally.
 *
 * REPLACE: MyApp, Account (the object you actually read), the actions.
 */
public with sharing class MyAppEmbedController {
    @AuraEnabled
    public static String handleRequest(String action, String payloadJson) {
        if (!Schema.SObjectType.Account.isAccessible()) {
            throw fail('You need access to Accounts to use My App.');
        }
        Map<String, Object> payload = String.isBlank(payloadJson)
            ? new Map<String, Object>()
            : (Map<String, Object>) JSON.deserializeUntyped(payloadJson);
        switch on action {
            when 'ping' {
                return JSON.serialize(new Map<String, Object>{
                    'ok' => true,
                    'user' => UserInfo.getName(),
                    'recordId' => payload.get('recordId')
                });
            }
            when else {
                throw fail('Unknown action: ' + action);
            }
        }
    }

    /** getMessage() on AuraHandledException is generic unless setMessage is called. */
    static AuraHandledException fail(String message) {
        AuraHandledException e = new AuraHandledException(message);
        e.setMessage(message);
        return e;
    }
}
