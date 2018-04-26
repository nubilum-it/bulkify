/**
 * Copyright (c) 2018-present, Nubilum IT Consulting d.o.o. 
 * All rights reserved.
 * Operation is a generic type for doing some data manipulation that can be bulkified.
 * For example we can have oparetaion to retrieve data from database(SOQL) another is
 * to save it to the database(DML).
 * Opeartion should be lazy data type that will be used with combinators.
 * Operation can have combinators that will do operation:
 *   then
 *   join
 *   bulkify
 * Operation will be executed by using:
 *   execute
 * Each operation will have three states:
 *   Done
 *   Next
 *   Error
 * Next state will contain list of (Request, OperationResult) = NextRequest
 * OperationResult will have:
 *   OperationWaiting
 *   OperationSuccess 
 *   OperationError
 */
public class Operation implements OperationSupplier {
    public interface Function {
        Object apply(Object a);
    }
    public abstract class Function2 implements Function {
        public Object apply(Object a) {
            return apply2(a);
        }
        abstract Function apply2(Object a);
    }
    public interface OperationFunction2 {
        OperationFunction apply(Operation a);
    }
    public interface OperationSupplier {
        State get();
        List<Operation> getOperations();
    }
    public interface State {}
    public class Done implements State{
        public Done(Object value) { this.value = value; }
        public Object value; 
    }
    public class Next implements State {
        public Next(List<NextRequest> nextRequests, Operation operation) {
            this.nextRequests = nextRequests;
            this.operation = operation;
        }
        List<NextRequest> nextRequests;
        Operation operation;
    }
    public class Error implements State {
        public Error(Exception e) {
            this.e = e;
        }
        Exception e;
    }
    public class Ref {
        public OperationStatus operationStatus;
        public Ref(OperationStatus operationStatus) { this.operationStatus = operationStatus; }
    }
    public interface Request {
        String getClassName();
    }
    public class NextRequest {
        public Request request;
        public Ref box;
        public NextRequest(Request request, Ref box) {
            this.request = request;
            this.box = box;
        }
    }
    public interface Executor {
        void execute(List<nextRequest> nextRequests);
    }
    
    public interface OperationStatus {}
    public class OperationWaiting implements OperationStatus {}
    public class OperationSuccess implements OperationStatus {
        public Object result;
        public OperationSuccess(Object result) { this.result = result; }
    }
    public class OperationError implements OperationStatus {
        public Exception e;
        public OperationError(Exception e) { this.e = e; }
    }

    /**
     * Cache for issued requests.
     * Request -> Ref
     */
    public static Map<Request, Ref> cache = new Map<Request, Ref>();

    OperationSupplier s;
    State a;

    public Operation(OperationSupplier s) { this.s = s; }
    /**
     * Evaluate operation with given supplier. 
     * After evaluation, supplier is released because it is not needed anymore.
     */
    public State get() {
        if (a == null) {
            a = s.get();
            s = null;
        }
        return a;
    }

    /**
     * Get all operations on with evaluation of this operation is depending
     */
    public List<Operation> getOperations() {
        if (a == null) {
            return s.getOperations();
        }
        else {
            return new List<Operation>{};
        }
    }

    /**
     * Generators.
     */

    /**
     * Constructor for the atomic operations from request without caching.
     */
    public static Operation unCached(Request request) {
        return new Operation(new UnCachedSupplier(request));
    }
    public class UnCachedSupplier implements OperationSupplier {
        Request request;
        public UnCachedSupplier(Request request) { this.request = request; }
        public State get() {
            Ref box  =  new Ref(new OperationWaiting());
            NextRequest nextRequest = new NextRequest(request, box);
            return new Next(new List<NextRequest> { nextRequest }, new Operation(new BoxOperationSupplier(box)));
        }
        public List<Operation> getOperations() {
            return new List<Operation>{};
        }
    }
    public class BoxOperationSupplier implements OperationSupplier {
        Ref box;
        public BoxOperationSupplier(Ref box) { this.box = box; }
        public State get() {
            if (box.operationStatus instanceof OperationSuccess) {
                OperationSuccess success = (OperationSuccess)box.operationStatus;
                return new Done(success.result);
            }
            else { //if (box.operationStatus instanceof OperationError) {
                OperationError error = (OperationError)box.operationStatus;
                return new Error(error.e);
            }
        }
        public List<Operation> getOperations() {
            return new List<Operation>{};
        }
    }

