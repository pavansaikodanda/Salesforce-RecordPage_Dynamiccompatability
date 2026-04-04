public class FieldSyncController {

    private static final Set<String> SYSTEM_FIELD_EXCLUSIONS = new Set<String>{
        'id', 'createddate', 'createdbyid', 'lastmodifieddate', 'lastmodifiedbyid',
        'systemmodstamp', 'isdeleted', 'lastactivitydate', 'lastvieweddate', 'lastreferenceddate'
    };

    private static final Set<Schema.DisplayType> EXCLUDED_TYPES = new Set<Schema.DisplayType>{
        Schema.DisplayType.Address,
        Schema.DisplayType.Location,
        Schema.DisplayType.Base64,
        Schema.DisplayType.EncryptedString
    };

    @AuraEnabled
    public static FormWrappers.SyncResultWrapper syncFields(String objectMappingId) {
        Custom_Object_Mapping__c mapping = [
            SELECT Object_API_Name__c, Page_Layout_ID__c
            FROM Custom_Object_Mapping__c
            WHERE Id = :objectMappingId
            LIMIT 1
        ];

        String nc = System.Label.Tooling_API_Named_Credential;
        String endpoint = 'callout:' + nc + '/services/data/v66.0/tooling/sobjects/Layout/'
            + mapping.Page_Layout_ID__c;

        HttpRequest req = new HttpRequest();
        req.setMethod('GET');
        req.setEndpoint(endpoint);

        HttpResponse res = new Http().send(req);
        if (res.getStatusCode() != 200) {
            throw new AuraHandledException('Tooling API error: ' + res.getStatus());
        }

        Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        Map<String, Object> metadata = (Map<String, Object>) body.get('Metadata');

        // Extract field name → section label from layout sections
        Map<String, String> fieldToSection = new Map<String, String>();
        List<Object> sections = (List<Object>) metadata.get('layoutSections');
        if (sections != null) {
            for (Object sec : sections) {
                Map<String, Object> section = (Map<String, Object>) sec;
                String sectionLabel = (String) section.get('label');
                List<Object> columns = (List<Object>) section.get('layoutColumns');
                if (columns == null) continue;
                for (Object col : columns) {
                    Map<String, Object> column = (Map<String, Object>) col;
                    List<Object> items = (List<Object>) column.get('layoutItems');
                    if (items == null) continue;
                    for (Object item : items) {
                        Map<String, Object> layoutItem = (Map<String, Object>) item;
                        String fieldName = (String) layoutItem.get('field');
                        if (String.isNotBlank(fieldName)) {
                            fieldToSection.put(fieldName, sectionLabel);
                        }
                    }
                }
            }
        }

        Map<String, Schema.SObjectField> schemaFields = Schema.getGlobalDescribe()
            .get(mapping.Object_API_Name__c).getDescribe().fields.getMap();

        // Load existing mappings into map by field API name
        Map<String, Custom_Field_Mapping__c> existingByApiName = new Map<String, Custom_Field_Mapping__c>();
        for (Custom_Field_Mapping__c cfm : [
            SELECT Id, Field_API_Name__c
            FROM Custom_Field_Mapping__c
            WHERE Object_Mapping__c = :objectMappingId
        ]) {
            existingByApiName.put(cfm.Field_API_Name__c, cfm);
        }

        Set<String> incomingFields = fieldToSection.keySet();
        List<Custom_Field_Mapping__c> toInsert = new List<Custom_Field_Mapping__c>();
        List<Custom_Field_Mapping__c> toDelete = new List<Custom_Field_Mapping__c>();
        Integer unchanged = 0;

        for (String fieldName : incomingFields) {
            if (SYSTEM_FIELD_EXCLUSIONS.contains(fieldName.toLowerCase())) continue;

            Schema.SObjectField sof = schemaFields.get(fieldName.toLowerCase());
            Boolean isReadOnly = false;

            if (sof != null) {
                Schema.DescribeFieldResult dfr = sof.getDescribe();

                if (EXCLUDED_TYPES.contains(dfr.getType())) continue;

                if (dfr.isCalculated() || dfr.isAutoNumber()) {
                    isReadOnly = true;
                } else if (!dfr.isUpdateable() && !dfr.isCreateable()) {
                    continue;
                }
            }

            if (existingByApiName.containsKey(fieldName)) {
                unchanged++;
            } else {
                String fieldType = 'Text';
                String referenceTo = null;
                Boolean isRequired = false;

                if (sof != null) {
                    Schema.DescribeFieldResult dfr = sof.getDescribe();
                    fieldType = dfr.getType().name();
                    isRequired = !dfr.isNillable() && !dfr.isDefaultedOnCreate();
                    List<Schema.SObjectType> refs = dfr.getReferenceTo();
                    if (!refs.isEmpty()) {
                        referenceTo = refs[0].getDescribe().getName();
                    }
                }

                toInsert.add(new Custom_Field_Mapping__c(
                    Object_Mapping__c = objectMappingId,
                    Field_API_Name__c = fieldName,
                    Field_Type__c = fieldType,
                    Is_Required_Layout__c = isRequired,
                    Is_Read_Only__c = isReadOnly,
                    Reference_To__c = referenceTo,
                    Section_Label__c = fieldToSection.get(fieldName),
                    Default_Visibility__c = 'Visible',
                    Is_Active__c = true
                ));
            }
        }

        for (String fieldName : existingByApiName.keySet()) {
            if (!incomingFields.contains(fieldName)) {
                toDelete.add(existingByApiName.get(fieldName));
            }
        }

        if (!toInsert.isEmpty()) insert toInsert;
        if (!toDelete.isEmpty()) delete toDelete;

        FormWrappers.SyncResultWrapper result = new FormWrappers.SyncResultWrapper();
        result.added = toInsert.size();
        result.removed = toDelete.size();
        result.unchanged = unchanged;
        return result;
    }
}
