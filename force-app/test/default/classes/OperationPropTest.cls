/**
 * Properties tests for operation:
 *   insert one account with name. Bulkify and execute for list of names. (cached, uncached)
 *   query one account with name. Bulkify and execute for list of names. (cached, uncached)
 *   insert account with name then opportunity to that account. Bulkify and execute it for list of names. (cached, uncached)
 *   insert opportunity with name and if account doesn't exists create new one. Bulkify and execute if for list of names.
 *   delete opportunity from account. If account is without opportunities delete it. Bulkify and execute if for list of names.
 */
@isTest
private class OperationPropTest {
    private class CreateAccountFunction extends OperationFunction {
        override public Operation apply(Object a) {
            String name = (String)a;
            Account acc = new Account(Name = name);
            return Operation.cached(DMLRequest.ins(acc));
        }
    }
    private class CreateAccountUnCachedFunction extends OperationFunction {
        override public Operation apply(Object a) {
            String name = (String)a;
            Account acc = new Account(Name = name);
            return Operation.unCached(DMLRequest.ins(acc));
        }
    }
    @isTest
    static void testInsertAccount() {
        Operation.result('Test 1').then(new CreateAccountFunction()).execute();

        System.assertEquals(1, [SELECT Id FROM Account].size());
    }
    @isTest
    static void testInsertAccountBulkify() {
        OperationFunction createAccount = new CreateAccountFunction();
        createAccount.bulkify(new List<String> {'Test 1', 'Test 2', 'Test 3'}).execute();
        System.assertEquals(3, [SELECT Id FROM Account].size());
    }
    @isTest
    static void testInsertAccountSameCached() {
        OperationFunction createAccount = new CreateAccountFunction();
        createAccount.bulkify(new List<String> {'Test 1', 'Test 1', 'Test 1'}).execute();

        System.assertEquals(1, [SELECT Id FROM Account].size());
    }
    @isTest
    static void testInsertAccountSameUnCached() {
        OperationFunction createAccount = new CreateAccountUnCachedFunction();
        createAccount.bulkify(new List<String> {'Test 1', 'Test 1', 'Test 1'}).execute();

        System.assertEquals(3, [SELECT Id FROM Account].size());
    }
    private class QueryAccountFunction extends OperationFunction {
        override public Operation apply(Object a) {
            String name = (String)a;
            String queryString = 'SELECT Id, Name FROM Account WHERE Name = ?';
            queryString = queryString.replaceAll('\\?', '\'' + name + '\'');
            return Operation.cached(SOQLRequest.query(queryString));
        }
    }
    private class QueryAccountUnCachedFunction extends OperationFunction {
        override public Operation apply(Object a) {
            String name = (String)a;
            String queryString = 'SELECT Id, Name FROM Account WHERE Name = ?';
            queryString = queryString.replaceAll('\\?', '\'' + name + '\'');
            return Operation.unCached(SOQLRequest.query(queryString));
        }
    }
    @isTest
    static void testQueryAccount() {
        testInsertAccountBulkify();
        OperationFunction queryAccount = new QueryAccountFunction();
        Object a = Operation.result('Test 1').then(queryAccount).execute();
        List<SObject> result = (List<SObject>)a;
        
        System.assertEquals(1, result.size());
    } 

    @isTest    
    static void testQueryAccountBulkify() {
        testInsertAccountBulkify();
        OperationFunction queryAccount = new QueryAccountFunction();
        Object a = queryAccount
            .bulkify(new List<String>{ 'Test 1', 'Test 2', 'Test 3'})
            .execute();

        List<Object> bs = (List<Object>)a;
        System.assertEquals(3, bs.size());
        for (Object b : bs) {
            List<SObject> cs = (List<SObject>)b;
            System.assertEquals(1, cs.size());
        }
    }

    @isTest
    static void testQueryAccountSameCached() {
        testInsertAccountBulkify();
        Test.startTest();
        OperationFunction queryAccount = new QueryAccountFunction();
        List<String> names = new List<String>{};
        for (Integer a = 0; a < 100; a++) {
            names.add('Test 1');
        }
        Object a = queryAccount
            .bulkify(names)
            .execute();

        System.assertEquals(1, Limits.getQueries());
        List<Object> bs = (List<Object>)a;
        System.assertEquals(100, bs.size());
        for (Object b : bs) {
            List<SObject> cs = (List<SObject>)b;
            System.assertEquals(1, cs.size());
        }
    }

    @isTest
    static void testQueryAccountSameUncached() {
        testInsertAccountBulkify();
        Test.startTest();
        OperationFunction queryAccount = new QueryAccountUnCachedFunction();
        List<String> names = new List<String>{};
        for (Integer a = 0; a < 100; a++) {
            names.add('Test 1');
        }
        Object a = queryAccount
            .bulkify(names)
            .execute();
        List<Object> bs = (List<Object>)a;
        System.assertEquals(100, Limits.getQueries());
        System.assertEquals(100, bs.size());
        for (Object b : bs) {
            List<SObject> cs = (List<SObject>)b;
            System.assertEquals(1, cs.size());
        }
    }

    private class CreateOpportunityFunction extends OperationFunction {
        override public Operation apply(Object a) {
            Account acc = (Account)a;
            return Operation.cached(DMLRequest.ins(new Opportunity(Name = acc.Name, AccountId = acc.Id, StageName = 'Prospecting', CloseDate = Date.today())));
        }
    }
    private class CreateOpportunityUnCachedFunction extends OperationFunction {
        override public Operation apply(Object a) {
            Account acc = (Account)a;
            return Operation.unCached(DMLRequest.ins(new Opportunity(Name = acc.Name, AccountId = acc.Id, StageName = 'Prospecting', CloseDate = Date.today())));
        }
    }
    @isTest
    static void testInsertAccountAndOpportunity() {
        Operation.result('Test 1')
            .then(new CreateAccountFunction())
            .then(new CreateOpportunityFunction())
            .execute();

        List<Opportunity> os = [SELECT Id FROM Opportunity];
        System.assertEquals(1, os.size());
    }

    @isTest
    static void testInsertAccountAndOpportunityBulkify() {
        (new CreateAccountFunction())
            .then(new CreateOpportunityFunction())
            .bulkify(new List<String> {'Test 1', 'Test 2', 'Test 3'})
            .execute();

        List<Opportunity> os = [SELECT Id FROM Opportunity];
        System.assertEquals(3, os.size());
    }

    @isTest
    static void testInsertAccountAndOpportunitySameCached() {
        List<String> names = new List<String>{};
        for (Integer a = 0; a < 100; a++) {
            names.add('Test 1');
        }
        OperationFunction a = new CreateAccountFunction();
        a.then(new CreateOpportunityFunction())
            .bulkify(names)
            .execute();

        List<Opportunity> os = [SELECT Id FROM Opportunity];
        System.assertEquals(1, os.size());
    }

    @isTest
    static void testInsertAccountAndOpportunitySameUnCached() {
        List<String> names = new List<String>{};
        for (Integer a = 0; a < 100; a++) {
            names.add('Test 1');
        }
        OperationFunction a = new CreateAccountUnCachedFunction();
        a.then(new CreateOpportunityUnCachedFunction())
            .bulkify(names)
            .execute();

        List<Opportunity> os = [SELECT Id FROM Opportunity];
        System.assertEquals(100, os.size());
     }
}