    /**
     * Constructor for the atomic operations from request with caching. 
     * If request is already requested result will be obtained from cached result box. 
     */
    public static Operation cached(Request request) {
        return new Operation(new CachedSupplier(request));
    }
    public class CachedSupplier implements OperationSupplier {
        Request request;
        public CachedSupplier(Request request) { this.request = request; }
        public State get() {
            Ref box = cache.get(request);
            if (box == null) {
                box = new Ref(new OperationWaiting());
                cache.put(request, box);
                NextRequest nextRequest = new NextRequest(request, box);
                return new Next(new List<NextRequest> { nextRequest }, new Operation(new BoxOperationSupplier(box)));
            }
            else {
                if (box.operationStatus instanceof OperationSuccess) {
                    OperationSuccess success = (OperationSuccess)box.operationStatus;
                    return new Done(success.result);
                }
                else if (box.operationStatus instanceof OperationWaiting) {
                    return new Next(new List<NextRequest> {}, new Operation(new BoxOperationSupplier(box)));
                }
                else { //if (box.operatoinStatus instanceof OperationError) {
                    OperationError error = (OperationError)box.operationStatus;
                    return new Error(error.e);
                }
            }
        }
        public List<Operation> getOperations() {
            return new List<Operation>{};
        }
    }
    

    /**
     * Constructor for predefined value.
     */
    public static Operation result(Object a) {
        return new Operation(new DoneOperationSupplier(a));
    }
    public class DoneOperationSupplier implements OperationSupplier {
        Object a;
        public DoneOperationSupplier(Object a) { this.a = a; }
        public State get() {
            return new Done(a);
        }
        public List<Operation> getOperations() {
            return new List<Operation>{};
        }
    }

    /**
     * Consturctor for error value.
     */
    public static Operation error(Exception e) {
        return new Operation(new ErrorOperationSupplier(e));
    }
    public class ErrorOperationSupplier implements OperationSupplier {
        Exception e;
        public ErrorOperationSupplier(Exception e) { this.e = e; }
        public State get() {
            return new Error(e);
        }
        public List<Operation> getOperations() {
            return new List<Operation>{};
        }
    }

    /**
     * Convert to operation function that will ingore argument and return this operation. 
     * Used for fast conversion to operation function for then combinator.
     */ 
    public OperationFunction operationFunction() {
        return new ToOperationFunction(this);
    }
    public class ToOperationFunction extends OperationFunction {
        Operation o;
        public ToOperationFunction(Operation o) { this.o = o; }
        override public Operation apply(Object a) { return o; }
    }

    /**
     * Convert to recover function that will ignore argument and return this operation. 
     * User for fast conversion to recover function for recover combinator.
     */ 
    public RecoverFunction recoverFunction() {
        return new ToRecoverFunction(this);
    }
    public class ToRecoverFunction extends RecoverFunction {
        Operation o;
        public ToRecoverFunction(Operation o) { this.o = o; }
        override public Operation apply(Exception e) { return o; }
    }

    /**
     * Combinators.
     */

