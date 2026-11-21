/** 
 * Tests for RecipeTriggerHandler
 * 
 * The tests fire the trigger with real DML instad of calling handler methods directly.
 *
 */

 @IsTest
 private class RecipeTriggerHandler_Test {

    //-----Test data helpers -----

    //A recipe with every required value filled in (not marked Draft)
    private static Recipe__c buildCompleteRecipe(String name)   {
        return new Recipe__c(
            Name                = name,
            Active_Time__c      = 30,
            Active_Time_Units__c = 'Minutes',
            Description__c      = 'A tasty test recipe',
            Servings__c         = 4
        );
    }

    @TestSetup
    static void makeData(){
        //cookbook and recipe it's used in
        Cookbook__c book = new Cookbook__c(Name = 'Test Cookbook');
        insert book;

        Recipe__c usedRecipe = buildCompleteRecipe('Used Recipe');
        insert usedRecipe;

        insert new Recipe_Usage__c(Cookbook__c = book.Id, Recipe__c = usedRecipe.Id);
    }

    //draft checkbox

    @IsTest
    static void completeRecipe_isNotDraft() {
        Recipe__c r = buildCompleteRecipe('Complete Recipe');

        Test.startTest();
        insert r;
        Test.stopTest();

        r = [SELECT Draft__c FROM Recipe__c WHERE Id = :r.Id];
        Assert.isFalse(r.Draft__c, 'A recipe with all key values should not be a draft.');
    }

    @IsTest
    static void missingValue_onInsert_isDraft() {
        Recipe__c r = buildCompleteRecipe('Missing Description');
        r.Description__c = null;

        Test.startTest();
        insert r;
        Test.stopTest();

        r = [SELECT Draft__c FROM Recipe__c WHERE Id = :r.Id];
        Assert.isTrue(r.Draft__c, ' A recipe missing description should be marked Draft.');
    }

    @IsTest 
    static void eachMissingField_isDraft() {
        //one recipe per required field, each missing just that field
        Recipe__c noTime = buildCompleteRecipe('No Active Time'); noTime.Active_Time__c = null;
        Recipe__c noUnits = buildCompleteRecipe('No units'); noUnits.Active_Time__c = null;
        Recipe__c noDesc = buildCompleteRecipe('No Description'); noDesc.Description__c = null;
        Recipe__c noServings = buildCompleteRecipe('No servings'); noServings.Servings__c = null;
        List<Recipe__c> recipes = new List<Recipe__c>{ noTime, noUnits, noDesc, noServings };

        Test.startTest();
        insert recipes;
        Test.stopTest();

        for (Recipe__c r : [SELECT Name, Draft__c FROM Recipe__c WHERE Id IN : recipes]) {
            Assert.isTrue(r.Draft__c, r.Name + ' should be marked Draft');
        }

    }

    @IsTest
    static void missingValue_onUpdate_isDraft() {
        Recipe__c r = buildCompleteRecipe('will lose servings');
        insert r;

        Test.startTest();
        r.Servings__c = null;
        update r;
        Test.stopTest();

        r = [SELECT Draft__c FROM Recipe__c WHERE Id = :r.Id];
        Assert.isTrue(r.Draft__c, 'clearing a key value on update should mark recipe draft');

    }

    @IsTest
    static void filledIn_onUpdate_isNoLongerDraft() {
        //does draft get unchecked once missing value is added
        Recipe__c r = buildCompleteRecipe('Starts as draft');
        r.Description__c = null;
        insert r;

        Test.startTest();
        r.Description__c = 'description add';
        update r;
        Test.stopTest();

        r = [SELECT Draft__c FROM Recipe__c WHERE Id = :r.Id];
        Assert.isFalse(r.Draft__c, 'filling in missing value should clear draft');
    }

    @IsTest
    static void complexity_isSetOnInsert() {
        Recipe__c r = buildCompleteRecipe('Complexity recipe');
        
        Test.startTest();
        insert r;
        Test.stopTest();

        r = [SELECT Name, Active_Time__c, Active_Time_Units__c, Description__c, Servings__c, Complexity__c
        FROM Recipe__c WHERE Id = :r.Id];

        Decimal rating = HelperFunctions.rateRecipeComplexity(r);
        String expected = rating == 3 ? 'Difficult' : rating  == 2 ? 'Moderate' : 'Simple';

        Assert.areEqual(expected, r.Complexity__c, 'complexity should match helper rating');
    }

    @IsTest
    static void complexity_isRecalculatedOnUpdate() {
        Recipe__c r = buildCompleteRecipe('gets harder');
        insert r;

        Test.startTest();
        r.Active_Time__c = 5;
        r.Active_Time_Units__c = 'Hours';
        Test.stopTest();

        r = [SELECT Complexity__c FROM Recipe__c WHERE Id = :r.Id];
        Assert.isNotNull(r.Complexity__c, 'complexity should still be set after update');
    }
        //review task for cookbook owners
        @IsTest
        static void updatingUsedRecipe_createsReviewTask() {
            Recipe__c r = [SELECT Id FROM Recipe__c WHERE Name = 'used recipe' LIMIT 1];
            Cookbook__c book = [SELECT Id, OwnerId FROM Cookbook__c WHERE Name = 'Test Cookbook' LIMIT 1];

            Test.startTest();
            r.Servings__c = 6;
            update r;
            Test.stopTest();

            List<Task> tasks = [SELECT OwnerId, ActivityDate, WhatId FROM Task WHERE WhatId = :book.Id];

            Assert.areEqual(1, tasks.size(), 'one review task should be created for the cookbook');
            Assert.areEqual(book.OwnerId, tasks[0].OwnerId, 'task should go to book owner');
            Assert.areEqual(Date.today().addDays(7), tasks[0].ActivityDate, 'task should be due in a week');
        }

        @IsTest
        static void updatingUnusedRecipe_createsNoTask() {
            Recipe__c r = buildCompleteRecipe('lonely recipe');
            insert r;

            Test.startTest();
            r.Servings__c = 2;
            update r;
            Test.stopTest();

            Assert.areEqual(0, [SELECT COUNT() FROM Task WHERE WhatId = :r.Id], 'no task created for recipe not in book');
        }

        //-----BULK ------

        @IsTest
        static void bulkInsert_200Recipes() {
            List<Recipe__c> recipes = new List<Recipe__c>();
            for (Integer i = 0; i < 200; i++) {
                Recipe__c r = buildCompleteRecipe('Bulk ' + i);
                if (Math.mod(i, 2) == 0) {
                    r.Description__c = null; //half are drafts
                }
                recipes.add(r);
            }

            Test.startTest();
            insert recipes;
            Test.stopTest();

            Assert.areEqual(100, [SELECT COUNT() FROM Recipe__c WHERE Id IN :recipes AND Draft__c = true], 'half of the bulk recipes are draft');
            Assert.areEqual(200, [SELECT COUNT() FROM Recipe__c WHERE Id IN :recipes AND Complexity__c != null], 'every bulk recipe gets complexity');
        }
    }