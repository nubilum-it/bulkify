/**
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
 * Each operation will have two states:
 *   Done
 *   Next
 * Next state will contain list of (Request, OperationResult) = NextRequest
 * OperationResult will have:
 *   OperationWaiting
 *   OperationSuccess 
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

    /**
     * Cache for issued requests.
     * Request -> Ref
     */
    static Map<Request, Ref> cache = new Map<Request, Ref>();

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
    }
    public class BoxOperationSupplier implements OperationSupplier {
        Ref box;
        public BoxOperationSupplier(Ref box) { this.box = box; }
        public State get() {
            OperationSuccess success = (OperationSuccess)box.operationStatus;
            return new Done(success.result);
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
                else { //if (box.operationStatus instanceof OperationWaiting) {
                    return new Next(new List<NextRequest> {}, new Operation(new BoxOperationSupplier(box)));
                }
            }
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
            if (o.get() instanceof Done) {
                Done done = (Done)o.get();
                return f.apply(done.value).get();
            }
            else { // if (o.get() instanceof Next) {
                Next next = (Next)o.get();
                return new Next(next.nextRequests, next.operation.then(f)); 
            }
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
            else { //if (a.get() instanceof Next && b.get() instanceof Next) {
                Next nextA = (Next)a.get();
                Next nextB = (Next)b.get();
                return new Next(concat(nextA.nextRequests, nextB.nextRequests), nextA.operation.apply(nextB.operation));
            }
        }
    }
    static List<NextRequest> concat(List<NextRequest> a, List<NextRequest> b) {
        List<NextRequest> result = new List<NextRequest>(a);
        result.addAll(b);
        return result;
    }

     /**
     * Joins list of operations into the one operation.
     */
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
        while (that.get() instanceof Next) {
            Next next = (Next)that.get();            
            execute(next.nextRequests);
            that = next.operation;
        }
        Done done = (Done)that.get();
        return done.value;
    }

    /**
     * Executor for the next requests.
     * We needs to group requests be executors.
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
