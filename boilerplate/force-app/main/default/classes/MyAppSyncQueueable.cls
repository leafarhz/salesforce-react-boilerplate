/**
 * BOILERPLATE: Queueable that refreshes Salesforce Decision Tables via an AutoLaunched Flow.
 *
 * WHY FLOW INSTEAD OF Invocable.Action.createStandardAction():
 *   refreshDecisionTable is a Flow-only standard action — calling it directly from Apex
 *   via Invocable.Action throws "XYZ isn't a valid action type."
 *   The workaround: create an AutoLaunched Flow that calls the action, then invoke the
 *   Flow from Apex via Flow.Interview. See RefreshMyDecisionTable.flow-meta.xml.
 *
 * TABLE API NAMES:
 *   Use DeveloperName from DecisionTable sObject (e.g. My_Decision_Table),
 *   NOT the SetupName display label (e.g. "My Decision Table").
 *   Verify: SELECT DeveloperName, SetupName FROM DecisionTable ORDER BY DeveloperName
 *
 * DML ORDER RULE:
 *   Never insert/update records BEFORE calling Flow.Interview.start().
 *   Do all DML AFTER the work is done.
 *
 * REPLACE: MyApp, MY_TABLES, 'RefreshMyDecisionTable' → your values.
 */
public class MyAppSyncQueueable implements Queueable {

    // DeveloperName values from DecisionTable — NOT camelCase abbreviations.
    private static final List<String> MY_TABLES = new List<String>{
        'My_First_Decision_Table',
        'My_Second_Decision_Table',
        'My_Third_Decision_Table'
    };

    private String triggeredBy;
    private Id triggeredByUserId;

    public MyAppSyncQueueable(String triggeredBy, Id triggeredByUserId) {
        this.triggeredBy = triggeredBy;
        this.triggeredByUserId = triggeredByUserId;
    }

    public void execute(QueueableContext ctx) {
        DateTime startTime = System.now();
        Integer succeeded  = 0;
        Integer failed     = 0;
        List<String> errors = new List<String>();

        // Step 1: Do all work BEFORE any DML
        for (String tableName : MY_TABLES) {
            try {
                Map<String, Object> inputs = new Map<String, Object>{
                    'DecisionTableApiName' => tableName
                };
                // Flow must have a <faultConnector> that captures {!$Flow.FaultMessage}
                // into an 'ErrorMessage' output variable — otherwise action failures send
                // admin error emails and the exception message is just "An unhandled fault..."
                Flow.Interview interview = Flow.Interview.createInterview(
                    'RefreshMyDecisionTable', inputs
                );
                interview.start();

                String actionError = (String) interview.getVariableValue('ErrorMessage');
                if (String.isNotBlank(actionError)) {
                    failed++;
                    errors.add(tableName + ': ' + actionError);
                } else {
                    succeeded++;
                }
            } catch (Exception e) {
                failed++;
                errors.add(tableName + ': ' + e.getMessage());
            }
        }

        // Step 2: DML happens AFTER all work is done
        String status   = failed == 0 ? 'Success' : (succeeded == 0 ? 'Failed' : 'Partial');
        String errorMsg = errors.isEmpty() ? null : String.join(errors, '; ').left(255);

        MyAppLog__c logRecord = new MyAppLog__c(
            Status__c          = status,
            TriggeredBy__c     = triggeredBy,
            TriggeredByUser__c = triggeredByUserId,
            StartTime__c       = startTime,
            EndTime__c         = System.now(),
            ErrorMessage__c    = errorMsg,
            Succeeded__c       = succeeded,
            Failed__c          = failed
        );
        insert logRecord;
    }
}
