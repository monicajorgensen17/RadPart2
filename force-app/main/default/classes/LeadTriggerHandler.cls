public with sharing class LeadTriggerHandler {

    //must match API values for picklist exactly
    //follow up task for each product intereset value
    private static final Map<String, String> SUBJECT_BY_INTEREST = new Map<String, STring>{
        'Cookbook Authorship' => 'Follow up: discuss writing a cookbook',
        'Cookbook Editing' => 'Follow up: discuss editing services',
        'Cookbook Distribution' => 'Follow up: discuss distribution options'
    };

    private static final Integer DAYS_UNTIL_DUE = 3;

    //after insert every new lead with a prodcut interterst gets a task
    public static void handleAfterInsert(List<Lead> newLeads) {
        createFollowUpTasks(newLeads);
    }

    //after update, only leades whose product interest changed get a task
    public static void handleAfterUpdate(List<Lead> newLeads, Map<Id, Lead> oldLeadMap) {
        List<Lead> changedLeads = new List<Lead>();

        for (Lead newLead : newLeads) {
            Lead oldLead = oldLeadMap.get(newLead.Id);
            if (newLead.ProductInterest__c != oldLead.ProductInterest__c) {
                changedLeads.add(newLead);
            }
    }

    createFollowUpTasks(changedLeads);
}

//build one task per lead then insert them all at once
private static void createFollowUpTasks(List<Lead> leads) {
    List<Task> tasksToInsert = new List<Task>();

    for(lead l : leads) {
        //skip leads with no product interest
        if (String.isblank(l.ProductInterest__c)) {
            continue;
        }

        String subject = SUBJECT_BY_INTEREST.containsKey(l.ProductInterest__c)
        ? SUBJECT_BY_INTEREST.get(l.ProductInterest__c)
        : 'Follow up: ' + l.ProductInterest__c;

        Task t = new Task(
            WhoId = l.Id,
            Subject = subject,
            ActivityDate = Date.today().addDays(DAYS_UNTIL_DUE),
            Status = 'Not Started',
            Priority = 'Normal',
            Description = 'Lead is interested in ' + l.ProductInterest__c + '.'
        );

        //tasks can't be owned by queue so only assign to lead owner if it's a user
        if (l.OwnerId != null && l.OwnerId.getSobjectType() == User.SObjectType) {
            t.OwnerId = l.OwnerId;
        }

        tasksToInsert.add(t);
    }

    //one dml outside the loop for bulk
    if (!tasksToInsert.isEmpty()) {
        insert tasksToInsert;
    }
}
}