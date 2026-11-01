public with sharing class WeekTwoHomework {

    //1. Queary a lst of contacts, including teh parent acct name and industry. loop through and print each contact's account name.
    public static void printContactAccountNames() {
        List<Contact> contacts = [
            SELECT Id, FirstName, LastName, Account.Name, Account.Industry
            FROM Contact
            WHERE AccountId != null
            ORDER BY LastName
            LIMIT 50
        ];

        for (Contact c : contacts) {
            System.debug(c.FirstName + ' ' + c.LastName
            + ' | Account: ' + c.Account.Name + ' | Industry: ' + c.Account.Industry);
        }
    }

    //2. query a list of accounts with the closed won opptys in a subquery. loop through and print each account's oppty names
    public static void printAccountClosedWonOppNames() {
        List<Account> accounts = [
            SELECT Id, Name, (SELECT Id, Name, Amount, CloseDate FROM Opportunities WHERE StageName = 'Closed Won')
            FROM Account
            ORDER BY Name
        ];

        for (Account acc : accounts) {
            for (Opportunity opp : acc.Opportunities) {
                System.debug('Account: ' + acc.Name + ' | Closed Won Opp: ' + opp.Name);
            }
        }
    }

    //3. query oppty records and retrun results as map keyed by Id
    public static Map<Id, Opportunity> getOpportunityMap() {
        Map<Id, Opportunity> oppMap = new Map<Id, Opportunity>([
            SELECT Id, Name, Amount, StageName, CloseDate, Account.Name
            FROM Opportunity
            WHERE Amount > 0
        ]);

        System.debug('Opportunities in map: ' + oppMap.size());
        return oppMap;
    }

    //4. aggregate query that returns the total number of open opptys
    public static Integer countOpenOpportunities() {
        List<AggregateResult> results = [
            SELECT COUNT(Id) totalOpen
            FROM Opportunity
            WHERE IsClosed=false
        ];

        Integer totalOpen = (Integer) results[0].get('totalOpen');
        System.debug('Open Opportunities: ' + totalOpen);
        return totalOpen;
    }
}