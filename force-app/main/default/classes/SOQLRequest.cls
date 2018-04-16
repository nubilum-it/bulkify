/**
 * Copyright (c) 2018-present, Nubilum IT Consulting d.o.o. 
 * All rights reserved.
 */
public class SOQLRequest implements Operation.Request {
    public String query;
    public SOQLRequest(String query) { this.query = query; }
    public String getClassName() { return SOQLExecutor.class.getName(); }
    public static SOQLRequest query(String query) { return new SOQLRequest(query); }
    public Integer hashCode() {
        return query.hashCode();
    }
    public Boolean equals(Object a) {
        if (a instanceof SOQLRequest) {
            return (query == ((SOQLRequest)a).query);
        }
        return false;
    }
}
