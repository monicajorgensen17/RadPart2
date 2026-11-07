@IsTest
private class LeadTriggerHandlerTest {

    private static Lead buildLead(String interest) {
        return new Lead(
            LastName = 'Tester',
            Company = 'Test Kitchen',
            ProductInterest__c = interest
        );
    }

    private static Integer taskCount(Id leadId) {
        return [SELECT COUNT() FROM Task WHERE WhoId = :leadId];
    }

    @IsTest
    static void insertWithInterestCreatesTask() {
        Lead l = buildLead('Cookbook Authorship');
        Test.startTest();
        insert l;
        Test.stopTest();

        Task t = [SELECT Subject FROM Task WHERE WhoId = :l.Id];
        System.assertEquals('Follow up: discuss writing a cookbook', t.Subject);
    }

    @IsTest
    static void insertWithoutInterestCreatesNoTask() {
        Lead l = buildLead(null);
        insert l;
        System.assertEquals(0, taskCount(l.Id));
    }

    @IsTest
    static void updateWithChangedInterestCreatesTask() {
        Lead l = buildLead('Cookbook Authorship');
        insert l;

        Test.startTest();
        l.ProductInterest__c = 'Cookbook Editing';
        update l;
        Test.stopTest();

        System.assertEquals(2, taskCount(l.Id), 'One task from insert, one from the change');
    }

    @IsTest
    static void updateWithoutInterestChangeCreatesNoTask() {
        Lead l = buildLead('Cookbook Authorship');
        insert l;

        Test.startTest();
        l.Title = 'Head Chef';
        update l;
        Test.stopTest();

        System.assertEquals(1, taskCount(l.Id), 'Only the insert task should exist');
    }

    @IsTest
    static void bulkInsertCreatesOneTaskPerLead() {
        List<Lead> leads = new List<Lead>();
        for (Integer i = 0; i < 200; i++) {
            leads.add(buildLead('Cookbook Distribution'));
        }

        Test.startTest();
        insert leads;
        Test.stopTest();

        System.assertEquals(200, [SELECT COUNT() FROM Task WHERE WhoId IN :leads]);
    }
}