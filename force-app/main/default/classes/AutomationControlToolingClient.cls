@SuppressWarnings('PMD.CyclomaticComplexity,PMD.ExcessiveParameterList,PMD.ApexDoc,PMD.ApexSuggestUsingNamedCred')
public inherited sharing class AutomationControlToolingClient {
    public static final String NAMED_CREDENTIAL = 'Automation_Control_Center';
    public static final String API_VERSION = 'v60.0';
    @TestVisible
    private static String sessionIdOverride;

    public class ToolingClientException extends Exception {
    }

    public class QueryPage {
        public Integer totalSize;
        public Boolean done;
        public String nextRecordsUrl;
        public List<Map<String, Object>> records = new List<Map<String, Object>>();
    }

    public class CompositeRequestEntry {
        public String method;
        public String url;
        public String referenceId;
        public Object body;
    }

    public class CompositeSubresponse {
        public String referenceId;
        public Integer httpStatusCode;
        public Object body;
    }

    public QueryPage query(String soql) {
        String encodedQuery = EncodingUtil.urlEncode(soql, 'UTF-8');
        HttpResponse response = send(request('GET', '/services/data/' + API_VERSION + '/tooling/query/?q=' + encodedQuery));
        return parseQueryPage(response.getBody());
    }

    public QueryPage queryMore(String nextRecordsUrl) {
        if (String.isBlank(nextRecordsUrl) || !nextRecordsUrl.startsWith('/services/data/')) {
            throw new ToolingClientException('Invalid Tooling API query locator.');
        }
        HttpResponse response = send(request('GET', nextRecordsUrl));
        return parseQueryPage(response.getBody());
    }

    public Map<String, Object> retrieve(String sobjectName, String recordId) {
        HttpResponse response = send(
            request('GET', '/services/data/' + API_VERSION + '/tooling/sobjects/' + sobjectName + '/' + recordId)
        );
        return (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
    }

    public void patch(String sobjectName, String recordId, Map<String, Object> body) {
        HttpRequest request = request(
            'PATCH',
            '/services/data/' + API_VERSION + '/tooling/sobjects/' + sobjectName + '/' + recordId
        );
        request.setBody(JSON.serialize(body));
        send(request);
    }

    public List<CompositeSubresponse> composite(List<CompositeRequestEntry> entries) {
        if (entries == null || entries.isEmpty()) {
            return new List<CompositeSubresponse>();
        }
        if (entries.size() > 25) {
            throw new ToolingClientException('Composite requests can contain at most 25 subrequests.');
        }

        HttpRequest request = request('POST', '/services/data/' + API_VERSION + '/tooling/composite');
        request.setBody(
            JSON.serialize(
                new Map<String, Object>{
                    'allOrNone' => false,
                    'compositeRequest' => entries
                }
            )
        );

        HttpResponse response = send(request);
        Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
        List<CompositeSubresponse> subresponses = new List<CompositeSubresponse>();
        for (Object rawSubresponse : (List<Object>) payload.get('compositeResponse')) {
            Map<String, Object> raw = (Map<String, Object>) rawSubresponse;
            CompositeSubresponse subresponse = new CompositeSubresponse();
            subresponse.referenceId = stringValue(raw.get('referenceId'));
            subresponse.httpStatusCode = integerValue(raw.get('httpStatusCode'));
            subresponse.body = raw.get('body');
            subresponses.add(subresponse);
        }
        return subresponses;
    }

    public static CompositeRequestEntry compositeGet(String referenceId, String toolingSobjectName, String recordId) {
        CompositeRequestEntry entry = new CompositeRequestEntry();
        entry.method = 'GET';
        entry.referenceId = referenceId;
        entry.url = '/services/data/' + API_VERSION + '/tooling/sobjects/' + toolingSobjectName + '/' + recordId;
        return entry;
    }

    public static CompositeRequestEntry compositePatch(
        String referenceId,
        String toolingSobjectName,
        String recordId,
        Map<String, Object> body
    ) {
        CompositeRequestEntry entry = new CompositeRequestEntry();
        entry.method = 'PATCH';
        entry.referenceId = referenceId;
        entry.url = '/services/data/' + API_VERSION + '/tooling/sobjects/' + toolingSobjectName + '/' + recordId;
        entry.body = body;
        return entry;
    }

    public static Boolean isSuccess(Integer statusCode) {
        return statusCode != null && statusCode >= 200 && statusCode < 300;
    }

    public static String responseMessage(Object body) {
        if (body == null) {
            return null;
        }
        try {
            List<String> messages = new List<String>();
            for (Object item : (List<Object>) body) {
                try {
                    messages.add(stringValue(((Map<String, Object>) item).get('message')));
                } catch (Exception e) {
                    messages.add(String.valueOf(item));
                }
            }
            return String.join(messages, ' | ');
        } catch (Exception e) {
            if (String.isBlank(e.getMessage())) {
                return String.valueOf(body);
            }
        }

        try {
            Map<String, Object> raw = (Map<String, Object>) body;
            if (raw.containsKey('message')) {
                return stringValue(raw.get('message'));
            }
            if (raw.containsKey('error')) {
                return stringValue(raw.get('error'));
            }
        } catch (Exception e) {
            return String.valueOf(body);
        }
        return String.valueOf(body);
    }

    private HttpRequest request(String method, String servicePath) {
        HttpRequest request = new HttpRequest();
        request.setEndpoint('callout:' + NAMED_CREDENTIAL + servicePath);
        request.setMethod(method);
        // This org blocks Connected App creation, so the endpoint lives in a Named Credential
        // while the current admin's API-capable session supplies same-org Tooling API auth.
        request.setHeader('Authorization', 'Bearer ' + apiSessionId());
        request.setHeader('Content-Type', 'application/json');
        request.setHeader('Accept', 'application/json');
        request.setTimeout(120000);
        return request;
    }

    private String apiSessionId() {
        if (String.isNotBlank(sessionIdOverride)) {
            return sessionIdOverride;
        }
        if (Test.isRunningTest()) {
            return 'test-session';
        }

        String sessionId = Page.AutomationControlSession.getContent().toString().trim();
        if (String.isBlank(sessionId)) {
            throw new ToolingClientException('Unable to obtain an API-capable Salesforce session for Tooling API access.');
        }
        return sessionId;
    }

    private HttpResponse send(HttpRequest request) {
        HttpResponse response = new Http().send(request);
        Integer statusCode = response.getStatusCode();
        if (!isSuccess(statusCode)) {
            throw new ToolingClientException(errorMessage(statusCode, response.getBody()));
        }
        return response;
    }

    private QueryPage parseQueryPage(String body) {
        Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(body);
        QueryPage page = new QueryPage();
        page.totalSize = integerValue(payload.get('totalSize'));
        page.done = (Boolean) payload.get('done');
        page.nextRecordsUrl = stringValue(payload.get('nextRecordsUrl'));

        try {
            for (Object rawRecord : (List<Object>) payload.get('records')) {
                page.records.add((Map<String, Object>) rawRecord);
            }
        } catch (Exception e) {
            page.records = new List<Map<String, Object>>();
        }
        return page;
    }

    private String errorMessage(Integer statusCode, String body) {
        String detail;
        try {
            detail = responseMessage(JSON.deserializeUntyped(body));
        } catch (Exception e) {
            detail = body;
        }
        return 'Tooling API request failed with HTTP ' + statusCode + ': ' + detail;
    }

    private static Integer integerValue(Object value) {
        if (value == null) {
            return null;
        }
        if (value instanceof Integer) {
            return (Integer) value;
        }
        if (value instanceof Decimal) {
            return ((Decimal) value).intValue();
        }
        if (value instanceof Long) {
            return Integer.valueOf(String.valueOf(value));
        }
        return Integer.valueOf(String.valueOf(value));
    }

    private static String stringValue(Object value) {
        return value == null ? null : String.valueOf(value);
    }
}
