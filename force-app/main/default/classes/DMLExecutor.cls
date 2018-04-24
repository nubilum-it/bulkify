/**
 * Copyright (c) 2018-present, Nubilum IT Consulting d.o.o. 
 * All rights reserved.
 * DML Executor functionality. 
 * Steps of execution:
 *   groupBy SObject type already each grouped request.
 *   execute operation and update operation status in the box.
 * Some operations can be executed with all records and some should be executed one record at the time like upsert.
 * Delete should be done by deleting first child than parent. We chan chain operations with then combinator.
 */
public class DMLExecutor {
    public class Ins implements Operation.Executor {
        public void execute(List<Operation.NextRequest> nextRequests) {
            System.debug('nextRequests: ' + nextRequests);
            Map<String, List<Operation.NextRequest>> bySObjectType = Operation.groupBy(nextRequests, new SObjectTypeFunction());
            for (String key : bySObjectType.keySet()) {
                List<SObject> records = new List<SObject>();
                for (Operation.NextRequest nr : bySObjectType.get(key)) {
                    records.add(((DMLRequest)nr.request).record.clone(true, true, true, true));
                }
                Database.SaveResult[] results = Database.insert(records, false);

                Iterator<SObject> recIt = records.iterator();
                Iterator<Operation.NextRequest> nrIt = bySObjectType.get(key).iterator();
                Iterator<Database.SaveResult> resultIt = results.iterator();
                while (recIt.hasNext() && nrIt.hasNext() && resultIt.hasNext()) {
                    Database.SaveResult result = resultIt.next();
                    if (result.isSuccess()) {
                        nrIt.next().box.operationStatus = new Operation.OperationSuccess(recIt.next());
                    }
                    else {
                        nrIt.next().box.operationStatus = new Operation.OperationError(new DMLException(getErrorMessage(result.getErrors())));
                        //
                        // Goto next result value. 
                        //
                        recIt.next();
                    }
                }
            }
       }
    }
    public class SObjectTypeFunction implements Operation.Function {
        public Object apply(Object a) {
            Operation.NextRequest nr = (Operation.NextRequest)a;
            return ((DMLRequest)nr.request).record.getSObjectType().getDescribe().getName();
        }
    }


    public class Upd implements Operation.Executor {
        public void execute(List<Operation.NextRequest> nextRequests) {
            Map<String, List<Operation.NextRequest>> bySObjectType = Operation.groupBy(nextRequests, new SObjectTypeFunction());
            for (String key : bySObjectType.keySet()) {
                List<SObject> records = new List<SObject>();
                for (Operation.NextRequest nr : bySObjectType.get(key)) {
                    records.add(((DMLRequest)nr.request).record.clone(true, true, true, true));
                }
                Database.SaveResult[] results = Database.update(records, false);
                Iterator<SObject> recIt = records.iterator();
                Iterator<Operation.NextRequest> nrIt = bySObjectType.get(key).iterator();
                Iterator<Database.SaveResult> resultIt = results.iterator();
                while (recIt.hasNext() && nrIt.hasNext() && resultIt.hasNext()) {
                    Database.SaveResult result = resultIt.next();
                    if (result.isSuccess()) {
                        nrIt.next().box.operationStatus = new Operation.OperationSuccess(recIt.next());
                    }
                    else {
                        nrIt.next().box.operationStatus = new Operation.OperationError(new DMLException(getErrorMessage(result.getErrors())));
                        recIt.next();
                    }
                }
            }
        }
    }

    public class Del implements Operation.Executor {
        public void execute(List<Operation.NextRequest> nextRequests) {
            System.debug('nextRequests: ' + nextRequests);
            Map<String, List<Operation.NextRequest>> bySObjectType = Operation.groupBy(nextRequests, new SObjectTypeFunction());
            for (String key : bySObjectType.keySet()) {
                List<SObject> records = new List<SObject>();
                for (Operation.NextRequest nr : bySObjectType.get(key)) {
                    records.add(((DMLRequest)nr.request).record.clone(true, true, true, true));
                }
                System.debug('Records: ' + records);
                Database.DeleteResult[] results = Database.delete(records, false);
                Iterator<SObject> recIt = records.iterator();
                Iterator<Operation.NextRequest> nrIt = bySObjectType.get(key).iterator();
                Iterator<Database.DeleteResult> resultIt = results.iterator();
                while (recIt.hasNext() && nrIt.hasNext() && resultIt.hasNext()) {
                    Database.DeleteResult result = resultIt.next();
                    if (result.isSuccess()) {
                        nrIt.next().box.operationStatus = new Operation.OperationSuccess(recIt.next());
                    }
                    else {
                        nrIt.next().box.operationStatus = new Operation.OperationError(new DMLException(getErrorMessage(result.getErrors())));
                        recIt.next();
                    }
                }
            }
        }
    }

    public class Ups implements Operation.Executor {
        public void execute(List<Operation.NextRequest> nextRequests) {
            Map<String, List<Operation.NextRequest>> bySObjectTypeField = Operation.groupBy(nextRequests, new SObjectTypeFieldFunction());
            for (String key : bySObjectTypeField.keySet()) {
                DMLRequest.Ups r = ((DMLRequest.Ups)bySObjectTypeField.get(key)[0].request);
                String listType = 'List<' + r.record.getSObjectType().getDescribe().getName() + '>';
                List<SObject> records = (List<SObject>)Type.forName(listType).newInstance();
                Schema.SObjectField externalIdField = r.externalIdField;
                for (Operation.NextRequest nr : bySObjectTypeField.get(key)) {
                    records.add(((DMLRequest.Ups)nr.request).record.clone(true, true, true, true));
                }
                Database.UpsertResult[] results; 
                if (externalIdField == null) {
                    results = Database.upsert(records);
                }
                else {
                    results = Database.upsert(records, externalIdField);
                }
                Iterator<SObject> recIt = records.iterator();
                Iterator<Operation.NextRequest> nrIt = bySObjectTypeField.get(key).iterator();
                Iterator<Database.UpsertResult> resultIt = results.iterator();
                while (recIt.hasNext() && nrIt.hasNext() && resultIt.hasNext()) {
                    Database.UpsertResult result = resultIt.next();
                    if (result.isSuccess()) {
                        nrIt.next().box.operationStatus = new Operation.OperationSuccess(recIt.next());
                    }
                    else {
                        nrIt.next().box.operationStatus = new Operation.OperationError(new DMLException(getErrorMessage(result.getErrors())));
                        recIt.next();
                    }
                }
            }
        }
    }
    public class SObjectTypeFieldFunction implements Operation.Function {
        public Object apply(Object a) {
            Operation.NextRequest nr = (Operation.NextRequest)a;
            DMLRequest.Ups r = (DMLRequest.Ups)nr.request;
            if (r.externalIdField == null) {
                return r.record.getSObjectType().getDescribe().getName();
            }
            else {
                return r.record.getSObjectType().getDescribe().getName() + '-' 
                    + r.externalIdField.getDescribe().getName();
            }
        }        
    }

    public static String getErrorMessage(Database.Error[] errors) {
        List<String> messages = new List<String>();
        for (Database.Error error : errors) {
            messages.add(error.getStatusCode() + error.getMessage());
        }
        return String.join(messages, '\r\n');
    }
}