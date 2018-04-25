/**
 * Copyright (c) 2018-present, Nubilum IT Consulting d.o.o. 
 * All rights reserved.
 */
public abstract class OperationFunction {
    abstract public Operation apply(Object a);
    public OperationFunction then(OperationFunction f) {
        return new ThenOperationFunction(this, f);
    }
    public class ThenOperationFunction extends OperationFunction {
        OperationFunction fa;
        OperationFunction fb;
        public ThenOperationFunction(OperationFunction fa, OperationFunction fb) {
            this.fa = fa;
            this.fb = fb;
        }
        override public Operation apply(Object a) {
            return fa.apply(a).then(fb);
        }
    }
    public OperationFunction recover(RecoverFunction f) {
        return new RecoverOperationFunction(this, f);
    }
    public class RecoverOperationFunction extends OperationFunction {
        OperationFunction fa;
        RecoverFunction fb;
        public RecoverOperationFunction(OperationFunction fa, RecoverFunction fb) {
            this.fa = fa;
            this.fb = fb;
        }
        override public Operation apply(Object a) {
            return fa.apply(a).recover(fb);
        }
    }
    public OperationFunction allways(CodeBlock b) {
        return new AllwaysOperationFunction(this, b);
    }
    public class AllwaysOperationFunction extends OperationFunction {
        OperationFunction f;
        CodeBlock b;
        public AllwaysOperationFunction(OperationFunction f, CodeBlock b) {
            this.f = f;
            this.b = b;
        }
        override public Operation apply(Object a) {
            return f.apply(a).allways(b);
        }
    }
    public Operation bulkify(List<Object> bs) {
        List<Operation> operations = new List<Operation>();
        for (Object b : bs) {
            operations.add(this.apply(b));
        }
        return Operation.join(operations);
    }
}
