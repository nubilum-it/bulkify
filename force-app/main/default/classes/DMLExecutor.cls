/**
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
                    records.add(((DMLRequest)nr.request).record.clone());
                }
                Database.insert(records);
                Iterator<SObject> recIt = records.iterator();
                Iterator<Operation.NextRequest> nrIt = bySObjectType.get(key).iterator();
                while (recIt.hasNext() && nrIt.hasNext()) {
                    nrIt.next().box.operationStatus = new Operation.OperationSuccess(recIt.next());
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
                    records.add(((DMLRequest)nr.request).record.clone());
                }
                Database.update(records);
                Iterator<SObject> recIt = records.iterator();
                Iterator<Operation.NextRequest> nrIt = bySObjectType.get(key).iterator();
                while (recIt.hasNext() && nrIt.hasNext()) {
                    nrIt.next().box.operationStatus = new Operation.OperationSuccess(recIt.next());
                }
            }
        }
    }

    public class Del implements Operation.Executor {
        public void execute(List<Operation.NextRequest> nextRequests) {
            Map<String, List<Operation.NextRequest>> bySObjectType = Operation.groupBy(nextRequests, new SObjectTypeFunction());
            for (String key : bySObjectType.keySet()) {
                List<SObject> records = new List<SObject>();
                for (Operation.NextRequest nr : bySObjectType.get(key)) {
                    records.add(((DMLRequest)nr.request).record.clone());
                }
                Database.delete(records);
                Iterator<SObject> recIt = records.iterator();
                Iterator<Operation.NextRequest> nrIt = bySObjectType.get(key).iterator();
                while (recIt.hasNext() && nrIt.hasNext()) {
                    nrIt.next().box.operationStatus = new Operation.OperationSuccess(recIt.next());
                }
            }
        }
    }

    public class Ups implements Operation.Executor {
        public void execute(List<Operation.NextRequest> nextRequests) {
            for (Operation.NextRequest nr : nextRequests) {
                DMLRequest.Ups request = (DMLRequest.Ups)nr.request;
                SObject record = request.record.clone();
                Database.upsert(request.record, request.externalIdField); 
                nr.box.operationStatus = new Operation.OperationSuccess(record);
            }
        }
    }
}