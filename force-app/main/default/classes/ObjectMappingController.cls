public class ObjectMappingController {

    @AuraEnabled(cacheable=true)
    public static List<FormWrappers.ObjectWrapper> getObjects() {
        String nc = System.Label.Tooling_API_Named_Credential;
        String query = 'SELECT QualifiedApiName, Label FROM EntityDefinition WHERE IsCustomizable = true';
        String endpoint = 'callout:' + nc + '/services/data/v66.0/tooling/query?q='
            + EncodingUtil.urlEncode(query, 'UTF-8');

        HttpRequest req = new HttpRequest();
        req.setMethod('GET');
        req.setEndpoint(endpoint);

        HttpResponse res = new Http().send(req);
        if (res.getStatusCode() != 200) {
            throw new AuraHandledException('Tooling API error: ' + res.getStatus());
        }

        Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        List<Object> records = (List<Object>) body.get('records');

        List<FormWrappers.ObjectWrapper> result = new List<FormWrappers.ObjectWrapper>();
        for (Object rec : records) {
            Map<String, Object> r = (Map<String, Object>) rec;
            FormWrappers.ObjectWrapper w = new FormWrappers.ObjectWrapper();
            w.label = (String) r.get('Label');
            w.apiName = (String) r.get('QualifiedApiName');
            result.add(w);
        }
        return result;
    }

    @AuraEnabled(cacheable=true)
    public static List<FormWrappers.LayoutWrapper> getPageLayouts(String objectApiName) {
        String nc = System.Label.Tooling_API_Named_Credential;
        String query = 'SELECT Id, Name FROM Layout WHERE EntityDefinition.QualifiedApiName = \''
            + String.escapeSingleQuotes(objectApiName) + '\'';
        String endpoint = 'callout:' + nc + '/services/data/v66.0/tooling/query?q='
            + EncodingUtil.urlEncode(query, 'UTF-8');

        HttpRequest req = new HttpRequest();
        req.setMethod('GET');
        req.setEndpoint(endpoint);

        HttpResponse res = new Http().send(req);
        if (res.getStatusCode() != 200) {
            throw new AuraHandledException('Tooling API error: ' + res.getStatus());
        }

        Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        List<Object> records = (List<Object>) body.get('records');

        List<FormWrappers.LayoutWrapper> result = new List<FormWrappers.LayoutWrapper>();
        for (Object rec : records) {
            Map<String, Object> r = (Map<String, Object>) rec;
            FormWrappers.LayoutWrapper w = new FormWrappers.LayoutWrapper();
            w.id = (String) r.get('Id');
            w.name = (String) r.get('Name');
            result.add(w);
        }
        return result;
    }
}
