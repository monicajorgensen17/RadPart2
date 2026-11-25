/**
 * RecipeTriggerHandler (week 6)
 *
 * Requirement change: a recipe missing a required field is no longer
 * saved as Draft. It is blocked with addError instead.
 */
public with sharing class RecipeTriggerHandler {

    @TestVisible
    private static final String MISSING_FIELDS_ERROR = 'Recipe is missing required fields: ';

    public static void handleBeforeInsert(List<Recipe__c> newRecipes) {
        validateRequiredFields(newRecipes);
        setComplexity(newRecipes);
    }

    public static void handleAfterInsert(List<Recipe__c> newRecipes) {

    }

    public static void handleBeforeUpdate(List<Recipe__c> newRecipes, Map<Id, Recipe__c> oldMap) {
        validateRequiredFields(newRecipes);
        setComplexity(newRecipes);
    }

    public static void handleAfterUpdate(List<Recipe__c> newRecipes, Map<Id, Recipe__c> oldMap) {
        createReviewTasks(newRecipes);
    }

    private static void validateRequiredFields(List<Recipe__c> recipes) {
        for (Recipe__c r : recipes) {
            List<String> missing = new List<String>();
            if (String.isBlank(r.Name))                 { missing.add('Name'); }
            if (r.Active_Time__c == null)               { missing.add('Active Time'); }
            if (String.isBlank(r.Active_Time_Units__c)) { missing.add('Active Time Units'); }
            if (String.isBlank(r.Description__c))       { missing.add('Description'); }
            if (r.Servings__c == null)                  { missing.add('Servings'); }

            if (!missing.isEmpty()) {
                // replaces the old: r.Draft__c = true;
                r.addError(MISSING_FIELDS_ERROR + String.join(missing, ', '));
            } else {
                // clears Draft on any older draft recipes once they're fixed
                r.Draft__c = false;
            }
        }
    }

    private static void setComplexity(List<Recipe__c> recipes) {
        for (Recipe__c r : recipes) {
            Integer rating = HelperFunctions.rateRecipeComplexity(r);

            switch on rating {
                when 3 {
                    r.Complexity__c = 'Difficult';
                }
                when 2 {
                    r.Complexity__c = 'Moderate';
                }
                when 1 {
                    r.Complexity__c = 'Simple';
                }
            }
        }
    }

    private static void createReviewTasks(List<Recipe__c> recipes) {

        // 1. Keep only the recipes that are not drafts
        Set<Id> nonDraftRecipeIds = new Set<Id>();
        for (Recipe__c r : recipes) {
            if (r.Draft__c == false) {
                nonDraftRecipeIds.add(r.Id);
            }
        }

        if (nonDraftRecipeIds.isEmpty()) {
            return;
        }

        // 2. Find where those recipes are used in cookbooks
        List<Recipe_Usage__c> usages = [
            SELECT Id, Recipe__c, Cookbook__c, Cookbook__r.OwnerId
            FROM Recipe_Usage__c
            WHERE Recipe__c IN :nonDraftRecipeIds
        ];

        // 3. Build one task per cookbook, skipping cookbooks we've already handled
        List<Task> tasksToInsert = new List<Task>();
        Set<Id> cookbooksWithTask = new Set<Id>();
        for (Recipe_Usage__c usage : usages) {
            if (cookbooksWithTask.contains(usage.Cookbook__c)) {
                continue;
            }
            cookbooksWithTask.add(usage.Cookbook__c);

            Task t = new Task();
            t.Subject = 'Review';
            t.WhatId = usage.Cookbook__c;
            t.OwnerId = usage.Cookbook__r.OwnerId;
            t.ActivityDate = System.today().addDays(7);
            tasksToInsert.add(t);
        }

        // 4. Insert them all at once
        if (!tasksToInsert.isEmpty()) {
            insert tasksToInsert;
        }
    }
}