public with sharing class RecipeTriggerHandler {

    public static void handleBeforeInsert(List<Recipe__c> newRecipes) {
        markDraftIfMissingValues(newRecipes);
        setComplexity(newRecipes);
    }

    public static void handleAfterInsert(List<Recipe__c> newRecipes) {

    }

    public static void handleBeforeUpdate(List<Recipe__c> newRecipes, Map<Id, Recipe__c> oldMap) {
        markDraftIfMissingValues(newRecipes);
        setComplexity(newRecipes);
    }

    public static void handleAfterUpdate(List<Recipe__c> newRecipes, Map<Id, Recipe__c> oldMap) {
        createReviewTasks(newRecipes);
    }

    private static void markDraftIfMissingValues(List<Recipe__c> recipes) {
        for (Recipe__c r : recipes) {
            if (String.isBlank(r.Name)
                || r.Active_Time__c == null
                || String.isBlank(r.Description__c)
                || String.isBlank(r.Active_Time_Units__c)
                || r.Servings__c == null) {
                r.Draft__c = true;
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