    /**
     * Operation for chaining(then) will have two arguments:
     *   Operation - will be this operation.
     *   OperationFunction - functaion that will return operation.
     * Result will be new Operation that will chain Operation with OperationFunction.
     */
    public Operation then(OperationFunction f) {
        return new Operation(new ThenOperationSupplier(this, f));
    }
    public class ThenOperationSupplier implements OperationSupplier {
        Operation o;
        OperationFunction f;
        public ThenOperationSupplier(Operation o, OperationFunction f) {
            this.o = o;
            this.f = f;
        }
        public State get() {
            try {
                if (o.get() instanceof Done) {
                    Done done = (Done)o.get();
                    return f.apply(done.value).get();
                }
                else if (o.get() instanceof Next) {
                    Next next = (Next)o.get();
                    return new Next(next.nextRequests, next.operation.then(f)); 
                }
                else { // if (o.get() instanceof Error) {
                    return o.get();
                }
            }
            catch (Exception e) {
                return new Error(e);
            }
        }
        public List<Operation> getOperations() {
            return new List<Operation>{o};
        }
    }

    /**
     * Recovery from the error.
     * When evaluating operation on next operation we are attaching error handler
     * so that we recover whole operation chain.
     */
    public Operation recover(RecoverFunction f) {
        return new Operation(new RecoverOperationSupplier(this, f));
    }
    public class RecoverOperationSupplier implements OperationSupplier {
        Operation o;
        RecoverFunction f;
        public RecoverOperationSupplier(Operation o, RecoverFunction f) {
            this.o = o;
            this.f = f;
        }
        public State get() {
            try {
                if (o.get() instanceof Done) {
                    return o.get();
                }
                else if (o.get() instanceof Next) {
                    Next nextA = (Next)o.get();
                    return new Next(nextA.nextRequests, nextA.operation.recover(f));
                }
                else { //if (o.get() instanceof Error) {
                    Error a = (Error)o.get();
                    return f.apply(a.e).get();
                }
            }
            catch (Exception e) {
                return new Error(e);
            }
        }
        public List<Operation> getOperations() {
            return new List<Operation>{o};
        }
    }

    /**
     * Always run the code block. 
     * When evaluating operation on next operation we are attaching this code block.
     * Code blocked is runned on Done | Error. 
     * If exception is thrown on Done we will generate Error otherwise old error will be propagated.
     */
    public Operation always(CodeBlock b) {
        return new Operation(new AllwaysOperationSupplier(this, b));
    }
    public class AllwaysOperationSupplier implements OperationSupplier {
        Operation o;
        CodeBlock b;
        public AllwaysOperationSupplier(Operation o, CodeBlock b) {
            this.o = o;
            this.b = b;
        }
        public State get() {
            try {
                if (o.get() instanceof Done) {
                    // Run code block
                    b.run();
                    return o.get();
                }
                else if (o.get() instanceof Next) {
                    Next nextA = (Next)o.get();
                    return new Next(nextA.nextRequests, nextA.operation.always(b));
                }
                else {// if (o.get() instanceof Error) {
                    // Run code block
                    b.run();
                    return o.get();
                }
            }
            catch (Exception e) {
                if (o.get() instanceof Error) {
                    return o.get();
                }                
                else {
                    return new Error(e);
                }
            }
        }
        public List<Operation> getOperations() {
            return new List<Operation>{o};
        }
    }

