@IsTest
private class MyAppEmbedControllerTest {
    @IsTest
    static void pingAnswersWithTheRecordId() {
        Map<String, Object> out = (Map<String, Object>) JSON.deserializeUntyped(
            MyAppEmbedController.handleRequest('ping', '{"recordId":"001000000000000AAA"}'));
        System.assertEquals(true, out.get('ok'));
        System.assertEquals('001000000000000AAA', out.get('recordId'));
    }

    @IsTest
    static void unknownActionsFailWithAReadableMessage() {
        try {
            MyAppEmbedController.handleRequest('nope', null);
            System.assert(false, 'expected an error');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Unknown action'));
        }
    }
}
