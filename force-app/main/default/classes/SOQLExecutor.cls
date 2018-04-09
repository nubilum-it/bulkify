/**
 * Execute SOQL queries. 
 * For now we are keeping it plain simple. Bulkification should be added
 * in product.
 * Currently we are doing SOQL with QueryLocator but it cannot have FOR UPDATE keyword.
 */
public class SOQLExecutor implements Operation.Executor {
    public void execute(List<Operation.NextRequest> nextRequests) {
        for (Operation.NextRequest nr : nextRequests) {
            SOQLRequest request = (SOQLRequest)nr.request;
            List<SObject> result = new List<SObject> {};
            Database.QueryLocator queryLocator = Database.getQueryLocator(request.query);
            Database.QueryLocatorIterator queryIt = queryLocator.iterator();
            while (queryIt.hasNext()) {
                result.add(queryIt.next());
            }
            nr.box.operationStatus = new Operation.OperationSuccess(result);
        }
    }
}
