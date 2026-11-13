trigger RecipeTrigger on Recipe__c (before insert, after insert, before update, after update) {

    switch on Trigger.operationType {
        when BEFORE_INSERT {
            RecipeTriggerHandler.handleBeforeInsert(Trigger.new);
        }
        when AFTER_INSERT {
            RecipeTriggerHandler.handleAfterInsert(Trigger.new);
        }
        when BEFORE_UPDATE {
            RecipeTriggerHandler.handleBeforeUpdate(Trigger.new, Trigger.oldMap);
        }
        when AFTER_UPDATE {
            RecipeTriggerHandler.handleAfterUpdate(Trigger.new, Trigger.oldMap);
        }
    }
}