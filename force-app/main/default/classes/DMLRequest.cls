/**
 * Copyright (c) 2018-present, Nubilum IT Consulting d.o.o. 
 * All rights reserved.
 */
public abstract class DMLRequest implements Operation.Request {
    public SObject record;
    public DMLRequest(SObject record) { this.record = record; }
    abstract String getClassName();
    public class Ins extends DMLRequest {
        public Ins(SObject record) { super(record); }
        override public String getClassName() { return DMLExecutor.Ins.class.getName(); }
        public Integer hashCode() {
            return ((Object)record).hashCode();
        }
        public Boolean equals(Object a) {
            if (a instanceof DMLRequest.Ins) {
                return (record == ((DMLRequest.Ins)a).record);
            }
            return false;
        }
    }
    public class Upd extends DMLRequest {
        public Upd(Sobject record) { super(record); }
        override public String getClassName() { return DMLExecutor.Upd.class.getName(); }
        public Integer hashCode() {
            return ((Object)record).hashCode();
        }
        public Boolean equals(Object a) {
            if (a instanceof DMLRequest.Upd) {
                return (record == ((DMLRequest.Upd)a).record);
            }
            return false;
        }
    }
    public class Del extends DMLRequest {
        public Del(SObject record) { super(record); }
        override public String getClassName() { return DMLExecutor.Del.class.getName(); }
        public Integer hashCode() {
            return record.get('Id').hashCode();
        }
        public Boolean equals(Object a) {
            if (a instanceof DMLRequest.Del) {
                return (record.get('Id') == ((DMLRequest.Del)a).record.get('Id'));
            }
            return false;
        }
    }
    public class Ups extends DMLRequest {
        public Schema.SObjectField externalIdField;
        public Ups(SObject record, Schema.SObjectField externalIdField) { 
            super(record); 
            this.externalIdField = externalIdField;
        }
        override public String getClassName() { return DMLExecutor.Ups.class.getName(); }
        public Integer hashCode() {
            final Integer PRIME = 59;
            Integer result = 1;
            result = result * PRIME + ((Object)record).hashCode();
            result = result * PRIME + ((Object)externalIdField).hashCode();
            return result;
        }
        public Boolean equals(Object a) {
            if (a instanceof DMLRequest.Ups) {
                return (record == ((DMLRequest.Ups)a).record 
                    && externalIdField == ((DMLRequest.Ups)a).externalIdField);
            }
            return false;
        }
    }
    public static DMLRequest ins(SObject record) { return new Ins(record); }
    public static DMLRequest del(SObject record) { return new Del(record); }
    public static DMLRequest upd(SObject record) { return new Upd(record); }
    public static DMLRequest ups(SObject record, Schema.SObjectField externalIdField) { return new Ups(record, externalIdField); }
}
