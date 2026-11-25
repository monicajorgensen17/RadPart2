/** 
 * Tests for RecipeTriggerHandler
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
static void missingValue_onInsert_throwsError() {
    Recipe__c r = buildCompleteRecipe('Missing Description');
    r.Description__c = null;

    Boolean exceptionThrown = false;

    Test.startTest();
    try {
        insert r;
    } catch (DmlException e) {
        exceptionThrown = true;
        Assert.isTrue(e.getMessage().contains(RecipeTriggerHandler.MISSING_FIELDS_ERROR),
            'Unexpected error: ' + e.getMessage());
        Assert.isTrue(e.getMessage().contains('Description'),
            'Error should name the missing field');
    }
    Test.stopTest();

    Assert.isTrue(exceptionThrown, 'Inserting a recipe missing Description should throw an error');
}

    @IsTest
static void eachMissingField_isRejected() {
    // one recipe per required field, each missing just that field
    Recipe__c noTime     = buildCompleteRecipe('No Active Time'); noTime.Active_Time__c = null;
    Recipe__c noUnits    = buildCompleteRecipe('No units');       noUnits.Active_Time_Units__c = null;
    Recipe__c noDesc     = buildCompleteRecipe('No Description'); noDesc.Description__c = null;
    Recipe__c noServings = buildCompleteRecipe('No servings');    noServings.Servings__c = null;

    List<Recipe__c> recipes = new List<Recipe__c>{ noTime, noUnits, noDesc, noServings };
    // same order as the list above
    List<String> expectedField = new List<String>{ 'Active Time', 'Active Time Units', 'Description', 'Servings' };

    Test.startTest();
    List<Database.SaveResult> results = Database.insert(recipes, false);
    Test.stopTest();

    for (Integer i = 0; i < results.size(); i++) {
        Assert.isFalse(results[i].isSuccess(), recipes[i].Name + ' should have been rejected');
        Assert.isTrue(results[i].getErrors()[0].getMessage().contains(expectedField[i]),
            recipes[i].Name + ' error should mention ' + expectedField[i]);
    }
    Assert.areEqual(0, [SELECT COUNT() FROM Recipe__c WHERE Id IN :recipes], 'none should be saved');
}

    @IsTest
static void missingValue_onUpdate_throwsError() {
    Recipe__c r = buildCompleteRecipe('will lose servings');
    insert r;

    Boolean exceptionThrown = false;

    Test.startTest();
    try {
        r.Servings__c = null;
        update r;
    } catch (DmlException e) {
        exceptionThrown = true;
        Assert.isTrue(e.getMessage().contains('Servings'),
            'Error should name the missing field: ' + e.getMessage());
    }
    Test.stopTest();

    Assert.isTrue(exceptionThrown, 'Clearing Servings on update should throw an error');
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
    update r;
    Test.stopTest();

    r = [SELECT Name, Active_Time__c, Active_Time_Units__c, Description__c, Servings__c, Complexity__c
         FROM Recipe__c WHERE Id = :r.Id];

    Decimal rating = HelperFunctions.rateRecipeComplexity(r);
    String expected = rating == 3 ? 'Difficult' : rating == 2 ? 'Moderate' : 'Simple';

    Assert.areEqual(expected, r.Complexity__c, 'complexity should be recalculated after update');
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
static void bulkInsert_onlyIncompleteRecipesRejected() {
    List<Recipe__c> recipes = new List<Recipe__c>();
    for (Integer i = 0; i < 200; i++) {
        Recipe__c r = buildCompleteRecipe('Bulk ' + i);
        if (Math.mod(i, 2) == 0) {
            r.Description__c = null; // half are incomplete
        }
        recipes.add(r);
    }

    Test.startTest();
    List<Database.SaveResult> results = Database.insert(recipes, false);
    Test.stopTest();

    Integer failures = 0;
    for (Database.SaveResult sr : results) {
        if (!sr.isSuccess()) { failures++; }
    }

    Assert.areEqual(100, failures, 'the 100 incomplete recipes should be rejected');
    Assert.areEqual(100, [SELECT COUNT() FROM Recipe__c WHERE Name LIKE 'Bulk %'], 'the 100 complete recipes should save');
    Assert.areEqual(100, [SELECT COUNT() FROM Recipe__c WHERE Name LIKE 'Bulk %' AND Complexity__c != null], 'saved recipes still get complexity');
    Assert.areEqual(0, [SELECT COUNT() FROM Recipe__c WHERE Draft__c = true], 'nothing should be marked Draft');
}
 }