/**
 * Copyright (c) 2018-present, Nubilum IT Consulting d.o.o. 
 * All rights reserved.
 */
public abstract class RecoverFunction {
    abstract public Operation apply(Exception e);
    public RecoverFunction then(OperationFunction f) {
        return new ThenRecoverFunction(this, f);
    }
    public class ThenRecoverFunction extends RecoverFunction {
        RecoverFunction fa;
        OperationFunction fb;
        public ThenRecoverFunction(RecoverFunction fa, OperationFunction fb) {
            this.fa = fa;
            this.fb = fb;
        }   
        override public Operation apply(Exception e) {
            return fa.apply(e).then(fb);
        }
    }
}
