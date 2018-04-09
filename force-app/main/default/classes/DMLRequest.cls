public abstract class DMLRequest implements Operation.Request {
    public SObject record;
    public DMLRequest(SObject record) { this.record = record; }
    abstract String getClassName();
    public class Ins extends DMLRequest {
        public Ins(SObject record) { super(record); }
        override public String getClassName() { return DMLExecutor.Ins.class.getName(); }
    }
   public class Upd extends DMLRequest {
        public Upd(Sobject record) { super(record); }
        override public String getClassName() { return DMLExecutor.Upd.class.getName(); }
    }
    public class Del extends DMLRequest {
        public Del(SObject record) { super(record); }
        override public String getClassName() { return DMLExecutor.Del.class.getName(); }
    }
     public class Ups extends DMLRequest {
        public Schema.SObjectField externalIdField;
        public Ups(SObject record, Schema.SObjectField externalIdField) { 
            super(record); 
            this.externalIdField = externalIdField;
        }
        override public String getClassName() { return DMLExecutor.Ups.class.getName(); }
    }
    public static DMLRequest ins(SObject record) { return new Ins(record); }
    public static DMLRequest del(SObject record) { return new Del(record); }
    public static DMLRequest upd(SObject record) { return new Upd(record); }
    public static DMLRequest ups(SObject record, Schema.SObjectField externalIdField) { return new Ups(record, externalIdField); }
}