    /**
     * Apply of he Operation function with the Operation value. 
     * Arguments:
     *   Operation f - function that will be applied. 
     *   Operation a - value that will be used in function. 
     * Result will be Operation that will apply value to the function.
     */
    public Operation apply(Operation o) {
        return new Operation(new ApplyOperationSupplier(this, o));
    }
    public class ApplyOperationSupplier implements OperationSupplier {
        Operation a;
        Operation b;
        public ApplyOperationSupplier(Operation a, Operation b) {
            this.a = a;
            this.b = b;
        }
        public State get() {
            if (a.get() instanceof Done && b.get() instanceof Done) {
                Done doneA = (Done)a.get();
                Done doneB = (Done)b.get();
                Function f = (Function)doneA.value;
                return new Done(f.apply(doneB.value));
            }
            else if (a.get() instanceof Done && b.get() instanceof Next) {
                Done doneA = (Done)a.get();
                Next nextB = (Next)b.get();
                return new Next(nextB.nextRequests, a.apply(nextB.operation));
            }
            else if (a.get() instanceof Next && b.get() instanceof Done) {
                Next nextA = (Next)a.get();
                Done doneB = (Done)b.get();
                return new Next(nextA.nextRequests, nextA.operation.apply(b));
            }
            else if (a.get() instanceof Next && b.get() instanceof Next) {
                Next nextA = (Next)a.get();
                Next nextB = (Next)b.get();
                return new Next(concat(nextA.nextRequests, nextB.nextRequests), nextA.operation.apply(nextB.operation));
            }
            else if (a.get() instanceof Next && b.get() instanceof Error) { 
                // We don't know if left side with return Error in the end.
                // If yes we should return left side error.
                Next nextA = (Next)a.get();
                return new Next(nextA.nextRequests, nextA.operation.apply(b));
            }
            else if (a.get() instanceof Error) {
                return a.get();
            }
            else { // if (!(a.get() instanceof Error) && b.get() instanceof Error) {
                return b.get();
            }
        }
        public List<Operation> getOperations() {
            return new List<Operation>{a, b};
        }
    }
    static List<NextRequest> concat(List<NextRequest> a, List<NextRequest> b) {
        List<NextRequest> result = new List<NextRequest>(a);
        result.addAll(b);
        return result;
    }

    /**
     * Joins list of operations into the one operation using applicative apply.
     * Code is just for info. This is how it previously worked.
     */
    /*
    public static Operation join(List<Operation> operations) {
        Operation acc = Operation.result(new List<Object>());
        OperationFunction2 cons = new LiftOperationFunction2(new AppendFunction2());
        for (Operation o : operations) {
            acc = cons.apply(o).apply(acc);
        }
        return acc;
    }
    public class AppendFunction2 extends Function2 {
        override public Function apply2(Object a) {
            return new AppendFunction(a);            
        }
    }
    public class AppendFunction implements Function {
        Object a;
        public AppendFunction(Object a) { this.a = a; }
        public Object apply(Object b) {
            List<Object> bs = (List<Object>)b;
            List<Object> result = new List<Object>(bs);
            result.add(a);
            return result;
        }
    }
    public class LiftOperationFunction2 implements OperationFunction2 {
        Function2 f;
        public LiftOperationFunction2(Function2 f) { this.f = f; }
        public OperationFunction apply(Operation a) {
            return new LiftOperationFunction(f, a);
        }
    }
    public class LiftOperationFunction extends OperationFunction {
        Function2 f;
        Operation a;
        public LiftOperationFunction(Function2 f, Operation a) {
            this.f = f;
            this.a = a;
        }
        override public Operation apply(Object b) {
        return Operation.result(f).apply(a).apply((Operation)b);
        }
    }
    */

    /**
     * Optimized version of applicative join operation.
     * It should have better execution time and memory consumption. 
     * Steps:
     *   Evaluate all operations.
     *   If all operations are Done create Done operation with list of all results.
     *   If one operation is Error:
     *     Previous operations are Done return Error. 
     *     Otherwise join previous next.operatoins and evalueated Done with Error at the end.
     *   Otherwise create Next operation with:
     *     operation as join of all next.operation
     *     Done operations are passed by reference that has been evaluated.
     */
    public static Operation join(List<Operation> operations) {
        return new Operation(new JoinOperationSupplier(operations));
    }
    public class JoinOperationSupplier implements OperationSupplier {
        List<Operation> operations;
        public JoinOperationSupplier(List<Operation> operations) { this.operations = operations; }
        public State get() {
            Boolean isDone = true;
            List<Operation> nextOperations = new List<Operation>();
            List<NextRequest> nextRequests = new List<NextRequest>();
            for (Operation o : operations) {
                if (o.get() instanceof Done) {
                    nextOperations.add(o);
                }
                else if (o.get() instanceof Next) {
                    Next nextA = (Next)o.get();
                    nextOperations.add(nextA.operation);
                    nextRequests.addAll(nextA.nextRequests);
                    isDone = false;
                }
                else { //if (o.get() instanceof Error) {
                    if (isDone) {
                        return o.get();
                    }
                    else {
                        nextOperations.add(o);
                        return new Next(nextRequests, join(nextOperations));
                    }
                }
            }
            if (isDone) {
                List<Object> result = new List<Object>();
                for (Operation o : nextOperations) {
                    Done doneA = (Done)o.get();
                    result.add(doneA.value);
                }
                return new Done(result); 
            }
            else {
                return new Next(nextRequests, join(nextOperations));
            }
        }
        public List<Operation> getOperations() { return operations; }
    }


