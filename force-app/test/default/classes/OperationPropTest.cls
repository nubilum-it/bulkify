/**
 * Copyright (c) 2018-present, Nubilum IT Consulting d.o.o. 
 * All rights reserved.
 * Properties tests for operation:
 *   insert one account with name. Bulkify and execute for list of names. (cached, uncached)
 *   query one account with name. Bulkify and execute for list of names. (cached, uncached)
 *   insert account with name then opportunity to that account. Bulkify and execute it for list of names. (cached, uncached)
 *   insert opportunity with name and if account doesn't exists create new one. Bulkify and execute if for list of names.
 *   delete opportunity from account. If account is without opportunities delete it. Bulkify and execute if for list of names.
 *   error behaviour. If error happened in operation chain rest of the operations will not be executed and exeption will be thrown.
 *   error recoveryBehaviour. On error recovery function is called to recover result.
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
    private class UpsertAccountFunction extends OperationFunction {
        override public Operation apply(Object a) {
            String name = (String)a;
            Account acc = new Account(Name = name);
            return Operation.cached(DMLRequest.ups(acc, null));
        }
    }
    private class UpdateAccountFunction extends OperationFunction {
        override public Operation apply(Object a) {
            Account acc = (Account)a;
            acc.Name = acc.Name + '0';
            return Operation.cached(DMLRequest.upd(acc));
        }
    }
  
    @isTest
    static void testInsertAccount() {
        Operation.result('Test 1').then(new CreateAccountFunction()).execute();

        System.assertEquals(1, [SELECT Id FROM Account].size());
    }
    
    @isTest
    static void testInsertUpdateAccount() {
        Operation.result('Test 1').then(new CreateAccountFunction()).then(new UpdateAccountFunction()).execute();

        System.assertEquals(1, [SELECT Id FROM Account WHERE Name = 'Test 10'].size());
    }
    
    @isTest
    static void testUpsertAccount() {
        Operation.result('Test 1').then(new UpsertAccountFunction()).execute();
        
        System.assertEquals(1, [SELECT Id FROM Account].size());
    }

    @isTest
    static void testInsertAccountBulkify() {
        OperationFunction createAccount = (new CreateAccountFunction());
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

        System.assertEquals(1, [SELECT Id FROM Opportunity].size());
    }

    @isTest
    static void testInsertAccountAndOpportunityBulkify() {
        (new CreateAccountFunction())
            .then(new CreateOpportunityFunction())
            .bulkify(new List<String> {'Test 1', 'Test 2', 'Test 3'})
            .execute();

        System.assertEquals(3, [SELECT Id FROM Opportunity].size());
    }

    @isTest
    static void testInsertAccountAndOpportunitySameCached() {
        List<String> names = new List<String>{};
        for (Integer a = 0; a < 200; a++) {
            names.add('Test 1');
        }
        OperationFunction a = new CreateAccountFunction();
        a.then(new CreateOpportunityFunction())
            .bulkify(names)
            .execute();

        System.assertEquals(1, [SELECT Id FROM Opportunity].size());
    }

    @isTest
    static void testInsertAccountAndOpportunitySameUnCached() {
        List<String> names = new List<String>{};
        for (Integer a = 0; a < 200; a++) {
            names.add('Test 1');
        }
        OperationFunction a = new CreateAccountUnCachedFunction();
        a.then(new CreateOpportunityUnCachedFunction())
            .bulkify(names)
            .execute();

        System.assertEquals(200, [SELECT Id FROM Opportunity].size());
    }

    private class QueryBusinessAccountFunction extends OperationFunction {
        override public Operation apply(Object a) {
            String n = (String)a;
            return Operation.join(new List<Operation> {
                (new QueryAccountFunction()).apply(n.substring(0, 3)),
                Operation.result(n)
            });
        }
    }
    private class CreateBusinessAccountFunction extends OperationFunction {
        override public Operation apply(Object b) {
            List<Object> bs = (List<Object>)b;
            Account[] acs  = (Account[])bs[0];
            String n = (String)bs[1];
            if (acs.size() > 0) {
                return Operation.join(new List<Operation> {
                    Operation.result(acs[0]),
                    Operation.result(n) 
                });
            }
            else {
                return Operation.join(new List<Operation> {
                    Operation.cached(DMLRequest.ins(new Account(Name = n.substring(0, 3)))),
                    Operation.result(n) 
                });
            }
        }
    }
    private class CreateBusinessOpportunityFunction extends OperationFunction {
        override public Operation apply(Object b) {
            List<Object> bs = (List<Object>)b;
            Account a = (Account)bs[0];
            String n = (String)bs[1];
            return Operation.cached(DMLRequest.ins(new Opportunity(Name = n, AccountId = a.Id, StageName = 'Prospecting', CloseDate = Date.today())));
        }
    }
    @isTest
    static void testBusinessLogic() {
        Operation.result('Test 1')
            .then(new QueryBusinessAccountFunction())
            .then(new CreateBusinessAccountFunction())
            .then(new CreateBusinessOpportunityFunction())
            .execute();

        System.assertEquals(1, [SELECT Id FROM Account].size());
        System.assertEquals(1, [SELECT Id FROM Opportunity].size());
    }

    @isTest
    static void testBusinessLogicBulkify() {
        insert new Account(Name = 'Tes');

        (new QueryBusinessAccountFunction())
            .then(new CreateBusinessAccountFunction())
            .then(new CreateBusinessOpportunityFunction())
            .bulkify(new List<String> {'Test 1', 'Test 2', 'Test 3', 'Rest 1', 'Rest 2', 'Rest 3'})
            .execute();

        System.assertEquals(2, [SELECT Id FROM Account].size());
        System.assertEquals(6, [SELECT Id FROM Opportunity].size());
    }

    private class QueryBusinessOpportunityFunction extends OperationFunction {
        override public Operation apply(Object a) {
            String n = (String)a;
            String queryString = 'SELECT Id, Name, AccountId FROM Opportunity WHERE Name = ?';
            queryString = queryString.replaceAll('\\?', '\'' + n + '\'');
            return Operation.cached(SOQLRequest.query(queryString));
        }
    }
    private class DeleteBusinessOpportunityFunction extends OperationFunction {
        override public Operation apply(Object o) {
            System.debug('Opportunities: ' + o);
            List<SObject> os = (List<SObject>)o;
            return Operation.join(new List<Operation> {
                Operation.cached(DMLRequest.del(os[0])),
                Operation.result(((Opportunity)os[0]).AccountId)
            });

        }
    }
    private class QueryBusinessAccountOpportunityFunction extends OperationFunction {
        override public Operation apply(Object b) {
            List<Object> bs = (List<Object>)b;
            String a = (String)bs[1];
            String queryString = 'SELECT Id, Name, AccountId FROM Opportunity WHERE AccountId = ?';
            queryString = queryString.replaceAll('\\?', '\'' + a + '\'');
            return Operation.join(new List<Operation> { 
                Operation.cached(SOQLRequest.query(queryString)),
                Operation.result(a)
            });
        }
    }
    private class DeleteBusinessAccountFunction extends OperationFunction {
        override public Operation apply(Object b) {
            List<Object> bs = (List<Object>)b;
            List<SObject> os = (List<SObject>)bs[0];
            String a = (String)bs[1];
            if (os.size() == 0) {
                return Operation.cached(DMLRequest.del(new Account(Id = a)));
            }
            else {
                return Operation.result(new Account(Id = a));
            }
        }
    }
    @isTest
    static void testDeleteBusinessLogic() {
        testBusinessLogicBulkify();

        Operation.result('Rest 1')
            .then(new QueryBusinessOpportunityFunction())
            .then(new DeleteBusinessOpportunityFunction())
            .then(new QueryBusinessAccountOpportunityFunction())
            .then(new DeleteBusinessAccountFunction())
            .execute();

        System.assertEquals(2, [SELECT Id FROM Account].size());
        System.assertEquals(5, [SELECT Id FROM Opportunity].size());
    }

    @isTest
    static void testDeleteBusinessLogicBulkify() {
        testBusinessLogicBulkify();

        OperationFunction process = (new QueryBusinessOpportunityFunction())
            .then(new DeleteBusinessOpportunityFunction())
            .then(new QueryBusinessAccountOpportunityFunction())
            .then(new DeleteBusinessAccountFunction());

        process
            .bulkify(new List<String> {'Test 1', 'Rest 1', 'Rest 2', 'Rest 3'})
            .execute();

        System.assertEquals(1, [SELECT Id FROM Account].size());
        System.assertEquals(2, [SELECT Id FROM Opportunity].size());
    }
    
    @isTest
    static void testBulkifyLimit() {
        OperationFunction createAccount = new CreateAccountFunction();
        List<String> names = new List<String>();
        for (Integer i = 1; i <= 1000; i++) {
            names.add('Test 1');
        }

        createAccount.bulkify(names).execute();

        System.assertEquals(1, [SELECT Id FROM Account].size());
    }

    private class TestException extends Exception {}
    private class ErrorFunction extends OperationFunction {
        override public Operation apply(Object a) {
            return Operation.error(new TestException());
        }
    }
    private class ErrorOpportunityFunction extends OperationFunction {
        override public Operation apply(Object a) {
            String n = (String)a;
            return Operation.cached(DMLRequest.ins(new Opportunity(Name = n)));
        }
    }
    private class RecoverFunction extends OperationFunction {
        override public Operation apply(Object a) {
            return Operation.result('Test');
        }
    }
    @isTest
    static void testError() {
        try {
            (new CreateAccountFunction())
                .then(new ErrorFunction())
                .apply('Test 1')
                .execute();
            System.assert(false);
        } 
        catch (Exception e) {
            System.assert(true);
        }
    }

    @isTest
    static void testOpportunityError() {
        try {
            (new ErrorOpportunityFunction())
                .apply('Test 1')
                .execute();
            System.assert(false);
        }
        catch (Exception e) {
            System.assert(true);
        }
    }
    
    @isTest
    static void testErrorRecovery() {
        try {
            (new CreateAccountFunction())
                .then(new ErrorFunction())
                .recoverWith(new RecoverFunction())
                .apply('Test 1')
                .execute();
            System.assert(true);
        } 
        catch (Exception e) {
            System.assert(false);
        }
    }
}
