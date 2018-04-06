/**
 * DML Executor functionality. 
 * Steps of execution:
 *   groupBy requests by operation type (insert, delete, update, upsert).
 *   groupBy SObject type already each grouped request.
 *   execute each needed operation.
 * Some operations can be executed with all records and some should be executed one record at the time like upsert.
 * Delete should be done by deleting first child than parent. We chan chain operations with then combinator.
 */
public with sharing class DMLExecutor implements Operation.Executor {
    /**
     * Method for executing DML operations.
     */
    public void execute(List<Operation.NextRequest> nextRequests) {
    }
}
