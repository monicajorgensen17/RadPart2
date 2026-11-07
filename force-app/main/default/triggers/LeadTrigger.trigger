trigger LeadTrigger on Lead (after insert, after update) {
    if (Trigger.isAfter) {
        if (Trigger.isInsert) {
            LeadTriggerHandler.handleAfterInsert(Trigger.new);
        } else if (Trigger.isUpdate) {
            LeadTriggerHandler.handleAfterUpdate(Trigger.new, Trigger.oldMap);
        }
    }

}