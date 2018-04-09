public class SOQLRequest implements Operation.Request {
    public String query;
    public SOQLRequest(String query) { this.query = query; }
    public String getClassName() { return SOQLExecutor.class.getName(); }
}