    /**
    * Join list of the operation functions into the one operation function. 
    */
    public static OperationFunction join(List<OperationFunction> fs) {
        return new JoinOperationFunction(fs);
    }
    public class JoinOperationFunction extends OperationFunction {
        List<OperationFunction> fs;
        public JoinOperationFunction(List<OperationFunction> fs) { this.fs = fs; }
        override public Operation apply(Object b) {
            List<Object> bs = (List<Object>)b;
            Iterator<Object> bsIt = bs.iterator();
            Iterator<OperationFunction> fsIt = fs.iterator();
            List<Operation> operations = new List<Operation>();
            while(bsIt.hasNext() && fsIt.hasNext()) {
                operations.add(fsIt.next().apply(bsIt.next()));
            }
            return join(operations);
        }
    }

    /**
    * Execution of the operation.
    * It will evaluate all operations in the chain.
    */
    public Object execute() {
        Operation that = this;
        evaluate(that);
        while (that.get() instanceof Next) {
            Next next = (Next)that.get();            
            execute(next.nextRequests);
            that = next.operation;
            evaluate(that);
        }
        if (that.get() instanceof Error) {
            Error error = (Error)that.get();
            throw error.e;
        }
        // if (that.get() instanceof Done) {
        Done done = (Done)that.get();
        return done.value;
        // }
   }

    /**
    * Evaluate operation and all depending suboperations without causing stack overflow.
    * Steps:
    *   Get list of all operations that needs to be evaluated. 
    *   Evaluate operations in oposite order.
    */
    public void evaluate(Operation o) {
        List<Operation> os = new List<Operation>{o};
        List<Operation> ps = new List<Operation>{o};
        while (ps.size() > 0) {
            List<Operation> rs = new List<Operation>{};
            for (Operation p : ps) {
                rs.addAll(p.getOperations());
            }
            ps = rs;
            os.addAll(rs);
        }
        for (Integer a = os.size() - 1; a >= 0; a--) {
            os[a].get();
        }
    }

    /**
    * Executor for the next requests.
    * We needs to group requests by executors.
    */
    public static void execute(List<NextRequest> nextRequests) {
        Map<String, List<NextRequest>> executorRequests = groupBy(nextRequests, new ExecutorNameFunction());
        for (String key : executorRequests.keySet()) {
            Executor executor = (Executor)Type.forName(key).newInstance();
            executor.execute(executorRequests.get(key));
        }
    }
    public static Map<String, List<NextRequest>> groupBy(List<NextRequest> bs, Function f) {
        Map<String, List<NextRequest>> result = new Map<String, List<NextRequest>>();
        for (NextRequest b : bs) {
            String key = (String)f.apply(b);
            List<NextRequest> values = result.get(key);
            if (values != null) { values.add(b); }
            else {
                values = new List<NextRequest>{b};
                result.put(key, values);
            }
        }
        return result;
    }
    public class ExecutorNameFunction implements Function {
        public Object apply(Object a) {
            return ((NextRequest)a).request.getClassName();
        }
    }            
}
